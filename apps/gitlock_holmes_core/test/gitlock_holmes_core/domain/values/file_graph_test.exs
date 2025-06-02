defmodule GitlockHolmesCore.Domain.Values.FileGraphTest do
  use ExUnit.Case, async: true

  alias GitlockHolmesCore.Domain.Values.FileGraph

  describe "new/3" do
    test "creates a new graph with the provided nodes, edges, and metadata" do
      # Fix: Use proper node structure
      nodes = %{
        "file_a.ex" => %{complexity: 10, loc: 100, component: "core"},
        "file_b.ex" => %{complexity: 5, loc: 50, component: "utils"}
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
  end

  describe "components/1" do
    test "returns unique component names" do
      # Fix: Ensure components are accessed correctly
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
      # Fix: Handle missing component keys properly
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
  end

  describe "validation functions" do
    test "validate_graph/1 validates graph structure" do
      valid_graph = %FileGraph{nodes: %{}, edges: [], metadata: %{}}
      assert :ok = FileGraph.validate_graph(valid_graph)

      assert {:error, _} = FileGraph.validate_graph("not a graph")
    end

    test "validate_file_exists_in_graph/2 checks file existence" do
      nodes = %{"file_a.ex" => %{}}
      graph = %FileGraph{nodes: nodes, edges: [], metadata: %{}}

      assert :ok = FileGraph.validate_file_exists_in_graph("file_a.ex", graph)
      assert {:error, _} = FileGraph.validate_file_exists_in_graph("missing.ex", graph)
    end
  end
end
