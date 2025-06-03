defmodule GitlockCore.Domain.Services.CoupledHotspotAnalysisTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Domain.Services.CoupledHotspotAnalysis
  alias GitlockCore.Domain.Entities.{Commit, Author}
  alias GitlockCore.Domain.Values.{FileChange, ComplexityMetrics, CombinedRisk}

  describe "detect_combined/2" do
    test "identifies coupled files that are also hotspots" do
      # Use one author to create a consistent history
      author = Author.new("Test Author")

      # Create MANY commits with the two files changing together
      # We need at least 15-20 co-changes to ensure detection with different windows
      cochange_commits =
        Enum.map(1..20, fn i ->
          Commit.new(
            "cochange_#{i}",
            author,
            "2023-01-#{String.pad_leading("#{i}", 2, "0")}",
            "Both files changed",
            [
              FileChange.new("hotspot1.ex", "10", "5"),
              FileChange.new("hotspot2.ex", "15", "8")
            ]
          )
        end)

      # Add very few individual changes (helps coupling strength)
      # Just 2-3 individual changes for each file
      individual_commits =
        Enum.map(1..3, fn i ->
          Commit.new(
            "hs1_#{i}",
            author,
            "2023-02-0#{i}",
            "Hotspot1 only",
            [FileChange.new("hotspot1.ex", "8", "4")]
          )
        end) ++
          Enum.map(1..3, fn i ->
            Commit.new(
              "hs2_#{i}",
              author,
              "2023-03-0#{i}",
              "Hotspot2 only",
              [FileChange.new("hotspot2.ex", "9", "3")]
            )
          end)

      # Add unrelated commits to pad the timeline for better splitting
      padding_commits =
        Enum.map(1..10, fn i ->
          Commit.new(
            "other_#{i}",
            author,
            "2023-04-#{String.pad_leading("#{i}", 2, "0")}",
            "Other file",
            [FileChange.new("other.ex", "5", "2")]
          )
        end)

      all_commits = cochange_commits ++ individual_commits ++ padding_commits

      # Use extremely high complexity values 
      complexity_metrics = %{
        "hotspot1.ex" => ComplexityMetrics.new("hotspot1.ex", 500, 50, :elixir),
        "hotspot2.ex" => ComplexityMetrics.new("hotspot2.ex", 480, 48, :elixir)
      }

      result = CoupledHotspotAnalysis.detect_combined(all_commits, complexity_metrics)

      # Debugging output if test fails
      if Enum.empty?(result) do
        IO.puts("\nDEBUG: No coupled hotspots detected")

        hotspots =
          GitlockCore.Domain.Services.HotspotDetection.detect_hotspots(
            all_commits,
            complexity_metrics
          )

        couplings =
          GitlockCore.Domain.Services.CouplingDetection.detect_couplings(
            all_commits,
            # min_coupling 
            1.0,
            # min_windows
            5
          )

        IO.puts("Detected #{length(hotspots)} hotspots:")

        Enum.each(hotspots, fn h ->
          IO.puts("  #{h.entity} (risk: #{h.risk_score}, revs: #{h.revisions})")
        end)

        IO.puts("Detected #{length(couplings)} couplings:")

        Enum.each(couplings, fn c ->
          IO.puts("  #{c.entity} <-> #{c.coupled} (degree: #{c.degree}, windows: #{c.windows})")
        end)
      end

      # Should find coupled hotspots
      assert length(result) > 0

      # Verify the result
      first_result = hd(result)
      assert %CombinedRisk{} = first_result
      assert first_result.entity in ["hotspot1.ex", "hotspot2.ex"]
      assert first_result.coupled in ["hotspot1.ex", "hotspot2.ex"]
      assert first_result.entity != first_result.coupled

      # Should have substantial risk score
      assert first_result.combined_risk_score > 0

      # Should have individual risks for both files
      assert map_size(first_result.individual_risks) == 2
      assert first_result.individual_risks["hotspot1.ex"] > 0
      assert first_result.individual_risks["hotspot2.ex"] > 0
    end

    test "handles empty commits list" do
      result = CoupledHotspotAnalysis.detect_combined([])
      assert result == []
    end

    test "handles case with no coupled hotspots" do
      # Create commits without coupling
      commits = [
        create_commit("c1", ["file1.ex"]),
        create_commit("c2", ["file2.ex"]),
        create_commit("c3", ["file3.ex"])
      ]

      result = CoupledHotspotAnalysis.detect_combined(commits)
      assert result == []
    end
  end

  # Helper to create test commits
  defp create_commit(id, file_paths) do
    file_changes = Enum.map(file_paths, &FileChange.new(&1, 10, 5))

    %Commit{
      id: id,
      author: Author.new("Test Author"),
      date: ~D[2023-01-01],
      message: "Test commit",
      file_changes: file_changes
    }
  end
end

