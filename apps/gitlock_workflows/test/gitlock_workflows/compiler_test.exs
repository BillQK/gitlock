defmodule GitlockWorkflows.CompilerTest do
  use ExUnit.Case, async: true

  alias GitlockWorkflows.{Compiler, Pipeline, Node, Edge, Templates}
  alias GitlockWorkflows.Runtime.Workflow

  describe "to_workflow/1" do
    test "converts hotspot_scan template to workflow" do
      pipeline = Templates.build(:hotspot_scan)
      {:ok, workflow} = Compiler.to_workflow(pipeline)

      assert %Workflow{} = workflow
      assert workflow.name == "Hotspot Quick Scan"
      assert workflow.id == pipeline.id

      # git_log + hotspot_detection + summary = 3 nodes, all have runtime types
      assert length(workflow.nodes) == 3

      types = Enum.map(workflow.nodes, & &1.type)
      assert "gitlock.trigger.git_commits" in types
      assert "gitlock.analysis.hotspot" in types
      assert "gitlock.analysis.summary" in types
    end

    test "converts full_analysis template" do
      pipeline = Templates.build(:full_analysis)
      {:ok, workflow} = Compiler.to_workflow(pipeline)

      # git_log + 5 analyzers + summary = 7 (blast_radius has no runtime impl)
      assert length(workflow.nodes) == 7

      types = MapSet.new(workflow.nodes, & &1.type)
      assert MapSet.member?(types, "gitlock.trigger.git_commits")
      assert MapSet.member?(types, "gitlock.analysis.hotspot")
      assert MapSet.member?(types, "gitlock.analysis.coupling")
      assert MapSet.member?(types, "gitlock.analysis.knowledge_silo")
      assert MapSet.member?(types, "gitlock.analysis.code_age")
      assert MapSet.member?(types, "gitlock.analysis.coupled_hotspot")
      assert MapSet.member?(types, "gitlock.analysis.summary")
    end

    test "converts edges to connections with port names" do
      pipeline = Templates.build(:hotspot_scan)
      {:ok, workflow} = Compiler.to_workflow(pipeline)

      # hotspot_scan has: git_log→hotspot, git_log→summary
      assert length(workflow.connections) == 2

      # Verify connections use port names, not port IDs
      for conn <- workflow.connections do
        assert is_binary(conn.from.port)
        assert is_binary(conn.to.port)
        # Port names should be readable, not hex IDs
        refute String.match?(conn.from.port, ~r/^[0-9a-f]{16}$/)
      end
    end

    test "connections reference correct port names" do
      pipeline = Templates.build(:hotspot_scan)
      {:ok, workflow} = Compiler.to_workflow(pipeline)

      # git_log outputs "commits" → hotspot takes "commits"
      git_node = Enum.find(workflow.nodes, &(&1.type == "gitlock.trigger.git_commits"))
      hotspot_node = Enum.find(workflow.nodes, &(&1.type == "gitlock.analysis.hotspot"))

      git_to_hotspot =
        Enum.find(workflow.connections, fn conn ->
          conn.from.node == git_node.id and conn.to.node == hotspot_node.id
        end)

      assert git_to_hotspot != nil
      assert git_to_hotspot.from.port == "commits"
      assert git_to_hotspot.to.port == "commits"
    end

    test "preserves node IDs across compilation" do
      pipeline = Templates.build(:hotspot_scan)
      {:ok, workflow} = Compiler.to_workflow(pipeline)

      pipeline_node_ids = pipeline.nodes |> Map.keys() |> MapSet.new()
      workflow_node_ids = MapSet.new(workflow.nodes, & &1.id)

      # All workflow node IDs should be from the original pipeline
      assert MapSet.subset?(workflow_node_ids, pipeline_node_ids)
    end

    test "skips output nodes without runtime implementations" do
      # Build a pipeline with a csv_report output node
      git = Node.new(:git_log)
      hotspots = Node.new(:hotspot_detection)
      csv = Node.new(:csv_report)

      [git_out] = git.output_ports
      [hs_in] = hotspots.input_ports
      [hs_out] = hotspots.output_ports
      [csv_in] = csv.input_ports

      pipeline =
        Pipeline.new("With Output")
        |> Pipeline.add_node(git)
        |> Pipeline.add_node(hotspots)
        |> Pipeline.add_node(csv)
        |> Pipeline.add_edge(Edge.new(git.id, git_out.id, hotspots.id, hs_in.id))
        |> Pipeline.add_edge(Edge.new(hotspots.id, hs_out.id, csv.id, csv_in.id))

      {:ok, workflow} = Compiler.to_workflow(pipeline)

      # csv_report should be skipped
      types = Enum.map(workflow.nodes, & &1.type)
      refute "csv_report" in types
      assert length(workflow.nodes) == 2

      # Edge to csv_report should also be skipped
      assert length(workflow.connections) == 1
    end

    test "empty pipeline compiles to empty workflow" do
      pipeline = Pipeline.new("Empty")
      {:ok, workflow} = Compiler.to_workflow(pipeline)

      assert workflow.nodes == []
      assert workflow.connections == []
    end
  end

  describe "compile/1" do
    test "produces reactor-ready workflow from template" do
      pipeline = Templates.build(:hotspot_scan)
      {:ok, workflow} = Compiler.compile(pipeline)

      assert Workflow.reactor_ready?(workflow)
    end

    test "injects repo_path into trigger node parameters" do
      pipeline = Templates.build(:hotspot_scan)
      {:ok, workflow} = Compiler.to_workflow(pipeline, repo_path: "/tmp/test-repo")

      trigger = Enum.find(workflow.nodes, &(&1.type == "gitlock.trigger.git_commits"))
      assert trigger.parameters["repo_path"] == "/tmp/test-repo"
    end

    test "falls back to repo_url from config when no repo_path option" do
      git = Node.new(:git_log, config: %{"repo_url" => "https://github.com/test/repo"})
      hs = Node.new(:hotspot_detection)
      [git_out] = git.output_ports
      [hs_in] = hs.input_ports

      pipeline =
        Pipeline.new("Test")
        |> Pipeline.add_node(git)
        |> Pipeline.add_node(hs)
        |> Pipeline.add_edge(Edge.new(git.id, git_out.id, hs.id, hs_in.id))

      {:ok, workflow} = Compiler.to_workflow(pipeline)
      trigger = Enum.find(workflow.nodes, &(&1.type == "gitlock.trigger.git_commits"))
      assert trigger.parameters["repo_path"] == "https://github.com/test/repo"
    end

    test "empty pipeline fails reactor compilation" do
      pipeline = Pipeline.new("Empty")
      assert {:error, :empty_workflow} = Compiler.compile(pipeline)
    end
  end

  describe "runtime_type/1" do
    test "delegates to NodeCatalog.runtime_type" do
      assert "gitlock.trigger.git_commits" = Compiler.runtime_type(:git_log)
      assert "gitlock.analysis.hotspot" = Compiler.runtime_type(:hotspot_detection)
      assert "gitlock.analysis.summary" = Compiler.runtime_type(:summary)
    end

    test "returns nil for nodes without runtime modules" do
      assert nil == Compiler.runtime_type(:csv_report)
      assert nil == Compiler.runtime_type(:blast_radius_analysis)
      assert nil == Compiler.runtime_type(:nonexistent)
    end
  end
end
