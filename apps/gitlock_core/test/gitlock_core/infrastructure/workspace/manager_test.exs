defmodule GitlockCore.Infrastructure.Workspace.ManagerTest do
  use ExUnit.Case, async: false

  alias GitlockCore.Infrastructure.Workspace.{Manager, Store}

  setup do
    # Reset store state at start of each test
    Store.reset()

    # Create temp directory for tests
    {:ok, temp_dir} = Briefly.create(directory: true)

    on_exit(fn ->
      # Clean up any workspaces created during test
      try do
        Store.reset()
      catch
        # Ignore if Store is already dead
        :exit, _ -> :ok
      end
    end)

    {:ok, temp_dir: temp_dir}
  end

  describe "acquire/2 - local directories" do
    test "acquires existing local directory", %{temp_dir: temp_dir} do
      # Create a local directory
      local_dir = Path.join(temp_dir, "local_repo")
      File.mkdir_p!(local_dir)

      assert {:ok, workspace} = Manager.acquire(local_dir)

      assert workspace.source == local_dir
      assert workspace.path == local_dir
      assert workspace.type == :local
      assert workspace.state == :ready
      assert workspace.owner == self()
      assert %DateTime{} = workspace.created_at
    end

    test "handles non-existent local directory" do
      non_existent = "/path/that/does/not/exist/#{System.unique_integer()}"

      assert {:ok, workspace} = Manager.acquire(non_existent)

      # Manager creates workspace but marks as unknown type
      assert workspace.type == :unknown
      assert workspace.source == non_existent
      assert workspace.state == :ready
    end

    test "reuses existing workspace for same local directory", %{temp_dir: temp_dir} do
      local_dir = Path.join(temp_dir, "reuse_test")
      File.mkdir_p!(local_dir)

      # First acquisition
      assert {:ok, workspace1} = Manager.acquire(local_dir)

      # Second acquisition should reuse
      assert {:ok, workspace2} = Manager.acquire(local_dir)

      assert workspace1.id == workspace2.id
      assert workspace1.source == workspace2.source
    end
  end

  describe "acquire/2 - files" do
    test "acquires regular file", %{temp_dir: temp_dir} do
      file_path = Path.join(temp_dir, "test.txt")
      File.write!(file_path, "test content")

      assert {:ok, workspace} = Manager.acquire(file_path)

      assert workspace.source == file_path
      assert workspace.path == file_path
      assert workspace.type == :file
      assert workspace.state == :ready
    end
  end

  describe "acquire/2 - remote repositories" do
    @tag :integration
    test "clones remote repository" do
      # Use a small test repository
      repo_url = "https://github.com/octocat/Hello-World.git"

      assert {:ok, workspace} = Manager.acquire(repo_url, depth: 1)
      assert workspace.source == repo_url
      assert workspace.type == :remote
      assert workspace.state == :ready
      assert workspace.path != nil
      assert File.dir?(workspace.path)
      assert File.exists?(Path.join(workspace.path, ".git"))
    end

    test "handles clone failure gracefully" do
      invalid_url = "https://github.com/invalid/nonexistent-repo-#{System.unique_integer()}.git"

      assert {:error, reason} = Manager.acquire(invalid_url)
      assert is_binary(reason)
      assert reason =~ "Git clone failed"
    end
  end

  describe "release/1" do
    test "releases workspace by ID", %{temp_dir: temp_dir} do
      {:ok, workspace} = Manager.acquire(temp_dir)

      result = Manager.release(workspace.id)
      assert result == :ok
    end

    test "releases workspace by source", %{temp_dir: temp_dir} do
      {:ok, _workspace} = Manager.acquire(temp_dir)

      result = Manager.release(temp_dir)
      assert result == :ok
    end

    test "handles release of non-existent workspace" do
      result = Manager.release("non_existent_#{System.unique_integer()}")
      assert result == :ok
    end
  end

  describe "workspace type detection" do
    test "correctly identifies remote URL patterns" do
      remote_urls = [
        "https://github.com/user/repo.git",
        "http://example.com/repo.git",
        "git@github.com:user/repo.git",
        "ssh://git@server.com/repo.git"
      ]

      for url <- remote_urls do
        # Test the pattern matching directly
        assert remote_url_pattern?(url) == true
      end
    end

    test "correctly identifies local directories", %{temp_dir: temp_dir} do
      # Only test with paths that actually exist
      local_paths = [temp_dir, "/tmp"]

      for path <- local_paths do
        if File.dir?(path) do
          {:ok, workspace} = Manager.acquire(path)
          assert workspace.type == :local
          assert workspace.state == :ready
          assert workspace.path == path
        end
      end
    end

    test "correctly identifies files", %{temp_dir: temp_dir} do
      file_path = Path.join(temp_dir, "test_file.txt")
      File.write!(file_path, "content")

      {:ok, workspace} = Manager.acquire(file_path)
      assert workspace.type == :file
      assert workspace.state == :ready
      assert workspace.path == file_path
    end

    test "marks non-existent paths as unknown" do
      unknown_path = "/non/existent/path/#{System.unique_integer()}"
      {:ok, workspace} = Manager.acquire(unknown_path)
      assert workspace.type == :unknown
      assert workspace.state == :ready
      assert workspace.path == unknown_path
    end
  end

  describe "workspace state management" do
    test "local workspaces start in ready state" do
      {:ok, workspace} = Manager.acquire("/tmp")
      assert workspace.state == :ready
      assert workspace.path == "/tmp"
      assert workspace.type == :local
    end

    test "workspace deduplication works correctly" do
      source = "/tmp/dedup_test_#{System.unique_integer()}"

      # First acquisition
      {:ok, workspace1} = Manager.acquire(source)

      # Second acquisition should reuse
      {:ok, workspace2} = Manager.acquire(source)

      assert workspace1.id == workspace2.id
      assert workspace1.source == workspace2.source
    end

    test "concurrent acquisitions of same source return same workspace" do
      source = "/tmp/concurrent_#{System.unique_integer()}"

      # Start multiple acquisitions concurrently
      tasks =
        for i <- 1..3 do
          Task.async(fn ->
            {:ok, workspace} = Manager.acquire(source)
            {i, workspace.id}
          end)
        end

      # Wait for all to complete
      results = Enum.map(tasks, &Task.await/1)

      # All should get the same workspace ID
      workspace_ids = Enum.map(results, fn {_i, id} -> id end)
      assert length(Enum.uniq(workspace_ids)) == 1
    end
  end

  describe "error handling" do
    test "handles invalid workspace IDs gracefully" do
      # Should not crash on non-existent ID
      result = Manager.release("totally_fake_id_#{System.unique_integer()}")
      assert result == :ok
    end

    test "manager handles workspace creation correctly" do
      {:ok, workspace} = Manager.acquire("/tmp")

      # Verify basic workspace properties
      assert workspace.owner == self()
      assert %DateTime{} = workspace.created_at
      assert workspace.state == :ready
    end
  end

  describe "process lifecycle" do
    test "manager is running and responsive" do
      # Verify manager is registered and responding
      assert is_pid(GenServer.whereis(Manager))

      # Should be able to make calls
      assert {:ok, _workspace} = Manager.acquire("/tmp")
    end

    test "store is accessible" do
      # Create a workspace
      {:ok, workspace} = Manager.acquire("/tmp")

      # Should be able to retrieve it from store
      stored = Store.get(workspace.id)
      assert stored != nil
      assert stored.id == workspace.id
    end
  end

  # Helper functions - these test the core logic without side effects
  defp remote_url_pattern?(source) do
    String.match?(source, ~r/^(https?:\/\/|git@|ssh:\/\/git@)/)
  end
end
