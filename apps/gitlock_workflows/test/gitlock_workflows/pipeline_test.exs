defmodule GitlockWorkflows.PipelineTest do
  use ExUnit.Case, async: true

  alias GitlockWorkflows.{Pipeline, Node, Edge}

  # Helper to find a port by name in a list of ports
  defp find_port(ports, name), do: Enum.find(ports, &(&1.name == name))

  # ─── Node Creation ──────────────────────────────────────────────

  describe "Node.new/2 from catalog type" do
    test "creates a source node with output ports" do
      node = Node.new(:git_log)

      assert node.type == :git_log
      assert node.label == "Git Log"
      assert node.input_ports == []
      assert length(node.output_ports) == 2

      commits_port = find_port(node.output_ports, "commits")
      assert commits_port.data_type == :commits

      repo_path_port = find_port(node.output_ports, "repo_path")
      assert repo_path_port.data_type == :string
    end

    test "creates an analysis node with input and output ports" do
      node = Node.new(:hotspot_detection)

      assert node.type == :hotspot_detection
      assert length(node.input_ports) == 2
      assert length(node.output_ports) == 1

      commits_input = find_port(node.input_ports, "commits")
      assert commits_input.data_type == :commits

      complexity_input = find_port(node.input_ports, "complexity_map")
      assert complexity_input.data_type == :map
      assert complexity_input.optional == true

      [output] = node.output_ports
      assert output.data_type == :hotspots
    end

    test "creates an output node with input ports only" do
      node = Node.new(:csv_report)

      assert node.type == :csv_report
      assert length(node.input_ports) == 1
      assert node.output_ports == []

      [input] = node.input_ports
      assert input.data_type == :analysis_result
    end

    test "generates unique id per node" do
      node_a = Node.new(:git_log)
      node_b = Node.new(:git_log)

      assert node_a.id != node_b.id
    end

    test "accepts position option" do
      node = Node.new(:git_log, position: {100, 200})

      assert node.position == {100, 200}
    end

    test "defaults position to origin" do
      node = Node.new(:git_log)

      assert node.position == {0, 0}
    end

    test "accepts config option" do
      node = Node.new(:git_log, config: %{depth: 500, branch: "develop"})

      assert node.config == %{depth: 500, branch: "develop"}
    end

    test "rejects unknown node type" do
      assert {:error, :unknown_node_type} = Node.new(:nonexistent_type)
    end
  end

  # ─── Edge Creation ──────────────────────────────────────────────

  describe "Edge.new/4" do
    test "creates an edge between two ports" do
      source = Node.new(:git_log)
      target = Node.new(:hotspot_detection)

      source_port = find_port(source.output_ports, "commits")
      target_port = find_port(target.input_ports, "commits")

      edge = Edge.new(source.id, source_port.id, target.id, target_port.id)

      assert edge.source_node_id == source.id
      assert edge.source_port_id == source_port.id
      assert edge.target_node_id == target.id
      assert edge.target_port_id == target_port.id
    end

    test "generates unique id" do
      edge_a = Edge.new("n1", "p1", "n2", "p2")
      edge_b = Edge.new("n1", "p1", "n2", "p2")

      assert edge_a.id != edge_b.id
    end
  end

  # ─── Pipeline Construction ──────────────────────────────────────

  describe "Pipeline.new/2" do
    test "creates empty pipeline with name" do
      pipeline = Pipeline.new("Hotspot Analysis")

      assert pipeline.name == "Hotspot Analysis"
      assert pipeline.nodes == %{}
      assert pipeline.edges == %{}
      assert is_binary(pipeline.id)
    end
  end

  describe "Pipeline.add_node/2" do
    test "adds a node to the pipeline" do
      node = Node.new(:git_log)

      pipeline =
        Pipeline.new("test")
        |> Pipeline.add_node(node)

      assert Map.has_key?(pipeline.nodes, node.id)
      assert pipeline.nodes[node.id] == node
    end

    test "rejects duplicate node id" do
      node = Node.new(:git_log)

      pipeline =
        Pipeline.new("test")
        |> Pipeline.add_node(node)

      assert {:error, :duplicate_node} = Pipeline.add_node(pipeline, node)
    end
  end

  describe "Pipeline.add_edge/2" do
    setup do
      source = Node.new(:git_log)
      target = Node.new(:hotspot_detection)

      pipeline =
        Pipeline.new("test")
        |> Pipeline.add_node(source)
        |> Pipeline.add_node(target)

      %{pipeline: pipeline, source: source, target: target}
    end

    test "connects compatible ports", %{pipeline: pipeline, source: source, target: target} do
      source_port = find_port(source.output_ports, "commits")
      target_port = find_port(target.input_ports, "commits")

      edge = Edge.new(source.id, source_port.id, target.id, target_port.id)
      pipeline = Pipeline.add_edge(pipeline, edge)

      assert Map.has_key?(pipeline.edges, edge.id)
    end

    test "rejects edge to non-existent source node", %{pipeline: pipeline, target: target} do
      target_port = find_port(target.input_ports, "commits")
      edge = Edge.new("ghost", "p1", target.id, target_port.id)

      assert {:error, :source_node_not_found} = Pipeline.add_edge(pipeline, edge)
    end

    test "rejects edge to non-existent target node", %{pipeline: pipeline, source: source} do
      source_port = find_port(source.output_ports, "commits")
      edge = Edge.new(source.id, source_port.id, "ghost", "p1")

      assert {:error, :target_node_not_found} = Pipeline.add_edge(pipeline, edge)
    end

    test "rejects edge with non-existent source port", %{
      pipeline: pipeline,
      source: source,
      target: target
    } do
      target_port = find_port(target.input_ports, "commits")
      edge = Edge.new(source.id, "bad_port", target.id, target_port.id)

      assert {:error, :source_port_not_found} = Pipeline.add_edge(pipeline, edge)
    end

    test "rejects edge with non-existent target port", %{
      pipeline: pipeline,
      source: source,
      target: target
    } do
      source_port = find_port(source.output_ports, "commits")
      edge = Edge.new(source.id, source_port.id, target.id, "bad_port")

      assert {:error, :target_port_not_found} = Pipeline.add_edge(pipeline, edge)
    end

    test "rejects edge between incompatible port types" do
      # hotspot output is :hotspots, coupling input expects :commits
      hotspot_node = Node.new(:hotspot_detection)
      coupling_node = Node.new(:coupling_detection)

      pipeline =
        Pipeline.new("test")
        |> Pipeline.add_node(hotspot_node)
        |> Pipeline.add_node(coupling_node)

      [source_port] = hotspot_node.output_ports
      target_port = find_port(coupling_node.input_ports, "commits")

      edge = Edge.new(hotspot_node.id, source_port.id, coupling_node.id, target_port.id)

      assert {:error, :incompatible_port_types} = Pipeline.add_edge(pipeline, edge)
    end
  end

  describe "Pipeline.remove_node/2" do
    test "removes node and its connected edges" do
      source = Node.new(:git_log)
      middle = Node.new(:hotspot_detection)
      output = Node.new(:csv_report)

      src_port = find_port(source.output_ports, "commits")
      mid_in = find_port(middle.input_ports, "commits")
      [mid_out] = middle.output_ports
      [out_port] = output.input_ports

      edge1 = Edge.new(source.id, src_port.id, middle.id, mid_in.id)
      edge2 = Edge.new(middle.id, mid_out.id, output.id, out_port.id)

      pipeline =
        Pipeline.new("test")
        |> Pipeline.add_node(source)
        |> Pipeline.add_node(middle)
        |> Pipeline.add_node(output)
        |> Pipeline.add_edge(edge1)
        |> Pipeline.add_edge(edge2)

      # Sanity: 3 nodes, 2 edges
      assert map_size(pipeline.nodes) == 3
      assert map_size(pipeline.edges) == 2

      # Remove middle node — both edges should go
      pipeline = Pipeline.remove_node(pipeline, middle.id)

      assert map_size(pipeline.nodes) == 2
      assert map_size(pipeline.edges) == 0
      refute Map.has_key?(pipeline.nodes, middle.id)
    end

    test "returns unchanged pipeline for non-existent node" do
      pipeline = Pipeline.new("test")

      assert pipeline == Pipeline.remove_node(pipeline, "ghost")
    end
  end

  describe "Pipeline.remove_edge/2" do
    test "removes an edge by id" do
      source = Node.new(:git_log)
      target = Node.new(:hotspot_detection)
      src_port = find_port(source.output_ports, "commits")
      tgt_port = find_port(target.input_ports, "commits")
      edge = Edge.new(source.id, src_port.id, target.id, tgt_port.id)

      pipeline =
        Pipeline.new("test")
        |> Pipeline.add_node(source)
        |> Pipeline.add_node(target)
        |> Pipeline.add_edge(edge)

      pipeline = Pipeline.remove_edge(pipeline, edge.id)

      assert map_size(pipeline.edges) == 0
    end
  end

  # ─── Pipeline Validation ────────────────────────────────────────

  describe "Pipeline.validate/1" do
    test "valid three-node pipeline" do
      source = Node.new(:git_log)
      analysis = Node.new(:hotspot_detection)
      output = Node.new(:csv_report)

      src_port = find_port(source.output_ports, "commits")
      ana_in = find_port(analysis.input_ports, "commits")
      [ana_out] = analysis.output_ports
      [out_port] = output.input_ports

      pipeline =
        Pipeline.new("Full Pipeline")
        |> Pipeline.add_node(source)
        |> Pipeline.add_node(analysis)
        |> Pipeline.add_node(output)
        |> Pipeline.add_edge(Edge.new(source.id, src_port.id, analysis.id, ana_in.id))
        |> Pipeline.add_edge(Edge.new(analysis.id, ana_out.id, output.id, out_port.id))

      assert :ok = Pipeline.validate(pipeline)
    end

    test "detects unconnected required input ports" do
      # Analysis node with no source feeding it
      analysis = Node.new(:hotspot_detection)

      pipeline =
        Pipeline.new("test")
        |> Pipeline.add_node(analysis)

      assert {:error, errors} = Pipeline.validate(pipeline)
      assert :unconnected_inputs in Keyword.keys(errors)
    end

    test "empty pipeline is valid" do
      pipeline = Pipeline.new("empty")

      assert :ok = Pipeline.validate(pipeline)
    end

    test "source-only pipeline is valid (no required inputs)" do
      source = Node.new(:git_log)

      pipeline =
        Pipeline.new("test")
        |> Pipeline.add_node(source)

      assert :ok = Pipeline.validate(pipeline)
    end
  end

  # ─── Full Scenario ─────────────────────────────────────────────

  describe "realistic pipeline construction" do
    test "builds GitLog → HotspotDetection → CSVReport" do
      git_log = Node.new(:git_log, config: %{depth: 1000}, position: {0, 100})
      hotspots = Node.new(:hotspot_detection, position: {300, 100})
      report = Node.new(:csv_report, position: {600, 100})

      git_out = find_port(git_log.output_ports, "commits")
      hs_in = find_port(hotspots.input_ports, "commits")
      [hs_out] = hotspots.output_ports
      [rpt_in] = report.input_ports

      pipeline =
        Pipeline.new("Hotspot Analysis")
        |> Pipeline.add_node(git_log)
        |> Pipeline.add_node(hotspots)
        |> Pipeline.add_node(report)
        |> Pipeline.add_edge(Edge.new(git_log.id, git_out.id, hotspots.id, hs_in.id))
        |> Pipeline.add_edge(Edge.new(hotspots.id, hs_out.id, report.id, rpt_in.id))

      assert :ok = Pipeline.validate(pipeline)
      assert map_size(pipeline.nodes) == 3
      assert map_size(pipeline.edges) == 2
    end
  end
end
