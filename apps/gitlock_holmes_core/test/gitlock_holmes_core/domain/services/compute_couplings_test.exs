defmodule GitlockHolmesCore.Domain.Services.ComputeCouplingsTest do
  use ExUnit.Case, async: true

  alias GitlockHolmesCore.Domain.Services.ComputeCouplings
  alias GitlockHolmesCore.Domain.Values.{FileGraph}

  describe "calculate_coupling_strength/6" do
    test "calculates correct coupling degree" do
      # Test data - files changed together
      all_cochanges = %{{"file_a.ex", "file_b.ex"} => 3}
      early_cochanges = %{{"file_a.ex", "file_b.ex"} => 1}
      recent_cochanges = %{{"file_a.ex", "file_b.ex"} => 2}

      # File counts - file_a changed 4 times, file_b 3 times
      file_counts = %{"file_a.ex" => 4, "file_b.ex" => 3}

      # Calculate coupling
      couplings =
        ComputeCouplings.calculate_coupling_strength(
          all_cochanges,
          early_cochanges,
          recent_cochanges,
          file_counts,
          # min_coupling
          1.0,
          # min_windows
          1
        )

      assert length(couplings) == 1
      coupling = hd(couplings)

      # Verify coupling metrics
      # Coupling = (shared_commits / avg_revisions) * 100
      # Shared = 3, avg = (4 + 3) / 2 = 3.5
      # So degree = 3 / 3.5 * 100 = 85.7%
      assert_in_delta coupling.degree, 85.7, 0.1
      assert coupling.windows == 3

      # Trend = recent_degree - early_degree
      # recent_degree = 2 / 1.75 * 100 = 114.3
      # early_degree = 1 / 1.75 * 100 = 57.1
      # trend = 114.3 - 57.1 = 57.2
      # Trend should be positive (increasing)
      assert coupling.trend > 0
    end

    test "filters by minimum windows and coupling" do
      # Setup data with weak coupling
      all_cochanges = %{{"file_a.ex", "file_b.ex"} => 1}
      early_cochanges = %{}
      recent_cochanges = %{{"file_a.ex", "file_b.ex"} => 1}
      file_counts = %{"file_a.ex" => 10, "file_b.ex" => 10}

      # With high minimum coupling (50%), should filter out
      high_min =
        ComputeCouplings.calculate_coupling_strength(
          all_cochanges,
          early_cochanges,
          recent_cochanges,
          file_counts,
          # min_coupling
          50.0,
          # min_windows
          1
        )

      assert Enum.empty?(high_min)

      # With low minimum coupling (5%), should include
      low_min =
        ComputeCouplings.calculate_coupling_strength(
          all_cochanges,
          early_cochanges,
          recent_cochanges,
          file_counts,
          # min_coupling
          5.0,
          # min_windows
          1
        )

      assert length(low_min) == 1
    end
  end

  describe "blast_radius/4" do
    test "calculates blast radius with correct impact values" do
      # Create a simple graph with 3 files
      nodes = %{
        "lib/a.ex" => %{
          complexity: 10,
          loc: 100,
          revisions: 5,
          component: "core",
          authors: ["Alice"]
        },
        "lib/b.ex" => %{complexity: 5, loc: 50, revisions: 3, component: "core", authors: ["Bob"]},
        "lib/c.ex" => %{
          complexity: 8,
          loc: 80,
          revisions: 4,
          component: "utils",
          authors: ["Carol"]
        }
      }

      edges = [
        # Strong coupling between A and B
        {"lib/a.ex", "lib/b.ex", 0.7},
        # Medium coupling between B and C
        {"lib/b.ex", "lib/c.ex", 0.4}
      ]

      graph = FileGraph.new(nodes, edges, %{})

      # Calculate blast radius for file A
      blast = ComputeCouplings.blast_radius(graph, "lib/a.ex", 0.3, 2)

      # Should find all three files with decreasing impact
      assert length(blast) == 3

      # Check the specific files and their order
      # Target file with full impact
      assert Enum.at(blast, 0) == {"lib/a.ex", 1.0, 0}
      # Directly coupled
      assert Enum.at(blast, 1) == {"lib/b.ex", 0.7, 1}

      # C is indirectly coupled through B, with impact A->B->C
      {file_c, impact_c, distance_c} = Enum.at(blast, 2)
      assert file_c == "lib/c.ex"
      assert distance_c == 2
      # Impact should be reduced by distance
      assert impact_c < 0.5
    end

    test "respects threshold parameter" do
      # Create a graph with files of varying coupling strengths
      nodes = %{
        "file_a.ex" => %{complexity: 5, loc: 100, revisions: 5, component: "core"},
        "file_b.ex" => %{complexity: 5, loc: 100, revisions: 5, component: "core"},
        "file_c.ex" => %{complexity: 5, loc: 100, revisions: 5, component: "core"},
        "file_d.ex" => %{complexity: 5, loc: 100, revisions: 5, component: "core"}
      }

      edges = [
        # Strong coupling
        {"file_a.ex", "file_b.ex", 0.8},
        # Medium coupling
        {"file_a.ex", "file_c.ex", 0.4},
        # Weak coupling
        {"file_a.ex", "file_d.ex", 0.2}
      ]

      graph = FileGraph.new(nodes, edges, %{})

      # With high threshold, only include strong couplings
      high_threshold = ComputeCouplings.blast_radius(graph, "file_a.ex", 0.7, 2)
      # file_a and file_b only
      assert length(high_threshold) == 2

      # With medium threshold, include more files
      medium_threshold = ComputeCouplings.blast_radius(graph, "file_a.ex", 0.3, 2)
      # file_a, file_b, file_c
      assert length(medium_threshold) == 3

      # With low threshold, include all files
      low_threshold = ComputeCouplings.blast_radius(graph, "file_a.ex", 0.1, 2)
      # All files
      assert length(low_threshold) == 4
    end
  end
end
