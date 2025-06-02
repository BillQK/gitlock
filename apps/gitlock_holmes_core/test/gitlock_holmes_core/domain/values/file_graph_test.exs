defmodule GitlockHolmesCore.Domain.Values.FileGraphTest do
  use ExUnit.Case, async: true

  alias GitlockHolmesCore.Domain.Values.FileGraph

  describe "new/3" do
    test "creates a new graph with the provided nodes, edges, and metadata" do
      nodes = %{
        "file_a.ex" => %{
          complexity: 10,
          loc: 100,
          component: "core",
          revisions: 5,
          authors: ["Alice"]
        },
        "file_b.ex" => %{
          complexity: 5,
          loc: 50,
          component: "utils",
          revisions: 3,
          authors: ["Bob"]
        }
      }

      edges = [
        {"file_a.ex", "file_b.ex", 0.7}
      ]

      metadata = %{total_files: 2, generated_at: ~U[2023-01-01 12:00:00Z]}

      graph = FileGraph.new(nodes, edges, metadata)

      assert graph.nodes == nodes
      assert graph.edges == edges
      assert graph.metadata == metadata
    end

    test "creates empty graph when no data provided" do
      graph = FileGraph.new(%{}, [], %{})
      assert map_size(graph.nodes) == 0
      assert length(graph.edges) == 0
      assert map_size(graph.metadata) == 0
    end
  end

  describe "components/1" do
    test "returns unique component names" do
      nodes = %{
        "file_a.ex" => %{component: "core"},
        "file_b.ex" => %{component: "utils"},
        "file_c.ex" => %{component: "core"},
        "file_d.ex" => %{component: "data"}
      }

      graph = %FileGraph{nodes: nodes, edges: [], metadata: %{}}

      components = FileGraph.components(graph)
      assert length(components) == 3
      assert "core" in components
      assert "utils" in components
      assert "data" in components
    end

    test "handles missing component values" do
      nodes = %{
        "file_a.ex" => %{component: "core"},
        # No component key
        "file_b.ex" => %{},
        # Nil component
        "file_c.ex" => %{component: nil}
      }

      graph = %FileGraph{nodes: nodes, edges: [], metadata: %{}}

      components = FileGraph.components(graph)
      assert length(components) == 1
      assert "core" in components
    end

    test "returns empty list for empty graph" do
      graph = %FileGraph{nodes: %{}, edges: [], metadata: %{}}
      assert FileGraph.components(graph) == []
    end
  end

  describe "file_metrics/2" do
    test "returns metrics for a file" do
      nodes = %{
        "file_a.ex" => %{
          complexity: 10,
          loc: 100,
          revisions: 5
        }
      }

      graph = %FileGraph{nodes: nodes, edges: [], metadata: %{}}

      metrics = FileGraph.file_metrics(graph, "file_a.ex")
      assert metrics.complexity == 10
      assert metrics.loc == 100
      assert metrics.revisions == 5
    end

    test "returns default values for missing files" do
      graph = %FileGraph{nodes: %{}, edges: [], metadata: %{}}

      metrics = FileGraph.file_metrics(graph, "non_existent.ex")
      assert metrics.complexity == 0
      assert metrics.loc == 0
      assert metrics.revisions == 0
    end

    test "handles missing metrics within file data" do
      # Test when file exists but some metrics are missing
      nodes = %{
        # Missing loc and revisions
        "incomplete.ex" => %{complexity: 5}
      }

      graph = %FileGraph{nodes: nodes, edges: [], metadata: %{}}

      metrics = FileGraph.file_metrics(graph, "incomplete.ex")
      assert metrics.complexity == 5
      # Should default these missing values
      assert metrics.loc == 0
      assert metrics.revisions == 0
    end
  end

  describe "files_in_component/2" do
    test "returns files in the specified component" do
      nodes = %{
        "lib/core/a.ex" => %{component: "core"},
        "lib/core/b.ex" => %{component: "core"},
        "lib/utils/c.ex" => %{component: "utils"}
      }

      graph = %FileGraph{nodes: nodes, edges: [], metadata: %{}}

      core_files = FileGraph.files_in_component(graph, "core")
      assert length(core_files) == 2
      assert "lib/core/a.ex" in core_files
      assert "lib/core/b.ex" in core_files

      utils_files = FileGraph.files_in_component(graph, "utils")
      assert length(utils_files) == 1
      assert "lib/utils/c.ex" in utils_files
    end

    test "returns empty list for non-existent component" do
      nodes = %{
        "file_a.ex" => %{component: "core"}
      }

      graph = %FileGraph{nodes: nodes, edges: [], metadata: %{}}

      missing_files = FileGraph.files_in_component(graph, "missing")
      assert Enum.empty?(missing_files)
    end

    test "handles empty graph" do
      graph = %FileGraph{nodes: %{}, edges: [], metadata: %{}}
      assert FileGraph.files_in_component(graph, "any") == []
    end
  end

  describe "coupling_strength/3" do
    test "retrieves coupling strength between two files" do
      # Using a map for edges to simulate the get/2 behavior
      edges = %{
        {"file_a.ex", "file_b.ex"} => %{coupling_strength: 0.75}
      }

      graph = %FileGraph{nodes: %{}, edges: edges, metadata: %{}}

      # Test with files in order
      assert FileGraph.coupling_strength(graph, "file_a.ex", "file_b.ex") == 0.75

      # Test with files in reverse order
      assert FileGraph.coupling_strength(graph, "file_b.ex", "file_a.ex") == 0.75
    end

    test "returns zero when no coupling exists" do
      edges = %{}
      graph = %FileGraph{nodes: %{}, edges: edges, metadata: %{}}

      assert FileGraph.coupling_strength(graph, "file_a.ex", "file_b.ex") == 0.0
    end
  end

  describe "coupled_files/4" do
    test "returns files coupled to the target file above threshold" do
      edges = %{
        {"file_a.ex", "file_b.ex"} => %{coupling_strength: 0.8},
        {"file_a.ex", "file_c.ex"} => %{coupling_strength: 0.5},
        {"file_a.ex", "file_d.ex"} => %{coupling_strength: 0.3}
      }

      graph = %FileGraph{nodes: %{}, edges: edges, metadata: %{}}

      # Get files coupled to file_a.ex with strength >= 0.5
      coupled = FileGraph.coupled_files(graph, "file_a.ex", 0.5, 10)

      assert length(coupled) == 2

      # Should be sorted by strength (descending)
      assert Enum.at(coupled, 0) == {"file_b.ex", 0.8}
      assert Enum.at(coupled, 1) == {"file_c.ex", 0.5}
    end

    test "respects limit parameter" do
      edges = %{
        {"file_a.ex", "file_b.ex"} => %{coupling_strength: 0.8},
        {"file_a.ex", "file_c.ex"} => %{coupling_strength: 0.7},
        {"file_a.ex", "file_d.ex"} => %{coupling_strength: 0.6}
      }

      graph = %FileGraph{nodes: %{}, edges: edges, metadata: %{}}

      # Limit to 2 results
      coupled = FileGraph.coupled_files(graph, "file_a.ex", 0.0, 2)

      assert length(coupled) == 2
      # Should take top 2 by strength
      assert Enum.at(coupled, 0) == {"file_b.ex", 0.8}
      assert Enum.at(coupled, 1) == {"file_c.ex", 0.7}
    end

    test "returns empty list when no couplings above threshold" do
      edges = %{
        {"file_a.ex", "file_b.ex"} => %{coupling_strength: 0.3}
      }

      graph = %FileGraph{nodes: %{}, edges: edges, metadata: %{}}

      coupled = FileGraph.coupled_files(graph, "file_a.ex", 0.5, 10)
      assert coupled == []
    end
  end

  describe "validation functions" do
    test "validate_graph/1 validates graph structure" do
      valid_graph = %FileGraph{nodes: %{}, edges: [], metadata: %{}}
      assert :ok = FileGraph.validate_graph(valid_graph)

      assert {:error, _} = FileGraph.validate_graph("not a graph")
      assert {:error, _} = FileGraph.validate_graph(%{some: "map"})
      assert {:error, _} = FileGraph.validate_graph(nil)
    end

    test "validate_file_exists_in_graph/2 checks file existence" do
      nodes = %{"file_a.ex" => %{}}
      graph = %FileGraph{nodes: nodes, edges: [], metadata: %{}}

      assert :ok = FileGraph.validate_file_exists_in_graph("file_a.ex", graph)

      # Test with various non-existent files
      assert {:error, _} = FileGraph.validate_file_exists_in_graph("missing.ex", graph)
      assert {:error, _} = FileGraph.validate_file_exists_in_graph("", graph)
      assert {:error, _} = FileGraph.validate_file_exists_in_graph(nil, graph)
    end
  end
end
