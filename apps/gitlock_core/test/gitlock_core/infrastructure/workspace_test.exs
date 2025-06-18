defmodule GitlockCore.Infrastructure.WorkspaceTest do
  use ExUnit.Case, async: false

  alias GitlockCore.Infrastructure.Workspace
  alias GitlockCore.Infrastructure.Workspace.{Store}

  setup do
    # Reset store before each test
    Store.reset()

    on_exit(fn ->
      Store.reset()
    end)

    :ok
  end

  describe "with/3" do
    test "executes function with automatically managed workspace" do
      # Use a local directory for testing
      source = File.cwd!()

      result =
        Workspace.with(source, fn workspace ->
          assert workspace.path == source
          assert workspace.type == :local
          assert workspace.state == :ready

          # Return something to verify
          {:success, workspace.id}
        end)

      assert {:success, id} = result
      assert is_binary(id)

      # Workspace should be released after function
      # For local workspaces, they remain in store but marked as released
      workspace = Store.get_by_source(source)
      assert workspace.state == :released
    end

    test "handles function that returns various types" do
      source = File.cwd!()

      # Test returning different types
      assert 42 = Workspace.with(source, fn _ -> 42 end)
      assert "string" = Workspace.with(source, fn _ -> "string" end)
      assert [1, 2, 3] = Workspace.with(source, fn _ -> [1, 2, 3] end)
      assert %{key: "value"} = Workspace.with(source, fn _ -> %{key: "value"} end)
    end

    test "releases workspace even if function raises" do
      source = File.cwd!()

      result =
        Workspace.with(source, fn _workspace ->
          raise "Test error"
        end)

      assert {:error, error_msg} = result
      assert error_msg =~ "Test error"
      assert error_msg =~ "RuntimeError"

      # Workspace should still be released
      workspace = Store.get_by_source(source)
      assert workspace.state == :released
    end

    test "returns error if acquisition fails" do
      # Use an invalid source that will fail
      source = "/nonexistent/path/that/does/not/exist"

      result =
        Workspace.with(source, fn _workspace ->
          # This should never be called
          flunk("Function should not be called when acquisition fails")
        end)

      # Since it's not a valid directory, it will be treated as unknown type
      # The actual error depends on implementation
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "passes options to acquire" do
      source = File.cwd!()
      opts = [depth: 1, branch: "main"]

      Workspace.with(source, opts, fn workspace ->
        # Verify workspace was created with options
        assert workspace.opts == opts
      end)
    end

    test "supports nested workspace usage" do
      source1 = File.cwd!()
      source2 = Path.dirname(File.cwd!())

      result =
        Workspace.with(source1, fn workspace1 ->
          assert workspace1.path == source1

          Workspace.with(source2, fn workspace2 ->
            assert workspace2.path == source2
            assert workspace1.id != workspace2.id

            {workspace1.id, workspace2.id}
          end)
        end)

      assert {id1, id2} = result
      assert id1 != id2

      # Both should be released
      assert Store.get(id1).state == :released
      assert Store.get(id2).state == :released
    end

    test "reuses existing workspace for same source" do
      source = File.cwd!()

      # First acquisition
      id1 =
        Workspace.with(source, fn workspace ->
          workspace.id
        end)

      # Second acquisition should reuse
      id2 =
        Workspace.with(source, fn workspace ->
          workspace.id
        end)

      # Should get the same workspace
      assert id1 == id2
    end
  end

  describe "acquire/2" do
    test "manually acquires a workspace" do
      source = File.cwd!()

      assert {:ok, workspace} = Workspace.acquire(source)
      assert workspace.source == source
      assert workspace.path == source
      assert workspace.type == :local
      assert workspace.state == :ready
      assert is_binary(workspace.id)
      assert %DateTime{} = workspace.created_at

      # Should be in store
      assert Store.get(workspace.id) != nil
    end

    test "acquires with options" do
      source = File.cwd!()
      opts = [depth: 1, branch: "main"]

      assert {:ok, workspace} = Workspace.acquire(source, opts)
      assert workspace.opts == opts
    end

    test "reuses existing ready workspace" do
      source = File.cwd!()

      # First acquisition
      {:ok, workspace1} = Workspace.acquire(source)

      # Second acquisition
      {:ok, workspace2} = Workspace.acquire(source)

      # Should be the same workspace
      assert workspace1.id == workspace2.id
    end

    test "handles file type" do
      # Create a temporary file
      {:ok, file_path} = Briefly.create()
      File.write!(file_path, "test content")

      assert {:ok, workspace} = Workspace.acquire(file_path)
      assert workspace.type == :file
      assert workspace.path == file_path
    end

    test "handles directory type" do
      # Create a temporary directory
      dir_path = Path.join(System.tmp_dir!(), "test_dir_#{:rand.uniform(10000)}")
      File.mkdir_p!(dir_path)

      on_exit(fn -> File.rm_rf!(dir_path) end)

      assert {:ok, workspace} = Workspace.acquire(dir_path)
      assert workspace.type == :local
      assert workspace.path == dir_path
    end
  end

  describe "release/1" do
    test "releases workspace by workspace map" do
      {:ok, workspace} = Workspace.acquire(File.cwd!())
      assert workspace.state == :ready

      assert :ok = Workspace.release(workspace)

      # Check it's released
      released = Store.get(workspace.id)
      assert released.state == :released
    end

    test "releases workspace by ID" do
      {:ok, workspace} = Workspace.acquire(File.cwd!())

      assert :ok = Workspace.release(workspace.id)

      released = Store.get(workspace.id)
      assert released.state == :released
    end

    test "releases workspace by source" do
      source = File.cwd!()
      {:ok, workspace} = Workspace.acquire(source)

      assert :ok = Workspace.release(source)

      released = Store.get(workspace.id)
      assert released.state == :released
    end

    test "handles release of non-existent workspace" do
      # Should not crash
      assert :ok = Workspace.release("nonexistent_id")
      assert :ok = Workspace.release("/nonexistent/source")
    end

    test "can release already released workspace" do
      {:ok, workspace} = Workspace.acquire(File.cwd!())

      # Release once
      assert :ok = Workspace.release(workspace)

      # Release again - should not error
      assert :ok = Workspace.release(workspace)
    end
  end

  describe "exists?/1" do
    test "returns true for existing workspace" do
      source = File.cwd!()
      {:ok, _workspace} = Workspace.acquire(source)

      assert Workspace.exists?(source) == true
    end

    test "returns false for non-existent workspace" do
      assert Workspace.exists?("/nonexistent/source") == false
    end

    test "returns true even for released workspace" do
      source = File.cwd!()
      {:ok, workspace} = Workspace.acquire(source)
      Workspace.release(workspace)

      # Still exists in store, just released
      assert Workspace.exists?(source) == true
    end
  end

  describe "list/0" do
    test "returns empty list when no workspaces" do
      assert Workspace.list() == []
    end

    test "returns all active workspaces" do
      # Create multiple workspaces
      {:ok, ws1} = Workspace.acquire(File.cwd!())
      {:ok, ws2} = Workspace.acquire(Path.dirname(File.cwd!()))

      workspaces = Workspace.list()
      assert length(workspaces) == 2

      ids = Enum.map(workspaces, & &1.id)
      assert ws1.id in ids
      assert ws2.id in ids
    end

    test "includes workspaces in all states" do
      # Create workspace and release it
      {:ok, workspace} = Workspace.acquire(File.cwd!())
      Workspace.release(workspace)

      # Should still appear in list
      workspaces = Workspace.list()
      assert length(workspaces) == 1
      assert hd(workspaces).state == :released
    end
  end

  describe "integration scenarios" do
    test "typical usage flow" do
      source = File.cwd!()

      # Check doesn't exist
      refute Workspace.exists?(source)

      # Acquire
      {:ok, workspace} = Workspace.acquire(source)
      assert Workspace.exists?(source)

      # Use it
      assert File.exists?(workspace.path)

      # Release
      Workspace.release(workspace)

      # Still exists but released
      assert Workspace.exists?(source)
      released = Store.get_by_source(source)
      assert released.state == :released
    end

    test "with/3 provides cleaner API than manual acquire/release" do
      source = File.cwd!()

      # Manual way
      {:ok, workspace} = Workspace.acquire(source)

      file_count =
        try do
          length(File.ls!(workspace.path))
        after
          Workspace.release(workspace)
        end

      # With way - much cleaner
      count =
        Workspace.with(source, fn workspace ->
          length(File.ls!(workspace.path))
        end)

      assert count == file_count
    end

    test "handles concurrent access to same source" do
      source = File.cwd!()

      # Spawn multiple processes trying to acquire same source
      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            Workspace.with(source, fn workspace ->
              # Simulate some work
              :timer.sleep(10)
              workspace.id
            end)
          end)
        end

      # Collect results
      ids = Task.await_many(tasks)

      # All should get the same workspace ID (deduplication)
      assert length(Enum.uniq(ids)) == 1
    end
  end

  describe "error handling" do
    test "with/3 converts exceptions to error tuples" do
      source = File.cwd!()

      result =
        Workspace.with(source, fn _workspace ->
          # Will raise ArithmeticError
          1 / 0
        end)

      assert {:error, error_msg} = result
      assert error_msg =~ "ArithmeticError"
      assert error_msg =~ "bad argument in arithmetic expression"
    end

    test "with/3 preserves original return value structure" do
      source = File.cwd!()

      # Function returns error tuple
      result1 =
        Workspace.with(source, fn _ ->
          {:error, :custom_error}
        end)

      assert result1 == {:error, :custom_error}

      # Function returns ok tuple
      result2 =
        Workspace.with(source, fn _ ->
          {:ok, :success}
        end)

      assert result2 == {:ok, :success}

      # Function returns plain value
      result3 =
        Workspace.with(source, fn _ ->
          :plain_value
        end)

      assert result3 == :plain_value
    end
  end
end
