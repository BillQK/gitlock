defmodule GitlockCore.Domain.Services.CochangeAnalyzerTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Domain.Services.CochangeAnalyzer
  alias GitlockCore.Domain.Entities.{Commit, Author}
  alias GitlockCore.Domain.Values.FileChange

  describe "analyze_commits/1" do
    test "calculates co-change frequencies correctly" do
      # Create test commits with co-changing files
      commits = [
        # file_a and file_b change together twice
        create_test_commit("c1", [{"file_a.ex", 10, 5}, {"file_b.ex", 7, 3}]),
        create_test_commit("c2", [{"file_a.ex", 8, 4}, {"file_b.ex", 5, 2}]),

        # file_a changes alone once
        create_test_commit("c3", [{"file_a.ex", 6, 3}]),

        # file_c changes with file_a once
        create_test_commit("c4", [{"file_a.ex", 5, 2}, {"file_c.ex", 10, 0}])
      ]

      {coupling_data, file_revisions} = CochangeAnalyzer.analyze_commits(commits)

      # Check file revision counts
      # Changed in all 4 commits
      assert file_revisions["file_a.ex"] == 4
      # Changed in 2 commits
      assert file_revisions["file_b.ex"] == 2
      # Changed in 1 commit
      assert file_revisions["file_c.ex"] == 1

      # Check coupling data
      # Changed together twice
      assert coupling_data[{"file_a.ex", "file_b.ex"}] == 2
      # Changed together once
      assert coupling_data[{"file_a.ex", "file_c.ex"}] == 1

      # Check that coupling pairs are normalized (smaller name first)
      refute Map.has_key?(coupling_data, {"file_b.ex", "file_a.ex"})
    end

    test "handles empty commit list" do
      {coupling_data, file_revisions} = CochangeAnalyzer.analyze_commits([])

      assert coupling_data == %{}
      assert file_revisions == %{}
    end

    test "handles commits with single file changes" do
      # No co-change should occur
      commits = [
        create_test_commit("c1", [{"file_a.ex", 10, 5}]),
        create_test_commit("c2", [{"file_b.ex", 7, 3}])
      ]

      {coupling_data, file_revisions} = CochangeAnalyzer.analyze_commits(commits)

      # Should have no coupling data
      assert coupling_data == %{}

      # But should have file revisions
      assert file_revisions["file_a.ex"] == 1
      assert file_revisions["file_b.ex"] == 1
    end

    test "handles duplicate files in same commit" do
      # Create commit with duplicate file (should be counted once)
      commits = [
        create_test_commit("c1", [
          {"file_a.ex", 10, 5},
          {"file_b.ex", 7, 3},
          # Duplicate entry
          {"file_a.ex", 5, 2}
        ])
      ]

      {coupling_data, file_revisions} = CochangeAnalyzer.analyze_commits(commits)

      # Should count file_a only once
      assert file_revisions["file_a.ex"] == 1
      assert file_revisions["file_b.ex"] == 1

      # Should still have coupling
      assert coupling_data[{"file_a.ex", "file_b.ex"}] == 1
    end

    test "handles commits with many files" do
      # Create a commit with many files
      many_files = Enum.map(1..10, fn i -> {"file_#{i}.ex", 5, 2} end)
      commits = [create_test_commit("c1", many_files)]

      {coupling_data, file_revisions} = CochangeAnalyzer.analyze_commits(commits)

      # Should have correct file revisions (all 1)
      Enum.each(1..10, fn i ->
        assert file_revisions["file_#{i}.ex"] == 1
      end)

      # Should have coupling pairs for all combinations
      # 10 choose 2 = 45 pairs
      assert map_size(coupling_data) == 45

      # Fix: Check for the pair in the right order (lexicographical)
      # "file_10.ex" comes before "file_5.ex" when sorted as strings
      if "file_10.ex" < "file_5.ex" do
        assert coupling_data[{"file_10.ex", "file_5.ex"}] == 1
      else
        assert coupling_data[{"file_5.ex", "file_10.ex"}] == 1
      end
    end
  end

  describe "generate_file_pairs/1" do
    test "generates all unique pairs" do
      files = ["a.ex", "b.ex", "c.ex"]
      pairs = CochangeAnalyzer.generate_file_pairs(files)

      # Should have 3 choose 2 = 3 pairs
      assert length(pairs) == 3

      # Check all pairs are present
      assert {"a.ex", "b.ex"} in pairs
      assert {"a.ex", "c.ex"} in pairs
      assert {"b.ex", "c.ex"} in pairs

      # Check order is consistent (first element < second element)
      Enum.each(pairs, fn {a, b} ->
        assert a < b, "Pair #{a}, #{b} is not ordered correctly"
      end)
    end

    test "handles empty or single-item lists" do
      assert CochangeAnalyzer.generate_file_pairs([]) == []
      assert CochangeAnalyzer.generate_file_pairs(["a.ex"]) == []
    end

    test "handles large file lists efficiently" do
      # Generate 100 files
      files = Enum.map(1..100, &"file_#{&1}.ex")

      # Time the operation to ensure it's reasonably fast
      {time, pairs} = :timer.tc(fn -> CochangeAnalyzer.generate_file_pairs(files) end)

      # Should generate 100 choose 2 = 4950 pairs
      assert length(pairs) == 4950

      # Should complete in a reasonable time (less than 1 second)
      assert time < 1_000_000
    end
  end

  # Helper function to create test commits
  defp create_test_commit(id, file_changes) do
    changes =
      Enum.map(file_changes, fn {path, added, deleted} ->
        FileChange.new(path, to_string(added), to_string(deleted))
      end)

    %Commit{
      id: id,
      author: Author.new("Test Author"),
      date: ~D[2023-01-01],
      message: "Test commit",
      file_changes: changes
    }
  end
end
