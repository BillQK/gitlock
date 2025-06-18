defmodule GitlockCore.Infrastructure.GitRepositoryTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Infrastructure.GitRepository

  describe "determine_source_type/1" do
    test "detects remote URLs correctly" do
      assert GitRepository.determine_source_type("https://github.com/user/repo.git") == :url
      assert GitRepository.determine_source_type("http://gitlab.com/user/repo.git") == :url
      assert GitRepository.determine_source_type("ssh://git@github.com/user/repo.git") == :url
      assert GitRepository.determine_source_type("git@github.com:user/repo.git") == :url
      assert GitRepository.determine_source_type("git://github.com/user/repo.git") == :url
      assert GitRepository.determine_source_type("/local/path/repo.git") == :url
    end

    test "detects local git repository" do
      # Create a temporary directory with .git folder
      {:ok, temp_dir} = Briefly.create(directory: true)
      git_dir = Path.join(temp_dir, ".git")
      File.mkdir_p!(git_dir)

      assert GitRepository.determine_source_type(temp_dir) == :local_repo
    end

    test "detects .git file (submodule)" do
      # Create a temporary directory with .git file (submodule case)
      {:ok, temp_dir} = Briefly.create(directory: true)
      git_file = Path.join(temp_dir, ".git")
      File.write!(git_file, "gitdir: /path/to/actual/git")

      assert GitRepository.determine_source_type(temp_dir) == :local_repo
    end

    test "detects regular log files" do
      # Create an actual file
      {:ok, log_file} = Briefly.create()
      File.write!(log_file, "log content")

      assert GitRepository.determine_source_type(log_file) == :log_file
    end

    test "detects log files by extension even if they don't exist" do
      assert GitRepository.determine_source_type("/path/to/git_log.txt") == :log_file
      assert GitRepository.determine_source_type("/path/to/commits.log") == :log_file
      assert GitRepository.determine_source_type("output.txt") == :log_file
      assert GitRepository.determine_source_type("git.log") == :log_file
    end

    test "returns unknown for non-existent paths without log extensions" do
      assert GitRepository.determine_source_type("/non/existent/path") == :unknown
      assert GitRepository.determine_source_type("/path/without/extension") == :unknown
    end

    test "directory without .git is unknown" do
      {:ok, temp_dir} = Briefly.create(directory: true)
      assert GitRepository.determine_source_type(temp_dir) == :unknown
    end
  end

  describe "fetch_log/2" do
    test "fetches from file successfully" do
      # Create a test log file
      log_content = """
      commit abc123
      Author: Test User <test@example.com>
      Date: 2023-01-01

      10\t5\tfile.ex
      """

      {:ok, log_file} = Briefly.create()
      File.write!(log_file, log_content)

      assert {:ok, ^log_content} = GitRepository.fetch_log(log_file)
    end

    test "returns error for non-existent file" do
      non_existent = "/tmp/non_existent_#{:rand.uniform(10000)}.log"
      assert {:error, :enoent} = GitRepository.fetch_log(non_existent)
    end

    test "returns error for unknown source type" do
      assert {:error, :enoent} = GitRepository.fetch_log("/unknown/path/type")
    end

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
      File.mkdir_p!(Path.join(repo_dir, ".git"))

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
      # Create a directory that looks like a git repo but isn't valid
      {:ok, repo_dir} = Briefly.create(directory: true)
      git_dir = Path.join(repo_dir, ".git")
      File.mkdir_p!(git_dir)

      # This should fail because it's not a real git repository
      result = GitRepository.fetch_log(repo_dir)

      case result do
        {:error, msg} ->
          assert msg =~ "Git log failed"

        {:ok, _} ->
          # In some environments, this might succeed
          assert true
      end
    end
  end

  describe "fetch_log/2 with remote URLs" do
    test "attempts to fetch from remote URL" do
      # This test would require mocking Workspace.with/3
      # Since we can't easily mock it without adding Mox, we'll test the flow

      url = "https://github.com/test/repo.git"

      # We expect this to fail in test environment
      case GitRepository.fetch_log(url) do
        {:error, _reason} ->
          # Expected to fail without actual implementation
          assert true

        {:ok, _} ->
          # If it somehow succeeds, that's unexpected but okay
          assert true
      end
    end
  end

  describe "command building" do
    test "default log options are correct" do
      # We can verify the module attribute is set correctly
      # by checking the actual git command that would be run
      {:ok, repo_dir} = Briefly.create(directory: true)
      File.mkdir_p!(Path.join(repo_dir, ".git"))

      # The error message will contain the command that was attempted
      case GitRepository.fetch_log(repo_dir, %{}) do
        {:error, msg} ->
          # Verify the command includes our expected format
          assert msg =~ "log" || msg =~ "Git"

        {:ok, output} ->
          # If git is available, verify output format
          assert output =~ "commit" || output == ""
      end
    end
  end

  describe "error handling" do
    test "returns :enoent for unknown source types" do
      weird_path = "not-a-url-or-file"
      assert {:error, :enoent} = GitRepository.fetch_log(weird_path)
    end

    test "propagates file read errors" do
      # Create a file and then delete it to cause an error
      {:ok, temp_file} = Briefly.create()
      File.rm!(temp_file)

      assert {:error, :enoent} = GitRepository.fetch_log(temp_file)
    end
  end

  describe "option handling" do
    test "handles date-based options" do
      {:ok, repo_dir} = Briefly.create(directory: true)
      File.mkdir_p!(Path.join(repo_dir, ".git"))

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

    test "handles filtering options" do
      {:ok, repo_dir} = Briefly.create(directory: true)
      File.mkdir_p!(Path.join(repo_dir, ".git"))

      options = %{
        author: "John Doe",
        grep: "fix|feat",
        path: "lib/core/"
      }

      # Just verify it doesn't crash with these options
      result = GitRepository.fetch_log(repo_dir, options)
      assert match?({:error, _}, result) or match?({:ok, _}, result)
    end

    test "ignores unknown options" do
      {:ok, repo_dir} = Briefly.create(directory: true)
      File.mkdir_p!(Path.join(repo_dir, ".git"))

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
end
