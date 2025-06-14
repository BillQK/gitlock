defmodule GitlockCLI.RepositorySourceTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  alias GitlockCLI.RepositorySource

  describe "determine/1" do
    test "prioritizes repo option" do
      options = %{
        repo: "/path/to/repo",
        url: "https://github.com/user/repo.git",
        log: "git_log.txt"
      }

      assert {"/path/to/repo", _} = RepositorySource.determine(options)
    end

    test "uses url option when repo is not provided" do
      options = %{url: "https://github.com/user/repo.git", log: "git_log.txt"}

      assert {"https://github.com/user/repo.git", :url} = RepositorySource.determine(options)
    end

    test "uses log option with warning when repo and url are not provided" do
      options = %{log: "git_log.txt"}

      warning =
        capture_io(:stderr, fn ->
          assert {"git_log.txt", :log_file} = RepositorySource.determine(options)
        end)

      assert warning =~ "Warning: The --log option is deprecated"
    end

    test "defaults to current directory when no options are provided" do
      options = %{}

      assert {".", :local_repo} = RepositorySource.determine(options)
    end
  end

  describe "determine_source_type/1" do
    test "detects HTTP URLs" do
      assert RepositorySource.determine_source_type("https://github.com/user/repo.git") == :url
      assert RepositorySource.determine_source_type("http://github.com/user/repo") == :url
    end

    test "detects SSH URLs" do
      assert RepositorySource.determine_source_type("git@github.com:user/repo.git") == :url
    end

    test "detects local git repository" do
      # Create a temporary directory with .git folder to simulate a repository
      {:ok, temp_dir} = Briefly.create(directory: true)
      git_dir = Path.join(temp_dir, ".git")

      File.mkdir_p!(git_dir)
      assert RepositorySource.determine_source_type(temp_dir) == :local_repo
    end

    test "detects log files" do
      assert RepositorySource.determine_source_type("git_log.txt") == :log_file
      assert RepositorySource.determine_source_type("commits.log") == :log_file
    end

    test "returns unknown for paths that don't exist and don't match patterns" do
      assert RepositorySource.determine_source_type("/non/existent/path/with/no/extension") ==
               :log_file
    end
  end
end
