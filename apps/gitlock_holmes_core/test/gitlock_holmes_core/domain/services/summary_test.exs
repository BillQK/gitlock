defmodule GitlockHolmesCore.Domain.Services.SummaryTest do
  use ExUnit.Case, async: true

  alias GitlockHolmesCore.Domain.Services.Summary
  alias GitlockHolmesCore.Domain.Entities.{Commit, Author}
  alias GitlockHolmesCore.Domain.Values.FileChange

  describe "summarize/1" do
    test "calculates correct counts for commits, authors and entities" do
      # Create test commits
      commits = [
        # Commit 1: Author A, 2 files
        create_commit("c1", "Author A", [
          "file1.ex",
          "file2.ex"
        ]),

        # Commit 2: Author B, 1 file
        create_commit("c2", "Author B", [
          "file3.ex"
        ]),

        # Commit 3: Author A again, 1 file (already seen)
        create_commit("c3", "Author A", [
          "file1.ex"
        ])
      ]

      summary = Summary.summarize(commits)

      # Find stats by name
      commit_count = Enum.find(summary, &(&1.statistic == "number-of-commits"))
      author_count = Enum.find(summary, &(&1.statistic == "number-of-authors"))
      entity_count = Enum.find(summary, &(&1.statistic == "number-of-entities"))

      # Verify counts
      # 3 commits
      assert commit_count.value == 3
      # 2 unique authors
      assert author_count.value == 2
      # 3 unique files
      assert entity_count.value == 3
    end

    test "handles empty commit list" do
      summary = Summary.summarize([])

      # All counts should be zero
      assert Enum.all?(summary, &(&1.value == 0))
    end

    test "handles commits with no file changes" do
      commits = [
        %Commit{
          id: "empty",
          author: Author.new("Author"),
          date: ~D[2023-01-01],
          message: "Empty commit",
          file_changes: []
        }
      ]

      summary = Summary.summarize(commits)

      # Should have 1 commit, 1 author, 0 entities
      commit_count = Enum.find(summary, &(&1.statistic == "number-of-commits"))
      author_count = Enum.find(summary, &(&1.statistic == "number-of-authors"))
      entity_count = Enum.find(summary, &(&1.statistic == "number-of-entities"))

      assert commit_count.value == 1
      assert author_count.value == 1
      assert entity_count.value == 0
    end
  end

  # Helper to create test commits
  defp create_commit(id, author_name, file_paths) do
    file_changes =
      Enum.map(file_paths, fn path ->
        FileChange.new(path, 10, 5)
      end)

    %Commit{
      id: id,
      author: Author.new(author_name),
      date: ~D[2023-01-01],
      message: "Test commit",
      file_changes: file_changes
    }
  end
end
