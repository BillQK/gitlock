defmodule GitlockWorkflows.NodeCatalogTest do
  use ExUnit.Case, async: true

  alias GitlockWorkflows.NodeCatalog

  describe "list_types/0" do
    test "returns all available node types" do
      types = NodeCatalog.list_types()

      assert is_list(types)
      assert length(types) > 0

      type_ids = Enum.map(types, & &1.type_id)
      assert :git_log in type_ids
      assert :hotspot_detection in type_ids
      assert :csv_report in type_ids
    end

    test "every type has a runtime_module field" do
      for type_def <- NodeCatalog.list_types() do
        assert Map.has_key?(type_def, :runtime_module),
               "Type #{type_def.type_id} missing runtime_module field"
      end
    end
  end

  describe "get_type/1" do
    test "returns type definition for known type" do
      {:ok, type_def} = NodeCatalog.get_type(:git_log)

      assert type_def.type_id == :git_log
      assert type_def.category == :source
      assert type_def.label == "Git Log"
      assert type_def.input_ports == []
      assert length(type_def.output_ports) == 1
    end

    test "returns error for unknown type" do
      assert {:error, :unknown_node_type} = NodeCatalog.get_type(:does_not_exist)
    end
  end

  describe "runtime_module/1" do
    test "returns module for nodes with runtime implementations" do
      assert GitlockWorkflows.Runtime.Nodes.Triggers.GitCommits = NodeCatalog.runtime_module(:git_log)
      assert GitlockWorkflows.Runtime.Nodes.Analysis.Hotspot = NodeCatalog.runtime_module(:hotspot_detection)
      assert GitlockWorkflows.Runtime.Nodes.Analysis.Coupling = NodeCatalog.runtime_module(:coupling_detection)
      assert GitlockWorkflows.Runtime.Nodes.Analysis.KnowledgeSilo = NodeCatalog.runtime_module(:knowledge_silo_detection)
      assert GitlockWorkflows.Runtime.Nodes.Analysis.CodeAge = NodeCatalog.runtime_module(:code_age_analysis)
      assert GitlockWorkflows.Runtime.Nodes.Analysis.CoupledHotspot = NodeCatalog.runtime_module(:coupled_hotspot_analysis)
      assert GitlockWorkflows.Runtime.Nodes.Analysis.Summary = NodeCatalog.runtime_module(:summary)
    end

    test "returns nil for output nodes" do
      assert nil == NodeCatalog.runtime_module(:csv_report)
      assert nil == NodeCatalog.runtime_module(:json_report)
    end

    test "returns nil for nodes without implementations" do
      assert nil == NodeCatalog.runtime_module(:blast_radius_analysis)
    end

    test "returns nil for unknown nodes" do
      assert nil == NodeCatalog.runtime_module(:nonexistent)
    end
  end

  describe "runtime_type/1" do
    test "returns registry ID string from module metadata" do
      assert "gitlock.trigger.git_commits" = NodeCatalog.runtime_type(:git_log)
      assert "gitlock.analysis.hotspot" = NodeCatalog.runtime_type(:hotspot_detection)
      assert "gitlock.analysis.summary" = NodeCatalog.runtime_type(:summary)
    end

    test "returns nil for nodes without runtime modules" do
      assert nil == NodeCatalog.runtime_type(:csv_report)
      assert nil == NodeCatalog.runtime_type(:blast_radius_analysis)
      assert nil == NodeCatalog.runtime_type(:nonexistent)
    end
  end

  describe "runtime_modules/0" do
    test "returns all modules from the catalog" do
      modules = NodeCatalog.runtime_modules()

      assert is_list(modules)
      assert length(modules) > 0
      assert GitlockWorkflows.Runtime.Nodes.Triggers.GitCommits in modules
      assert GitlockWorkflows.Runtime.Nodes.Analysis.Hotspot in modules
    end

    test "does not include nil" do
      modules = NodeCatalog.runtime_modules()
      refute nil in modules
    end
  end

  describe "executable_types/0" do
    test "returns only types with runtime modules" do
      executable = NodeCatalog.executable_types()

      assert length(executable) > 0

      for type_def <- executable do
        assert type_def.runtime_module != nil,
               "Executable type #{type_def.type_id} should have a runtime_module"
      end
    end

    test "does not include source or output nodes without runtime" do
      executable_ids =
        NodeCatalog.executable_types()
        |> Enum.map(& &1.type_id)
        |> MapSet.new()

      refute MapSet.member?(executable_ids, :csv_report)
      refute MapSet.member?(executable_ids, :json_report)
      refute MapSet.member?(executable_ids, :blast_radius_analysis)
    end
  end

  describe "categories" do
    test "source nodes have no input ports" do
      sources = NodeCatalog.by_category(:source)
      assert length(sources) > 0

      for type_def <- sources do
        assert type_def.input_ports == [],
               "Source node #{type_def.type_id} should have no input ports"
      end
    end

    test "output nodes have no output ports" do
      outputs = NodeCatalog.by_category(:output)
      assert length(outputs) > 0

      for type_def <- outputs do
        assert type_def.output_ports == [],
               "Output node #{type_def.type_id} should have no output ports"
      end
    end

    test "analysis nodes have both input and output ports" do
      analyzers = NodeCatalog.by_category(:analyze)
      assert length(analyzers) > 0

      for type_def <- analyzers do
        assert length(type_def.input_ports) > 0,
               "Analysis node #{type_def.type_id} should have input ports"

        assert length(type_def.output_ports) > 0,
               "Analysis node #{type_def.type_id} should have output ports"
      end
    end

    test "no output nodes have runtime modules" do
      outputs = NodeCatalog.by_category(:output)

      for type_def <- outputs do
        assert type_def.runtime_module == nil,
               "Output node #{type_def.type_id} should not have a runtime_module"
      end
    end
  end

  describe "by_category/1" do
    test "filters by category" do
      sources = NodeCatalog.by_category(:source)

      assert length(sources) > 0
      assert Enum.all?(sources, &(&1.category == :source))
    end

    test "returns empty list for unknown category" do
      assert [] = NodeCatalog.by_category(:nonexistent)
    end
  end
end
