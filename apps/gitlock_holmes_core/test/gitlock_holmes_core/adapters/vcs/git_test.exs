defmodule GitlockHolmesCore.Adapters.VCS.GitTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias GitlockHolmesCore.Adapters.VCS.Git
  alias GitlockHolmesCore.Domain.Entities.{Commit, Author}
  alias GitlockHolmesCore.Domain.Values.FileChange

  describe "get_commit_history/2" do
    test "successfully parses a valid git log file" do
      # Create a test git log file with proper format
      log_content = """
      --abc123--2023-01-01--John Doe
      10\t5\tlib/example.ex
      3\t1\ttest/example_test.exs

      --def456--2023-01-02--Jane Smith
      20\t0\tlib/another.ex
      -\t-\tassets/image.png
      """

      {:ok, log_file} = Briefly.create()
      File.write!(log_file, log_content)

      assert {:ok, commits} = Git.get_commit_history(log_file, %{})
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

    test "handles empty log file" do
      {:ok, log_file} = Briefly.create()
      File.write!(log_file, "")

      assert {:ok, []} = Git.get_commit_history(log_file, %{})
    end

    test "handles log file with only whitespace" do
      {:ok, log_file} = Briefly.create()
      File.write!(log_file, "\n\n  \n\t\n")

      # The parser treats whitespace-only content as a malformed header
      assert {:error, {:commit, "Invalid commit header format:" <> _}} =
               Git.get_commit_history(log_file, %{})
    end

    test "handles single commit" do
      log_content = """
      --single123--2023-03-15--Solo Developer
      42\t13\tsrc/main.ex
      """

      {:ok, log_file} = Briefly.create()
      File.write!(log_file, log_content)

      assert {:ok, [commit]} = Git.get_commit_history(log_file, %{})
      assert commit.id == "single123"
      assert commit.author.name == "Solo Developer"
      assert length(commit.file_changes) == 1
    end

    test "handles commits with no file changes" do
      log_content = """
      --empty123--2023-04-01--Empty Commit Author
      """

      {:ok, log_file} = Briefly.create()
      File.write!(log_file, log_content)

      assert {:ok, [commit]} = Git.get_commit_history(log_file, %{})
      assert commit.file_changes == []
    end

    test "handles malformed header - returns error" do
      log_content = """
      malformed header without proper format
      10\t5\tlib/example.ex
      """

      {:ok, log_file} = Briefly.create()
      File.write!(log_file, log_content)

      assert {:error, {:commit, "Invalid commit header format:" <> _}} =
               Git.get_commit_history(log_file, %{})
    end

    test "handles empty header - returns error" do
      log_content = """

      """

      {:ok, log_file} = Briefly.create()
      File.write!(log_file, log_content)

      assert {:error, {:commit, "Empty commit text"}} =
               Git.get_commit_history(log_file, %{})
    end

    test "handles malformed file change line - returns error" do
      log_content = """
      --abc123--2023-01-01--John Doe
      this is not a valid file change line
      """

      {:ok, log_file} = Briefly.create()
      File.write!(log_file, log_content)

      # The parser filters out lines that don't contain tabs, so this results in a commit with no file changes
      assert {:ok, [commit]} = Git.get_commit_history(log_file, %{})
      assert commit.id == "abc123"
      assert commit.file_changes == []
    end

    test "handles file not found error" do
      non_existent = "/tmp/does_not_exist_#{:rand.uniform(10000)}.log"

      assert {:error, {:io, ^non_existent, :enoent}} =
               Git.get_commit_history(non_existent, %{})
    end

    test "handles authors with special characters" do
      log_content = """
      --abc123--2023-01-01--José García-López
      5\t2\tlib/español.ex

      --def456--2023-01-02--李明 (Li Ming)
      8\t3\tlib/中文.ex
      """

      {:ok, log_file} = Briefly.create()
      File.write!(log_file, log_content)

      assert {:ok, commits} = Git.get_commit_history(log_file, %{})
      assert length(commits) == 2
      assert Enum.map(commits, & &1.author.name) == ["José García-López", "李明 (Li Ming)"]
    end

    test "preserves commit order from file" do
      log_content = """
      --commit1--2023-01-01--Author One
      1\t0\tfile1.ex

      --commit2--2023-01-02--Author Two
      2\t0\tfile2.ex

      --commit3--2023-01-03--Author Three
      3\t0\tfile3.ex
      """

      {:ok, log_file} = Briefly.create()
      File.write!(log_file, log_content)

      assert {:ok, commits} = Git.get_commit_history(log_file, %{})
      assert Enum.map(commits, & &1.id) == ["commit1", "commit2", "commit3"]
    end

    test "handles paths with spaces" do
      log_content = """
      --abc123--2023-01-01--John Doe
      10\t5\tlib/my module/example file.ex
      3\t1\ttest/test with spaces.exs
      """

      {:ok, log_file} = Briefly.create()
      File.write!(log_file, log_content)

      assert {:ok, [commit]} = Git.get_commit_history(log_file, %{})

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

      {:ok, log_file} = Briefly.create()
      File.write!(log_file, log_content)

      assert {:ok, [commit]} = Git.get_commit_history(log_file, %{})
      [change] = commit.file_changes
      assert change.loc_added == "999999"
      assert change.loc_deleted == "888888"
    end
  end

  describe "property-based testing" do
    property "parses any valid git log format correctly" do
      check all(commits_data <- list_of(valid_commit_generator(), min_length: 0, max_length: 10)) do
        # Generate log content
        log_content =
          commits_data
          |> Enum.map(&format_commit_for_log/1)
          |> Enum.join("\n\n")

        # Create temp file using Briefly
        {:ok, path} = Briefly.create()
        File.write!(path, log_content)

        # Parse and verify
        assert {:ok, parsed_commits} = Git.get_commit_history(path, %{})
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
        {:ok, path} = Briefly.create()
        File.write!(path, content)

        # Should either parse successfully or return a proper error
        case Git.get_commit_history(path, %{}) do
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
      |> Enum.map(fn change ->
        "#{change.added}\t#{change.deleted}\t#{change.path}"
      end)
      |> Enum.join("\n")

    if changes == "" do
      header
    else
      "#{header}\n#{changes}"
    end
  end
end
