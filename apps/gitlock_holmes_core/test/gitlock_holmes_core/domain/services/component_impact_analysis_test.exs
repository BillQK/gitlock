defmodule GitlockHolmesCore.Domain.Services.ComponentImpactAnalysisTest do
  use ExUnit.Case, async: true

  alias GitlockHolmesCore.Domain.Services.ComponentImpactAnalysis
  alias GitlockHolmesCore.Domain.Values.FileGraph

  describe "calculate_cross_component_impact/2" do
    test "correctly sums impact by component" do
      # Create a simple graph with component information
      nodes = %{
        "lib/auth/session.ex" => %{component: "auth"},
        "lib/auth/token.ex" => %{component: "auth"},
        "lib/user/profile.ex" => %{component: "user"}
      }

      graph = %FileGraph{nodes: nodes, edges: [], metadata: %{}}

      # Define a blast radius with impacts
      blast_radius = [
        # Direct impact
        {"lib/auth/session.ex", 1.0, 0},
        # Related in same component
        {"lib/auth/token.ex", 0.7, 1},
        # Related in different component
        {"lib/user/profile.ex", 0.4, 2}
      ]

      # Calculate impact
      impact = ComponentImpactAnalysis.calculate_cross_component_impact(graph, blast_radius)

      # Verify correct component impacts
      # Two components
      assert map_size(impact) == 2
      # 1.0 + 0.7
      assert_in_delta impact["auth"], 1.7, 0.01
      assert_in_delta impact["user"], 0.4, 0.01
    end

    test "handles missing component information" do
      # Some nodes have missing component info
      nodes = %{
        "lib/auth/session.ex" => %{component: "auth"},
        # No component
        "lib/utils/helper.ex" => %{},
        # Nil component
        "lib/user/profile.ex" => %{component: nil}
      }

      graph = %FileGraph{nodes: nodes, edges: [], metadata: %{}}

      blast_radius = [
        {"lib/auth/session.ex", 1.0, 0},
        {"lib/utils/helper.ex", 0.6, 1},
        {"lib/user/profile.ex", 0.4, 2}
      ]

      impact = ComponentImpactAnalysis.calculate_cross_component_impact(graph, blast_radius)

      # Should only include the "auth" component
      assert map_size(impact) == 2
      assert impact["auth"] == 1.0
    end
  end

  describe "find_connector_files/2" do
    test "identifies files that bridge components" do
      nodes = %{
        "lib/auth/session.ex" => %{component: "auth"},
        "lib/auth/token.ex" => %{component: "auth"},
        "lib/user/profile.ex" => %{component: "user"},
        "lib/bridge.ex" => %{component: "core"}
      }

      edges = [
        # Same component
        {"lib/auth/session.ex", "lib/auth/token.ex", 0.8},
        # Different components
        {"lib/auth/session.ex", "lib/bridge.ex", 0.7},
        # Different components
        {"lib/bridge.ex", "lib/user/profile.ex", 0.6}
      ]

      graph = %FileGraph{nodes: nodes, edges: edges, metadata: %{}}

      # Find connector files with threshold 0.5
      connectors = ComponentImpactAnalysis.find_connector_files(graph, 0.5)

      # Should find lib/bridge.ex as a connector
      assert length(connectors) >= 1

      # At least one connector should be lib/bridge.ex
      bridge_connector =
        Enum.find(connectors, fn {file, _, _} ->
          file == "lib/bridge.ex"
        end)

      assert bridge_connector != nil

      # Extract components and strength
      {_, components, strength} = bridge_connector

      # Bridge should connect at least auth and core components
      assert "auth" in components
      assert "core" in components or "user" in components

      # Strength should be reasonable
      assert strength > 0.5
    end
  end
end
