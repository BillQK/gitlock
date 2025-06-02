defmodule GitlockHolmesCore.Domain.Entities.CommitTest do
  use ExUnit.Case, async: true

  alias GitlockHolmesCore.Domain.Entities.{Commit, Author}
  alias GitlockHolmesCore.Domain.Values.FileChange

  describe "new/5" do
    test "creates a commit with valid data" do
      author = Author.new("Jane Smith", "jane@example.com")

      file_changes = [
        FileChange.new("lib/example.ex", 10, 5),
        FileChange.new("test/example_test.exs", 20, 8)
      ]

      commit =
        Commit.new(
          "abc123",
          author,
          "2023-04-21",
          "Fix bug in parser",
          file_changes
        )

      assert commit.id == "abc123"
      assert commit.author == author
      assert commit.date == ~D[2023-04-21]
      assert commit.message == "Fix bug in parser"
      assert commit.file_changes == file_changes
    end

    test "works with empty file changes" do
      author = Author.new("John Doe")
      commit = Commit.new("def456", author, "2023-05-15", "Empty commit")

      assert commit.id == "def456"
      assert commit.file_changes == []
    end
  end

  describe "file_count/1" do
    test "returns the number of files changed" do
      commit = %Commit{
        file_changes: [
          FileChange.new("file1.ex", 10, 5),
          FileChange.new("file2.ex", 15, 3),
          FileChange.new("file3.ex", 8, 2)
        ]
      }

      assert Commit.file_count(commit) == 3
    end

    test "returns 0 for empty changes" do
      commit = %Commit{file_changes: []}
      assert Commit.file_count(commit) == 0
    end
  end

  describe "total_churn/1" do
    test "calculates sum of insertions and deletions" do
      commit = %Commit{
        file_changes: [
          # 15
          FileChange.new("file1.ex", 10, 5),
          # 10
          FileChange.new("file2.ex", 8, 2)
        ]
      }

      assert Commit.total_churn(commit) == 25
    end

    test "handles binary files with dash notation" do
      commit = %Commit{
        file_changes: [
          # 15
          FileChange.new("file1.ex", 10, 5),
          # 0
          FileChange.new("image.png", "-", "-")
        ]
      }

      assert Commit.total_churn(commit) == 15
    end

    test "returns 0 for empty changes" do
      commit = %Commit{file_changes: []}
      assert Commit.total_churn(commit) == 0
    end
  end
end
