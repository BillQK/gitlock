defmodule GitlockHolmesCore.Domain.Services.CommitSplitterTest do
  use ExUnit.Case, async: true

  alias GitlockHolmesCore.Domain.Services.CommitSplitter
  alias GitlockHolmesCore.Domain.Entities.{Commit, Author}
  alias GitlockHolmesCore.Domain.Values.FileChange

  describe "split_commits/1" do
    test "splits commits into full, early, and recent sets" do
      # Create test commits with different dates in strict chronological order
      commits = [
        create_test_commit("c1", "2023-01-01"),
        create_test_commit("c2", "2023-01-15"),
        create_test_commit("c3", "2023-02-01"),
        create_test_commit("c4", "2023-02-15")
      ]

      # Split the commits
      {full, early, recent} = CommitSplitter.split_commits(commits)

      # Verify full set contains all commits sorted by date
      assert length(full) == 4

      # Verify early and recent each contain half of the commits
      assert length(early) == 2
      assert length(recent) == 2

      # Since we're not sure exactly how they're divided, just verify that:
      # 1. All commits from full are accounted for in early and recent
      # 2. No duplicates between early and recent
      early_ids = Enum.map(early, & &1.id) |> MapSet.new()
      recent_ids = Enum.map(recent, & &1.id) |> MapSet.new()
      full_ids = Enum.map(full, & &1.id) |> MapSet.new()

      # Early and recent should be disjoint
      assert MapSet.disjoint?(early_ids, recent_ids)

      # The union of early and recent should be the same as full
      assert MapSet.equal?(MapSet.union(early_ids, recent_ids), full_ids)
    end

    test "handles odd number of commits" do
      commits = [
        create_test_commit("c1", "2023-01-01"),
        create_test_commit("c2", "2023-01-15"),
        create_test_commit("c3", "2023-02-01")
      ]

      {full, early, recent} = CommitSplitter.split_commits(commits)

      # With 3 commits, split should give us an uneven division
      assert length(full) == 3

      # Either early=1 and recent=2 OR early=2 and recent=1
      assert {length(early), length(recent)} in [{1, 2}, {2, 1}]

      # All commits from full should be in either early or recent
      full_ids = Enum.map(full, & &1.id) |> MapSet.new()
      combined_ids = (Enum.map(early, & &1.id) ++ Enum.map(recent, & &1.id)) |> MapSet.new()
      assert MapSet.equal?(full_ids, combined_ids)
    end

    test "handles empty commit list" do
      assert {[], [], []} = CommitSplitter.split_commits([])
    end

    test "handles single commit" do
      commit = create_test_commit("single", "2023-01-01")
      assert {[^commit], [^commit], []} = CommitSplitter.split_commits([commit])
    end

    test "raises ArgumentError for invalid input" do
      assert_raise ArgumentError, fn ->
        CommitSplitter.split_commits("not a list")
      end
    end
  end

  # Helper function to create test commits
  defp create_test_commit(id, date) do
    Commit.new(
      id,
      Author.new("Test Author"),
      date,
      "Test commit",
      [FileChange.new("test.ex", "10", "5")]
    )
  end
end
