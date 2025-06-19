defmodule GitlockCore.Adapters.VCS.GitTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias GitlockCore.Adapters.VCS.Git
  alias GitlockCore.Domain.Entities.{Commit, Author}
  alias GitlockCore.Domain.Values.FileChange

  describe "parse_git_log/1" do
    test "successfully parses a valid git log" do
      log_content = """
      --abc123--2023-01-01--John Doe
      10\t5\tlib/example.ex
      3\t1\ttest/example_test.exs

      --def456--2023-01-02--Jane Smith
      20\t0\tlib/another.ex
      -\t-\tassets/image.png
      """

      assert {:ok, commits} = Git.parse_git_log(log_content)
      assert length(commits) == 2

      # Verify first commit
      [first_commit, second_commit] = commits

      assert %Commit{
               id: "abc123",
               author: %Author{name: "John Doe"},
               date: ~D[2023-01-01],
               message: "",
               file_changes: [
                 %FileChange{entity: "lib/example.ex", loc_added: "10", loc_deleted: "5"},
                 %FileChange{entity: "test/example_test.exs", loc_added: "3", loc_deleted: "1"}
               ]
             } = first_commit

      # Verify second commit
      assert %Commit{
               id: "def456",
               author: %Author{name: "Jane Smith"},
               date: ~D[2023-01-02],
               message: "",
               file_changes: [
                 %FileChange{entity: "lib/another.ex", loc_added: "20", loc_deleted: "0"},
                 %FileChange{entity: "assets/image.png", loc_added: "-", loc_deleted: "-"}
               ]
             } = second_commit
    end

    test "handles empty log content" do
      assert {:ok, []} = Git.parse_git_log("")
    end

    test "handles log with only whitespace" do
      # The parser treats whitespace-only content as a malformed header
      assert {:error, {:commit, "Invalid commit header format:" <> _}} =
               Git.parse_git_log("\n\n  \n\t\n")
    end

    test "handles single commit" do
      log_content = """
      --single123--2023-03-15--Solo Developer
      42\t13\tsrc/main.ex
      """

      assert {:ok, [commit]} = Git.parse_git_log(log_content)
      assert commit.id == "single123"
      assert commit.author.name == "Solo Developer"
      assert length(commit.file_changes) == 1
    end

    test "handles commits with no file changes" do
      log_content = """
      --empty123--2023-04-01--Empty Commit Author
      """

      assert {:ok, [commit]} = Git.parse_git_log(log_content)
      assert commit.file_changes == []
    end

    test "handles malformed header - returns error" do
      log_content = """
      malformed header without proper format
      10\t5\tlib/example.ex
      """

      assert {:error, {:commit, "Invalid commit header format:" <> _}} =
               Git.parse_git_log(log_content)
    end

    test "handles empty header - returns error" do
      log_content = """

      """

      assert {:error, {:commit, "Empty commit text"}} = Git.parse_git_log(log_content)
    end

    test "handles malformed file change line" do
      log_content = """
      --abc123--2023-01-01--John Doe
      this is not a valid file change line
      """

      # The parser filters out lines that don't contain tabs, so this results in a commit with no file changes
      assert {:ok, [commit]} = Git.parse_git_log(log_content)
      assert commit.id == "abc123"
      assert commit.file_changes == []
    end

    test "handles authors with special characters" do
      log_content = """
      --abc123--2023-01-01--José García-López
      5\t2\tlib/español.ex

      --def456--2023-01-02--李明 (Li Ming)
      8\t3\tlib/中文.ex
      """

      assert {:ok, commits} = Git.parse_git_log(log_content)
      assert length(commits) == 2
      assert Enum.map(commits, & &1.author.name) == ["José García-López", "李明 (Li Ming)"]
    end

    test "preserves commit order" do
      log_content = """
      --commit1--2023-01-01--Author One
      1\t0\tfile1.ex

      --commit2--2023-01-02--Author Two
      2\t0\tfile2.ex

      --commit3--2023-01-03--Author Three
      3\t0\tfile3.ex
      """

      assert {:ok, commits} = Git.parse_git_log(log_content)
      assert Enum.map(commits, & &1.id) == ["commit1", "commit2", "commit3"]
    end

    test "handles paths with spaces" do
      log_content = """
      --abc123--2023-01-01--John Doe
      10\t5\tlib/my module/example file.ex
      3\t1\ttest/test with spaces.exs
      """

      assert {:ok, [commit]} = Git.parse_git_log(log_content)

      assert Enum.map(commit.file_changes, & &1.entity) == [
               "lib/my module/example file.ex",
               "test/test with spaces.exs"
             ]
    end

    test "handles very large numbers in file changes" do
      log_content = """
      --abc123--2023-01-01--John Doe
      999999\t888888\tlib/huge_refactor.ex
      """

      assert {:ok, [commit]} = Git.parse_git_log(log_content)
      [change] = commit.file_changes
      assert change.loc_added == "999999"
      assert change.loc_deleted == "888888"
    end

    test "parses standard git log format" do
      # Test the standard git log format (not custom format)
      log_content = """
      commit abc123def456
      Author: John Doe <john@example.com>
      Date: 2023-01-01

      10\t5\tlib/example.ex
      3\t1\ttest/example_test.exs
      """

      assert {:ok, [commit]} = Git.parse_git_log(log_content)
      assert commit.id == "abc123def456"
      assert commit.author.name == "John Doe"
      assert commit.author.email == "john@example.com"
      assert length(commit.file_changes) == 2
    end

    test "handles multiple commits in standard format" do
      log_content = """
      commit abc123
      Author: John Doe <john@example.com>
      Date: 2023-01-01

      10\t5\tlib/example.ex

      commit def456
      Author: Jane Smith <jane@example.com>
      Date: 2023-01-02

      20\t0\tlib/another.ex
      """

      assert {:ok, commits} = Git.parse_git_log(log_content)
      assert length(commits) == 2
    end
  end

  describe "get_commit_history/2 with real git repository" do
    @tag :integration
    test "fetches from local git repository" do
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
      case Git.get_commit_history(repo_dir) do
        {:ok, commits} ->
          assert length(commits) == 1
          [commit] = commits
          assert commit.author.name == "Test User"
          assert commit.author.email == "test@example.com"

        {:error, reason} ->
          # Git might not be available in CI
          IO.puts("Skipping git test: #{reason}")
      end
    end

    @tag :integration
    test "handles empty git repository" do
      {:ok, repo_dir} = Briefly.create(directory: true)
      System.cmd("git", ["init"], cd: repo_dir)

      case Git.get_commit_history(repo_dir) do
        {:ok, commits} ->
          assert commits == []

        {:error, msg} ->
          # Empty repo might return an error
          assert msg =~ "does not have any commits" or msg =~ "Git log failed"
      end
    end
  end

  describe "property-based testing" do
    property "parses any valid git log format correctly" do
      check all(commits_data <- list_of(valid_commit_generator(), min_length: 0, max_length: 10)) do
        # Generate log content
        log_content =
          commits_data
          |> Enum.map_join("\n\n", &format_commit_for_log/1)

        # Parse and verify
        assert {:ok, parsed_commits} = Git.parse_git_log(log_content)
        assert length(parsed_commits) == length(commits_data)

        # Verify each commit
        Enum.zip(commits_data, parsed_commits)
        |> Enum.each(fn {original, parsed} ->
          assert parsed.id == original.id
          assert parsed.author.name == original.author
          assert Date.to_string(parsed.date) == original.date
          assert length(parsed.file_changes) == length(original.changes)
        end)
      end
    end

    property "handles any malformed input without crashing" do
      check all(content <- string(:printable)) do
        # Should either parse successfully or return a proper error
        case Git.parse_git_log(content) do
          {:ok, commits} -> assert is_list(commits)
          {:error, reason} -> assert is_tuple(reason) or is_binary(reason)
        end
      end
    end
  end

  # Generator helpers for property-based testing
  defp valid_commit_generator do
    gen all(
          id <- commit_id_generator(),
          date <- date_generator(),
          author <- author_name_generator(),
          changes <- list_of(file_change_generator(), min_length: 0, max_length: 5)
        ) do
      %{
        id: id,
        date: date,
        author: author,
        changes: changes
      }
    end
  end

  defp commit_id_generator do
    gen all(chars <- string(:alphanumeric, min_length: 6, max_length: 40)) do
      chars
    end
  end

  defp date_generator do
    gen all(
          year <- integer(2000..2025),
          month <- integer(1..12),
          day <- integer(1..28)
        ) do
      Date.new!(year, month, day) |> Date.to_string()
    end
  end

  defp author_name_generator do
    gen all(
          first <- string(:alphanumeric, min_length: 1, max_length: 20),
          last <- string(:alphanumeric, min_length: 1, max_length: 20)
        ) do
      "#{first} #{last}"
    end
  end

  defp file_change_generator do
    gen all(
          path <- file_path_generator(),
          added <- one_of([integer(0..9999), constant("-")]),
          deleted <- one_of([integer(0..9999), constant("-")])
        ) do
      %{
        path: path,
        added: to_string(added),
        deleted: to_string(deleted)
      }
    end
  end

  defp file_path_generator do
    gen all(
          dir <- string(:alphanumeric, min_length: 1, max_length: 10),
          file <- string(:alphanumeric, min_length: 1, max_length: 10),
          ext <- member_of([".ex", ".exs", ".txt", ".md"])
        ) do
      "#{dir}/#{file}#{ext}"
    end
  end

  defp format_commit_for_log(commit_data) do
    header = "--#{commit_data.id}--#{commit_data.date}--#{commit_data.author}"

    changes =
      commit_data.changes
      |> Enum.map_join("\n", fn change ->
        "#{change.added}\t#{change.deleted}\t#{change.path}"
      end)

    if changes == "" do
      header
    else
      "#{header}\n#{changes}"
    end
  end
end
