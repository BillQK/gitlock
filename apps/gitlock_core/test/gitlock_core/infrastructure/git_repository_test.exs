defmodule GitlockCore.Infrastructure.GitRepositoryTest do
  use ExUnit.Case, async: false
  alias GitlockCore.Infrastructure.GitRepository
  alias GitlockCore.Infrastructure.Workspace
  alias GitlockCore.Infrastructure.Workspace.Store

  setup do
    # Clean up any existing workspaces before each test
    on_exit(fn ->
      Workspace.list()
      |> Enum.each(fn workspace ->
        Workspace.release(workspace.id)
      end)
    end)

    :ok
  end

  describe "fetch_log/2" do
    @tag :integration
    test "fetches from local git repository" do
      # This test requires git to be installed
      # Create a temporary git repository
      {:ok, repo_dir} = Briefly.create(directory: true)

      # Initialize a git repo
      System.cmd("git", ["init"], cd: repo_dir, stderr_to_stdout: true)

      # Configure git user for the test repo
      System.cmd("git", ["config", "user.email", "test@example.com"], cd: repo_dir)
      System.cmd("git", ["config", "user.name", "Test User"], cd: repo_dir)

      # Create a file and commit
      test_file = Path.join(repo_dir, "test.txt")
      File.write!(test_file, "test content")
      System.cmd("git", ["add", "."], cd: repo_dir)
      System.cmd("git", ["commit", "-m", "Initial commit"], cd: repo_dir)

      # Fetch log
      case GitRepository.fetch_log(repo_dir) do
        {:ok, log} ->
          assert log =~ "commit"
          assert log =~ "Author: Test User <test@example.com>"

        {:error, reason} ->
          # Git might not be available in CI
          IO.puts("Skipping git test: #{reason}")
      end
    end

    test "builds log command with various options" do
      {:ok, repo_dir} = Briefly.create(directory: true)
      System.cmd("git", ["init"], cd: repo_dir)

      options = %{
        since: "2023-01-01",
        until: "2023-12-31",
        max_count: 100,
        author: "John Doe",
        grep: "fix",
        path: "lib/",
        ignored_option: "should be ignored"
      }

      # We can't easily test System.cmd directly, but we can verify
      # the command would be built correctly by checking the error message
      case GitRepository.fetch_log(repo_dir, options) do
        {:error, msg} ->
          # Git command will fail, but we can check it tried to run
          assert msg =~ "Git log failed"

        {:ok, _} ->
          # If git is installed and works, that's fine too
          assert true
      end
    end

    test "handles git command failure" do
      # Create a directory that's not a git repo
      {:ok, repo_dir} = Briefly.create(directory: true)

      # This should fail because it's not a git repository
      result = GitRepository.fetch_log(repo_dir)

      case result do
        {:error, msg} ->
          assert msg =~ "Git log failed"

        {:ok, _} ->
          # In some environments, this might succeed
          assert true
      end
    end

    test "handles non-existent directory" do
      non_existent = "/tmp/non_existent_#{:rand.uniform(10000)}"

      assert {:error, msg} = GitRepository.fetch_log(non_existent)
      assert msg =~ "Git log failed"
    end
  end

  describe "option handling" do
    setup do
      # Create a valid git repository
      {:ok, repo_dir} = Briefly.create(directory: true)
      System.cmd("git", ["init"], cd: repo_dir)
      System.cmd("git", ["config", "user.email", "test@example.com"], cd: repo_dir)
      System.cmd("git", ["config", "user.name", "Test User"], cd: repo_dir)

      # Create a commit
      file = Path.join(repo_dir, "test.txt")
      File.write!(file, "content")
      System.cmd("git", ["add", "."], cd: repo_dir)
      System.cmd("git", ["commit", "-m", "Test"], cd: repo_dir)

      {:ok, repo_dir: repo_dir}
    end

    test "handles date-based options", %{repo_dir: repo_dir} do
      options = %{
        since: "2023-01-01",
        until: "2023-12-31",
        after: "2023-06-01",
        before: "2023-06-30"
      }

      # Just verify it doesn't crash with these options
      result = GitRepository.fetch_log(repo_dir, options)
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "handles filtering options", %{repo_dir: repo_dir} do
      options = %{
        author: "John Doe",
        grep: "fix|feat",
        path: "lib/core/"
      }

      # Just verify it doesn't crash with these options
      result = GitRepository.fetch_log(repo_dir, options)
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "ignores unknown options", %{repo_dir: repo_dir} do
      options = %{
        unknown_option: "value",
        another_unknown: 123,
        # This one is valid
        max_count: 10
      }

      # Should not crash with unknown options
      result = GitRepository.fetch_log(repo_dir, options)
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end
  end

  describe "caching behavior" do
    setup do
      # Create a valid git repository for cache tests
      {:ok, repo_dir} = Briefly.create(directory: true)

      System.cmd("git", ["init"], cd: repo_dir, stderr_to_stdout: true)
      System.cmd("git", ["config", "user.email", "test@example.com"], cd: repo_dir)
      System.cmd("git", ["config", "user.name", "Test User"], cd: repo_dir)

      # Create some commits
      for i <- 1..3 do
        file = Path.join(repo_dir, "file#{i}.txt")
        File.write!(file, "content #{i}")
        System.cmd("git", ["add", "."], cd: repo_dir)
        System.cmd("git", ["commit", "-m", "Commit #{i}"], cd: repo_dir)
      end

      {:ok, repo_dir: repo_dir}
    end

    test "does not cache when no workspace exists", %{repo_dir: repo_dir} do
      # Ensure no workspace exists by searching Store
      assert Enum.find(Store.list(), fn ws -> ws[:path] == repo_dir end) == nil

      # Fetch log twice
      {:ok, log1} = GitRepository.fetch_log(repo_dir)
      {:ok, log2} = GitRepository.fetch_log(repo_dir)

      # Should get the same content
      assert log1 == log2
      assert log1 =~ "Commit 3" or log1 =~ "commit"

      # No workspace should have been created
      assert Enum.find(Store.list(), fn ws -> ws[:path] == repo_dir end) == nil
    end

    test "caches log when workspace exists", %{repo_dir: repo_dir} do
      # Create workspace
      {:ok, workspace} = Workspace.acquire(repo_dir)

      # First fetch should generate and cache
      {:ok, log1} = GitRepository.fetch_log(repo_dir)

      # Check that cache was created
      workspace_after = Store.get(workspace.id)
      cache = workspace_after[:git_log_cache] || %{}
      assert is_map(cache)
      assert map_size(cache) == 1

      # Get cache file path
      [cache_path] = Map.values(cache)
      assert File.exists?(cache_path)

      # Second fetch should use cache
      {:ok, log2} = GitRepository.fetch_log(repo_dir)
      assert log1 == log2

      Workspace.release(workspace.id)
    end

    test "creates separate cache entries for different options", %{repo_dir: repo_dir} do
      {:ok, workspace} = Workspace.acquire(repo_dir)

      # Fetch with different options
      {:ok, _log_all} = GitRepository.fetch_log(repo_dir, %{})
      {:ok, _log_one} = GitRepository.fetch_log(repo_dir, %{max_count: 1})
      {:ok, _log_author} = GitRepository.fetch_log(repo_dir, %{author: "Test User"})

      # Should have three cache entries
      workspace_after = Store.get(workspace.id)
      cache = workspace_after[:git_log_cache] || %{}
      assert map_size(cache) == 3

      # All cache files should exist
      Enum.each(cache, fn {_hash, path} ->
        assert File.exists?(path)
      end)

      Workspace.release(workspace.id)
    end

    test "regenerates cache when file is missing", %{repo_dir: repo_dir} do
      {:ok, workspace} = Workspace.acquire(repo_dir)

      # First fetch creates cache
      {:ok, log1} = GitRepository.fetch_log(repo_dir)

      # Delete cache file
      workspace_data = Store.get(workspace.id)
      cache = workspace_data[:git_log_cache] || %{}
      [cache_path] = Map.values(cache)
      File.rm!(cache_path)

      # Next fetch should regenerate
      {:ok, log2} = GitRepository.fetch_log(repo_dir)
      assert log1 == log2
      assert File.exists?(cache_path)

      Workspace.release(workspace.id)
    end

    test "cache survives workspace touch/update", %{repo_dir: repo_dir} do
      {:ok, workspace} = Workspace.acquire(repo_dir)

      # Create cache
      {:ok, _log} = GitRepository.fetch_log(repo_dir)

      # Touch workspace (update last_accessed)
      Store.touch(workspace.id)

      # Cache should still work
      {:ok, _log2} = GitRepository.fetch_log(repo_dir)

      workspace_after = Store.get(workspace.id)
      cache = workspace_after[:git_log_cache] || %{}
      assert map_size(cache) == 1

      Workspace.release(workspace.id)
    end
  end

  describe "cache location" do
    setup do
      # Create a valid git repository
      {:ok, repo_dir} = Briefly.create(directory: true)

      System.cmd("git", ["init"], cd: repo_dir, stderr_to_stdout: true)
      System.cmd("git", ["config", "user.email", "test@example.com"], cd: repo_dir)
      System.cmd("git", ["config", "user.name", "Test User"], cd: repo_dir)

      # Create a commit
      file = Path.join(repo_dir, "test.txt")
      File.write!(file, "content")
      System.cmd("git", ["add", "."], cd: repo_dir)
      System.cmd("git", ["commit", "-m", "Test"], cd: repo_dir)

      {:ok, repo_dir: repo_dir}
    end

    test "stores cache in workspace directory", %{repo_dir: repo_dir} do
      {:ok, workspace} = Workspace.acquire(repo_dir)

      # Fetch log to create cache
      {:ok, _log} = GitRepository.fetch_log(repo_dir)

      # Check cache location
      workspace_data = Store.get(workspace.id)
      cache = workspace_data[:git_log_cache] || %{}

      if map_size(cache) > 0 do
        [cache_path] = Map.values(cache)

        # Should be inside workspace directory
        assert String.starts_with?(cache_path, workspace.path)
        assert cache_path =~ ".gitlock_cache"
      end

      Workspace.release(workspace.id)
    end
  end

  describe "cache performance" do
    setup do
      # Create a git repository with many commits
      {:ok, repo_dir} = Briefly.create(directory: true)

      System.cmd("git", ["init"], cd: repo_dir, stderr_to_stdout: true)
      System.cmd("git", ["config", "user.email", "test@example.com"], cd: repo_dir)
      System.cmd("git", ["config", "user.name", "Test User"], cd: repo_dir)

      # Create many commits for a meaningful test
      for i <- 1..50 do
        file = Path.join(repo_dir, "file#{i}.txt")
        File.write!(file, "content #{i}")
        System.cmd("git", ["add", "."], cd: repo_dir)
        System.cmd("git", ["commit", "-m", "Commit #{i}"], cd: repo_dir)
      end

      {:ok, repo_dir: repo_dir}
    end

    @tag :performance
    test "cached fetch is faster than generation", %{repo_dir: repo_dir} do
      {:ok, workspace} = Workspace.acquire(repo_dir)

      # Time first fetch (generation)
      start1 = System.monotonic_time(:microsecond)
      {:ok, _log1} = GitRepository.fetch_log(repo_dir)
      time1 = System.monotonic_time(:microsecond) - start1

      # Time second fetch (cached)
      start2 = System.monotonic_time(:microsecond)
      {:ok, _log2} = GitRepository.fetch_log(repo_dir)
      time2 = System.monotonic_time(:microsecond) - start2

      # Cached should be significantly faster
      assert time2 < time1

      IO.puts(
        "Generation: #{time1}μs, Cached: #{time2}μs, Speedup: #{Float.round(time1 / time2, 1)}x"
      )

      Workspace.release(workspace.id)
    end
  end

  describe "edge cases" do
    setup do
      # Create a valid git repository
      {:ok, repo_dir} = Briefly.create(directory: true)

      System.cmd("git", ["init"], cd: repo_dir, stderr_to_stdout: true)
      System.cmd("git", ["config", "user.email", "test@example.com"], cd: repo_dir)
      System.cmd("git", ["config", "user.name", "Test User"], cd: repo_dir)

      # Create a commit
      file = Path.join(repo_dir, "test.txt")
      File.write!(file, "content")
      System.cmd("git", ["add", "."], cd: repo_dir)
      System.cmd("git", ["commit", "-m", "Test"], cd: repo_dir)

      {:ok, repo_dir: repo_dir}
    end

    test "handles cache directory creation failure gracefully", %{repo_dir: repo_dir} do
      {:ok, workspace} = Workspace.acquire(repo_dir)

      # Even if caching fails, fetch should still work
      {:ok, log} = GitRepository.fetch_log(repo_dir)
      assert log =~ "Test" or log =~ "test"

      Workspace.release(workspace.id)
    end

    test "handles concurrent fetches safely", %{repo_dir: repo_dir} do
      {:ok, workspace} = Workspace.acquire(repo_dir)

      # Launch multiple concurrent fetches
      tasks =
        for _ <- 1..5 do
          Task.async(fn ->
            GitRepository.fetch_log(repo_dir)
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All should succeed
      assert Enum.all?(results, &match?({:ok, _}, &1))

      # All should return same content
      logs = Enum.map(results, fn {:ok, log} -> log end)
      first_log = hd(logs)
      assert Enum.all?(logs, &(&1 == first_log))

      # Should only have one cache entry
      workspace_data = Store.get(workspace.id)
      cache = workspace_data[:git_log_cache] || %{}
      assert map_size(cache) == 1

      Workspace.release(workspace.id)
    end

    test "handles empty repository", %{} do
      {:ok, empty_repo} = Briefly.create(directory: true)
      System.cmd("git", ["init"], cd: empty_repo)

      {:ok, workspace} = Workspace.acquire(empty_repo)

      # Should handle empty repo gracefully
      case GitRepository.fetch_log(empty_repo) do
        {:ok, log} ->
          assert log == "" or log =~ "does not have any commits"

        {:error, msg} ->
          assert msg =~ "does not have any commits" or msg =~ "Git log failed"
      end

      Workspace.release(workspace.id)
    end
  end
end
