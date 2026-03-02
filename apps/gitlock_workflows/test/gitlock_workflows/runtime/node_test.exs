defmodule GitlockWorkflows.Runtime.NodeTest do
  use ExUnit.Case, async: true

  alias GitlockWorkflows.Runtime.Node
  alias GitlockWorkflows.Fixtures.Nodes.{TestNode, TargetNode}

  # Test node implementation
  setup do
    # Register test nodes
    :ok = GitlockWorkflows.Runtime.Registry.register_nodes([TestNode, TargetNode])

    on_exit(fn ->
      # Cleanup registered nodes
      GitlockWorkflows.Runtime.Registry.unregister_node("test.node")
      GitlockWorkflows.Runtime.Registry.unregister_node("test.target")
    end)

    :ok
  end

  describe "using macro" do
    test "provides default reactor_options" do
      assert TestNode.reactor_options() == []
    end
  end

  describe "get_module/1" do
    test "retrieves registered node module" do
      assert {:ok, TestNode} = Node.get_module("test.node")
    end

    test "returns error for unknown node" do
      assert {:error, :not_found} = Node.get_module("unknown.node")
    end
  end

  describe "get_metadata/1" do
    test "retrieves node metadata" do
      assert {:ok, metadata} = Node.get_metadata("test.node")
      assert metadata.id == "test.node"
      assert metadata.displayName == "Test Node"
      assert length(metadata.inputs) == 2
      assert length(metadata.outputs) == 2
    end

    test "returns error for unknown node" do
      assert {:error, :not_found} = Node.get_metadata("unknown.node")
    end
  end
end
