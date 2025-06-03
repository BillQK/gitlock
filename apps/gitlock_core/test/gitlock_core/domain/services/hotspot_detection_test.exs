defmodule GitlockCore.Domain.Services.HotspotDetectionTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Domain.Services.HotspotDetection
  alias GitlockCore.Domain.Entities.{Commit, Author}
  alias GitlockCore.Domain.Values.{FileChange, ComplexityMetrics}

  describe "detect_hotspots/2" do
    test "identifies files with high change frequency as hotspots" do
      # Create test commits with multiple changes to the same file
      commits = [
        create_commit("commit1", "2023-01-01", [
          {"lib/hotspot.ex", 10, 5},
          {"lib/normal.ex", 5, 2}
        ]),
        create_commit("commit2", "2023-01-02", [
          {"lib/hotspot.ex", 20, 10}
        ]),
        create_commit("commit3", "2023-01-03", [
          {"lib/hotspot.ex", 15, 8},
          {"lib/another.ex", 3, 1}
        ]),
        create_commit("commit4", "2023-01-04", [
          {"lib/hotspot.ex", 25, 12}
        ])
      ]

      hotspots = HotspotDetection.detect_hotspots(commits)

      # The most changed file should be first
      assert [first_hotspot | _] = hotspots
      assert first_hotspot.entity == "lib/hotspot.ex"
      assert first_hotspot.revisions == 4

      # Should identify all unique files
      assert length(hotspots) == 3

      # Get all entities (order determined by risk score)
      entities = Enum.map(hotspots, & &1.entity)
      assert "lib/hotspot.ex" in entities
      assert "lib/normal.ex" in entities
      assert "lib/another.ex" in entities

      # Verify they're sorted by risk score (descending)
      risk_scores = Enum.map(hotspots, & &1.risk_score)
      assert risk_scores == Enum.sort(risk_scores, :desc)
    end

    test "incorporates complexity metrics when provided" do
      commits = [
        create_commit("commit1", "2023-01-01", [
          {"lib/complex.ex", 10, 5},
          {"lib/simple.ex", 10, 5}
        ]),
        create_commit("commit2", "2023-01-02", [
          {"lib/complex.ex", 5, 2},
          {"lib/simple.ex", 5, 2}
        ])
      ]

      # Provide complexity metrics
      complexity_metrics = %{
        "lib/complex.ex" => ComplexityMetrics.new("lib/complex.ex", 200, 25, :elixir),
        "lib/simple.ex" => ComplexityMetrics.new("lib/simple.ex", 50, 2, :elixir)
      }

      hotspots = HotspotDetection.detect_hotspots(commits, complexity_metrics)

      # Complex file should have higher risk despite same revision count
      [first, second] = hotspots
      assert first.entity == "lib/complex.ex"
      assert first.complexity == 25
      assert first.risk_score > second.risk_score
    end

    test "calculates risk scores based on revisions, complexity, and LOC" do
      commits = [
        create_commit("commit1", "2023-01-01", [{"lib/test.ex", 10, 5}])
      ]

      complexity_metrics = %{
        "lib/test.ex" => ComplexityMetrics.new("lib/test.ex", 100, 10, :elixir)
      }

      [hotspot] = HotspotDetection.detect_hotspots(commits, complexity_metrics)

      # Risk score should be calculated
      assert hotspot.risk_score > 0
      assert hotspot.risk_factor in [:high, :medium, :low]
    end

    test "assigns risk levels correctly" do
      # Test the risk level assignment
      assert HotspotDetection.risk_level_from_score(3.0) == :high
      assert HotspotDetection.risk_level_from_score(1.5) == :medium
      assert HotspotDetection.risk_level_from_score(0.5) == :low
    end

    test "handles empty commit list" do
      assert HotspotDetection.detect_hotspots([]) == []
    end

    test "handles commits with no file changes" do
      commits = [
        %Commit{
          id: "empty",
          author: Author.new("Test"),
          date: ~D[2023-01-01],
          message: "Empty commit",
          file_changes: []
        }
      ]

      assert HotspotDetection.detect_hotspots(commits) == []
    end

    test "sorts hotspots by risk score in descending order" do
      # Create commits that will result in different risk scores
      commits = [
        create_commit("c1", "2023-01-01", [{"low_risk.ex", 1, 0}]),
        create_commit("c2", "2023-01-02", [{"high_risk.ex", 50, 20}]),
        create_commit("c3", "2023-01-03", [{"high_risk.ex", 30, 15}]),
        create_commit("c4", "2023-01-04", [{"medium_risk.ex", 10, 5}]),
        create_commit("c5", "2023-01-05", [{"high_risk.ex", 40, 10}])
      ]

      hotspots = HotspotDetection.detect_hotspots(commits)

      # Verify descending order by risk score
      risk_scores = Enum.map(hotspots, & &1.risk_score)
      assert risk_scores == Enum.sort(risk_scores, :desc)

      # High risk file should be first
      assert List.first(hotspots).entity == "high_risk.ex"
    end

    test "handles binary files (represented by dashes)" do
      commits = [
        %Commit{
          id: "bin1",
          author: Author.new("Test"),
          date: ~D[2023-01-01],
          message: "Add binary",
          file_changes: [
            FileChange.new("image.png", "-", "-"),
            FileChange.new("code.ex", "10", "5")
          ]
        }
      ]

      hotspots = HotspotDetection.detect_hotspots(commits)

      assert length(hotspots) == 2
      # Both files should be detected
      entities = Enum.map(hotspots, & &1.entity)
      assert "image.png" in entities
      assert "code.ex" in entities
    end
  end

  # Helper function to create test commits
  defp create_commit(id, date, file_changes) do
    changes =
      Enum.map(file_changes, fn {path, added, deleted} ->
        FileChange.new(path, to_string(added), to_string(deleted))
      end)

    %Commit{
      id: id,
      author: Author.new("Test Author"),
      date: Date.from_iso8601!(date),
      message: "Test commit",
      file_changes: changes
    }
  end
end
