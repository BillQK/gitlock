defmodule GitlockHolmesCore.Domain.Services.KnowledgeSiloDetectionTest do
  use ExUnit.Case, async: true

  alias GitlockHolmesCore.Domain.Services.KnowledgeSiloDetection
  alias GitlockHolmesCore.Domain.Entities.{Commit, Author}
  alias GitlockHolmesCore.Domain.Values.{FileChange}

  describe "detect_knowledge_silos/1" do
    test "identifies files with high ownership by a single author" do
      # Create test commits with a clear knowledge silo pattern
      commits = [
        # File A changed many times by Alice
        create_commit("c1", "Alice", ["file_a.ex"]),
        create_commit("c2", "Alice", ["file_a.ex"]),
        create_commit("c3", "Alice", ["file_a.ex"]),
        create_commit("c4", "Alice", ["file_a.ex"]),
        # Only one change by Bob
        create_commit("c5", "Bob", ["file_a.ex"]),

        # File B changed by multiple people
        create_commit("c6", "Alice", ["file_b.ex"]),
        create_commit("c7", "Bob", ["file_b.ex"]),
        create_commit("c8", "Carol", ["file_b.ex"])
      ]

      silos = KnowledgeSiloDetection.detect_knowledge_silos(commits)

      # Should find file_a.ex as a knowledge silo
      file_a_silo = Enum.find(silos, &(&1.entity == "file_a.ex"))
      assert file_a_silo != nil
      assert file_a_silo.main_author == "Alice"
      # Alice owns 80% (4/5)
      assert file_a_silo.ownership_ratio > 70.0
      assert file_a_silo.risk_level == :low

      # file_b.ex should not be a high-risk silo
      file_b_silo = Enum.find(silos, &(&1.entity == "file_b.ex"))
      assert file_b_silo != nil
      assert file_b_silo.risk_level != :high
    end

    test "correctly calculates ownership ratios" do
      # Test with exactly known percentages
      commits = [
        # Alice: 4 commits (80%)
        create_commit("c1", "Alice", ["file.ex"]),
        create_commit("c2", "Alice", ["file.ex"]),
        create_commit("c3", "Alice", ["file.ex"]),
        create_commit("c4", "Alice", ["file.ex"]),
        # Bob: 1 commit (20%)
        create_commit("c5", "Bob", ["file.ex"])
      ]

      [silo] = KnowledgeSiloDetection.detect_knowledge_silos(commits)
      assert silo.entity == "file.ex"
      assert silo.main_author == "Alice"
      assert_in_delta silo.ownership_ratio, 80.0, 0.1
    end
  end

  describe "risk_level_from_metrics/3" do
    test "identifies high risk when ownership ratio is high and commit count is substantial" do
      assert KnowledgeSiloDetection.risk_level_from_metrics(0.85, 15, 1) == :high
    end

    test "identifies medium risk for moderate cases" do
      assert KnowledgeSiloDetection.risk_level_from_metrics(0.95, 6, 1) == :medium
    end

    test "identifies low risk for lower ownership or fewer commits" do
      assert KnowledgeSiloDetection.risk_level_from_metrics(0.85, 4, 2) == :low
      assert KnowledgeSiloDetection.risk_level_from_metrics(0.75, 6, 2) == :low
      assert KnowledgeSiloDetection.risk_level_from_metrics(0.65, 5, 2) == :low
      assert KnowledgeSiloDetection.risk_level_from_metrics(0.95, 2, 1) == :low
    end
  end

  # Helper to create test commits
  defp create_commit(id, author_name, file_paths) do
    file_changes = Enum.map(file_paths, &FileChange.new(&1, 10, 5))

    %Commit{
      id: id,
      author: Author.new(author_name),
      date: ~D[2023-01-01],
      message: "Test commit",
      file_changes: file_changes
    }
  end
end
