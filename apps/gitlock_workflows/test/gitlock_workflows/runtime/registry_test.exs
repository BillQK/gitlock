defmodule GitlockWorkflows.Runtime.RegistryTest do
  use ExUnit.Case, async: false

  alias GitlockWorkflows.Runtime.Registry
  alias GitlockWorkflows.Fixtures.Nodes

  # Invalid node for testing
  defmodule InvalidNode do
    # Deliberately missing required functions
    def some_function, do: :ok
  end

  setup do
    # Store initial registry state
    initial_nodes = Registry.list_nodes()
    initial_node_ids = Enum.map(initial_nodes, & &1.id)

    # Clean up any previously registered test nodes
    on_exit(fn ->
      # Get current nodes
      current_nodes = Registry.list_nodes()

      # Remove any nodes that weren't there initially
      Enum.each(current_nodes, fn node ->
        unless node.id in initial_node_ids do
          Registry.unregister_node(node.id)
        end
      end)
    end)

    :ok
  end

  describe "start_link/1" do
    test "registry starts successfully" do
      # Registry should already be started by the application
      assert Process.whereis(Registry) != nil
    end
  end

  describe "register_node/1" do
    test "registers a valid node successfully" do
      assert :ok = Registry.register_node(Nodes.ValidNode)

      # Verify registration
      assert {:ok, Nodes.ValidNode} = Registry.get_node("test.valid")
    end

    test "handles metadata normalization" do
      defmodule PartialNode do
        use GitlockWorkflows.Runtime.Node

        def metadata do
          %{
            id: "test.partial",
            # Missing displayName, should default to id
            # Missing group, should default to "other"
            version: 1,
            description: "Test",
            inputs: [],
            outputs: [],
            parameters: []
          }
        end

        def execute(_, _, _), do: {:ok, %{}}
        def validate_parameters(_), do: :ok
      end

      assert :ok = Registry.register_node(PartialNode)
      assert {:ok, metadata} = Registry.get_metadata("test.partial")

      # Defaults to id
      assert metadata.displayName == "test.partial"
      # Default group
      assert metadata.group == "other"
      # Default empty
      assert metadata.tags == []
      assert metadata.deprecated == false
      assert metadata.experimental == false
    end

    test "returns error for invalid node" do
      assert {:error, errors} = Registry.register_node(InvalidNode)

      assert Enum.any?(errors, fn
               {:missing_function, _} -> true
               _ -> false
             end)
    end

    test "returns error for node with invalid metadata" do
      defmodule BadMetadataNode do
        use GitlockWorkflows.Runtime.Node

        def metadata do
          %{
            # Missing required id field
            displayName: "Bad Node",
            group: "test",
            version: 1,
            description: "Invalid",
            # Should be a list
            inputs: "not a list",
            outputs: [],
            parameters: []
          }
        end

        def execute(_, _, _), do: {:ok, %{}}
        def validate_parameters(_), do: :ok
      end

      assert {:error, errors} = Registry.register_node(BadMetadataNode)

      assert Enum.any?(errors, fn
               {:invalid_id, _} -> true
               {:invalid_metadata, _} -> true
               _ -> false
             end)
    end
  end

  describe "register_nodes/1" do
    test "registers multiple nodes successfully" do
      assert :ok = Registry.register_nodes([Nodes.ValidNode, Nodes.MinimalNode])

      assert {:ok, Nodes.ValidNode} = Registry.get_node("test.valid")
      assert {:ok, Nodes.MinimalNode} = Registry.get_node("test.minimal")
    end

    test "returns errors for failed registrations" do
      assert {:error, failures} =
               Registry.register_nodes([Nodes.ValidNode, InvalidNode, Nodes.MinimalNode])

      # ValidNode and MinimalNode should succeed
      assert {:ok, Nodes.ValidNode} = Registry.get_node("test.valid")
      assert {:ok, Nodes.MinimalNode} = Registry.get_node("test.minimal")

      # InvalidNode should be in failures
      assert Map.has_key?(failures, InvalidNode)
    end
  end

  describe "get_node/1" do
    setup do
      Registry.register_node(Nodes.ValidNode)
      :ok
    end

    test "returns module for registered node" do
      assert {:ok, Nodes.ValidNode} = Registry.get_node("test.valid")
    end

    test "returns error for unknown node" do
      assert {:error, :not_found} = Registry.get_node("unknown.node")
    end
  end

  describe "get_metadata/1" do
    setup do
      Registry.register_node(Nodes.ValidNode)
      :ok
    end

    test "returns metadata for registered node" do
      assert {:ok, metadata} = Registry.get_metadata("test.valid")
      assert metadata.id == "test.valid"
      assert metadata.displayName == "Valid Test Node"
      assert metadata.experimental == true
    end

    test "returns error for unknown node" do
      assert {:error, :not_found} = Registry.get_metadata("unknown.node")
    end
  end

  describe "list_nodes/0" do
    test "returns empty list when no nodes registered" do
      # Clear any existing nodes
      nodes = Registry.list_nodes()

      Enum.each(nodes, fn node ->
        Registry.unregister_node(node.id)
      end)

      assert Registry.list_nodes() == []
    end

    test "returns all registered nodes sorted by display name" do
      Registry.register_nodes([Nodes.MinimalNode, Nodes.ValidNode])

      nodes = Registry.list_nodes()
      node_ids = Enum.map(nodes, & &1.id)

      assert "test.minimal" in node_ids
      assert "test.valid" in node_ids

      # Check sorting
      display_names = Enum.map(nodes, & &1.displayName)
      assert display_names == Enum.sort(display_names)
    end
  end

  describe "list_nodes_by_category/1" do
    setup do
      Registry.register_nodes([Nodes.ValidNode, Nodes.MinimalNode, Nodes.AnalysisNode])
      :ok
    end

    test "returns nodes in specified category" do
      test_nodes = Registry.list_nodes_by_category("test")
      assert length(test_nodes) >= 2
      assert Enum.all?(test_nodes, fn node -> node.group == "test" end)

      analysis_nodes = Registry.list_nodes_by_category("analysis")
      assert length(analysis_nodes) >= 1
      assert Enum.all?(analysis_nodes, fn node -> node.group == "analysis" end)
    end

    test "returns empty list for unknown category" do
      assert Registry.list_nodes_by_category("unknown") == []
    end
  end

  describe "list_categories/0" do
    setup do
      Registry.register_nodes([Nodes.ValidNode, Nodes.MinimalNode])
      :ok
    end

    test "returns sorted list of categories" do
      categories = Registry.list_categories()
      assert "test" in categories
      assert categories == Enum.sort(categories)
    end
  end

  describe "search_nodes/1" do
    setup do
      Registry.register_nodes([Nodes.ValidNode, Nodes.SearchableNode])
      :ok
    end

    test "searches by id" do
      results = Registry.search_nodes("searchable")
      assert length(results) >= 1
      assert Enum.any?(results, fn node -> node.id == "test.searchable" end)
    end

    test "searches by display name" do
      results = Registry.search_nodes("hotspot")
      assert length(results) >= 1
      assert Enum.any?(results, fn node -> node.displayName == "Hotspot Analyzer" end)
    end

    test "searches by description" do
      results = Registry.search_nodes("analyzes")
      assert length(results) >= 1
    end

    test "searches by tags" do
      results = Registry.search_nodes("git")
      assert length(results) >= 1
    end

    test "search is case insensitive" do
      results1 = Registry.search_nodes("HOTSPOT")
      results2 = Registry.search_nodes("hotspot")
      assert length(results1) == length(results2)
    end

    test "returns empty list for no matches" do
      assert Registry.search_nodes("nonexistent") == []
    end
  end

  describe "validate_node/1" do
    test "validates correct node" do
      assert :ok = Registry.validate_node(Nodes.ValidNode)
    end

    test "returns errors for invalid node" do
      assert {:error, errors} = Registry.validate_node(InvalidNode)
      assert is_list(errors)
      assert length(errors) > 0
    end

    test "checks for required functions" do
      defmodule MissingExecute do
        def metadata do
          %{
            id: "test.missing",
            displayName: "Missing Execute",
            group: "test",
            version: 1,
            description: "Test",
            inputs: [],
            outputs: [],
            parameters: []
          }
        end

        def validate_parameters(_), do: :ok
      end

      assert {:error, errors} = Registry.validate_node(MissingExecute)

      assert Enum.any?(errors, fn
               {:missing_function, :execute} -> true
               _ -> false
             end)
    end
  end

  describe "get_stats/0" do
    test "returns registry statistics" do
      # Clear registry first
      nodes = Registry.list_nodes()

      Enum.each(nodes, fn node ->
        Registry.unregister_node(node.id)
      end)

      # Register known nodes
      Registry.register_nodes([Nodes.ValidNode, Nodes.MinimalNode])

      stats = Registry.get_stats()

      assert stats.total_nodes >= 2
      assert stats.nodes_by_group["test"] >= 2
      assert %DateTime{} = stats.last_updated
    end
  end

  describe "unregister_node/1" do
    setup do
      Registry.register_node(Nodes.ValidNode)
      :ok
    end

    test "removes registered node" do
      assert {:ok, Nodes.ValidNode} = Registry.get_node("test.valid")
      assert :ok = Registry.unregister_node("test.valid")
      assert {:error, :not_found} = Registry.get_node("test.valid")
    end

    test "returns error for unknown node" do
      assert {:error, :not_found} = Registry.unregister_node("unknown.node")
    end

    test "updates statistics after removal" do
      initial_stats = Registry.get_stats()
      initial_count = initial_stats.total_nodes

      Registry.unregister_node("test.valid")

      new_stats = Registry.get_stats()
      assert new_stats.total_nodes == initial_count - 1
    end
  end

  describe "search index" do
    test "builds search index from node metadata" do
      defmodule IndexTestNode do
        use GitlockWorkflows.Runtime.Node

        def metadata do
          %{
            id: "test.index_node",
            displayName: "Complex Test Node",
            group: "testing",
            version: 1,
            description: "This node tests indexing",
            inputs: [],
            outputs: [],
            parameters: [],
            tags: ["index", "search", "test"]
          }
        end

        def execute(_, _, _), do: {:ok, %{}}
        def validate_parameters(_), do: :ok
      end

      Registry.register_node(IndexTestNode)

      # Should find by various terms
      assert length(Registry.search_nodes("complex")) >= 1
      assert length(Registry.search_nodes("index")) >= 1
      assert length(Registry.search_nodes("testing")) >= 1
    end
  end
end
