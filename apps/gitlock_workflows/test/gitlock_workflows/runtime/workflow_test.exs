defmodule GitlockWorkflows.Runtime.WorkflowTest do
  use ExUnit.Case, async: true

  alias GitlockWorkflows.Runtime.Workflow
  alias GitlockWorkflows.Runtime.Registry
  alias GitlockWorkflows.Fixtures.Nodes.{TriggerNode, ProcessNode, OutputNode}

  setup do
    # Register test nodes
    Registry.register_nodes([TriggerNode, ProcessNode, OutputNode])

    on_exit(fn ->
      Registry.unregister_node("test.trigger")
      Registry.unregister_node("test.process")
      Registry.unregister_node("test.output")
    end)

    :ok
  end

  describe "from_json/1" do
    test "parses valid n8n-compatible JSON" do
      json = ~s({
        "id": "workflow_123",
        "name": "Test Workflow",
        "description": "A test workflow",
        "nodes": [
          {
            "id": "node_1",
            "type": "test.trigger",
            "position": [100, 200],
            "parameters": {},
            "disabled": false
          }
        ],
        "connections": [],
        "settings": {"executionOrder": "v1"},
        "version": 1
      })

      assert {:ok, workflow} = Workflow.from_json(json)
      assert workflow.id == "workflow_123"
      assert workflow.name == "Test Workflow"
      assert workflow.description == "A test workflow"
      assert length(workflow.nodes) == 1
      assert workflow.version == 1
    end

    test "generates id if missing" do
      json = ~s({
        "name": "No ID Workflow",
        "nodes": [],
        "connections": []
      })

      assert {:ok, workflow} = Workflow.from_json(json)
      assert String.starts_with?(workflow.id, "wf_")
    end

    test "uses defaults for missing fields" do
      json = ~s({
        "nodes": [],
        "connections": []
      })

      assert {:ok, workflow} = Workflow.from_json(json)
      assert workflow.name == "Untitled Workflow"
      assert is_nil(workflow.description)
      assert workflow.settings == %{}
      assert workflow.version == 1
    end

    test "parses connections correctly" do
      json = ~s({
        "name": "Connected Workflow",
        "nodes": [
          {"id": "node_1", "type": "test.trigger"},
          {"id": "node_2", "type": "test.process"}
        ],
        "connections": [
          {
            "from": {"node": "node_1", "output": "main"},
            "to": {"node": "node_2", "input": "main"}
          }
        ]
      })

      assert {:ok, workflow} = Workflow.from_json(json)
      assert length(workflow.connections) == 1

      [conn] = workflow.connections
      assert conn.from.node == "node_1"
      assert conn.from.port == "main"
      assert conn.to.node == "node_2"
      assert conn.to.port == "main"
    end

    test "handles invalid JSON" do
      assert {:error, {:invalid_json, _}} = Workflow.from_json("not json")
    end

    test "handles parse errors" do
      # JSON missing required fields in nodes
      json = ~s({
        "nodes": [{"position": [0, 0]}],
        "connections": []
      })

      assert {:error, {:parse_error, _}} = Workflow.from_json(json)
    end
  end

  describe "to_json/1" do
    test "serializes workflow to JSON" do
      workflow = %Workflow{
        id: "wf_123",
        name: "Test",
        description: "Test workflow",
        nodes: [
          %{
            id: "node_1",
            type: "test.trigger",
            position: [0, 0],
            parameters: %{},
            disabled: false
          }
        ],
        connections: [
          %{
            from: %{node: "node_1", port: "main"},
            to: %{node: "node_2", port: "main"}
          }
        ],
        settings: %{},
        version: 1
      }

      assert {:ok, json} = Workflow.to_json(workflow)
      assert {:ok, parsed} = Jason.decode(json)

      assert parsed["id"] == "wf_123"
      assert parsed["name"] == "Test"
      assert length(parsed["nodes"]) == 1
      assert length(parsed["connections"]) == 1
    end
  end

  describe "add_node/2" do
    test "adds node to workflow" do
      workflow = %Workflow{
        id: "wf_1",
        name: "Test",
        nodes: [],
        connections: []
      }

      node = %{
        id: "node_1",
        type: "test.trigger",
        position: [0, 0],
        parameters: %{},
        disabled: false
      }

      updated = Workflow.add_node(workflow, node)
      assert length(updated.nodes) == 1
      assert hd(updated.nodes).id == "node_1"
      # Reactor cleared
      assert is_nil(updated.reactor)
    end

    test "raises on missing required fields" do
      workflow = %Workflow{nodes: [], connections: []}

      assert_raise ArgumentError, ~r/must have id and type/, fn ->
        Workflow.add_node(workflow, %{position: [0, 0]})
      end
    end

    test "raises on duplicate node id" do
      workflow = %Workflow{
        nodes: [%{id: "node_1", type: "test.trigger"}],
        connections: []
      }

      assert_raise ArgumentError, ~r/already exists/, fn ->
        Workflow.add_node(workflow, %{id: "node_1", type: "test.process"})
      end
    end
  end

  describe "add_connection/4" do
    setup do
      workflow = %Workflow{
        id: "wf_1",
        name: "Test",
        nodes: [
          %{id: "node_1", type: "test.trigger"},
          %{id: "node_2", type: "test.process"}
        ],
        connections: []
      }

      {:ok, workflow: workflow}
    end

    test "adds connection between existing nodes", %{workflow: workflow} do
      assert {:ok, updated} = Workflow.add_connection(workflow, "node_1", "node_2")
      assert length(updated.connections) == 1

      [conn] = updated.connections
      assert conn.from.node == "node_1"
      # default
      assert conn.from.port == "main"
      assert conn.to.node == "node_2"
      # default
      assert conn.to.port == "main"
    end

    test "adds connection with custom ports", %{workflow: workflow} do
      assert {:ok, updated} =
               Workflow.add_connection(
                 workflow,
                 "node_1",
                 "node_2",
                 from_port: "output1",
                 to_port: "input2"
               )

      [conn] = updated.connections
      assert conn.from.port == "output1"
      assert conn.to.port == "input2"
    end

    test "returns error for non-existent from node", %{workflow: workflow} do
      assert {:error, {:node_not_found, "missing"}} =
               Workflow.add_connection(workflow, "missing", "node_2")
    end

    test "returns error for non-existent to node", %{workflow: workflow} do
      assert {:error, {:node_not_found, "missing"}} =
               Workflow.add_connection(workflow, "node_1", "missing")
    end

    test "returns error for duplicate connection", %{workflow: workflow} do
      {:ok, with_connection} = Workflow.add_connection(workflow, "node_1", "node_2")

      assert {:error, :connection_already_exists} =
               Workflow.add_connection(with_connection, "node_1", "node_2")
    end
  end

  describe "get_node/2" do
    setup do
      workflow = %Workflow{
        nodes: [
          %{id: "n1", type: "test.trigger"},
          %{id: "n2", type: "test.process"}
        ],
        connections: []
      }

      {:ok, workflow: workflow}
    end

    test "returns node by id", %{workflow: workflow} do
      node = Workflow.get_node(workflow, "n1")
      assert node.id == "n1"
      assert node.type == "test.trigger"
    end

    test "returns nil for unknown node", %{workflow: workflow} do
      assert is_nil(Workflow.get_node(workflow, "unknown"))
    end
  end

  describe "get_nodes_by_type/2" do
    setup do
      workflow = %Workflow{
        nodes: [
          %{id: "n1", type: "test.trigger"},
          %{id: "n2", type: "test.process"},
          %{id: "n3", type: "test.trigger"}
        ],
        connections: []
      }

      {:ok, workflow: workflow}
    end

    test "returns all nodes of type", %{workflow: workflow} do
      triggers = Workflow.get_nodes_by_type(workflow, "test.trigger")
      assert length(triggers) == 2
      assert Enum.all?(triggers, fn n -> n.type == "test.trigger" end)
    end

    test "returns empty list for unknown type", %{workflow: workflow} do
      assert Workflow.get_nodes_by_type(workflow, "unknown") == []
    end
  end

  describe "get_node_connections/2" do
    setup do
      workflow = %Workflow{
        nodes: [
          %{id: "n1", type: "test.trigger"},
          %{id: "n2", type: "test.process"},
          %{id: "n3", type: "test.output"}
        ],
        connections: [
          %{from: %{node: "n1", port: "main"}, to: %{node: "n2", port: "main"}},
          %{from: %{node: "n2", port: "main"}, to: %{node: "n3", port: "main"}}
        ]
      }

      {:ok, workflow: workflow}
    end

    test "returns inputs and outputs for node", %{workflow: workflow} do
      connections = Workflow.get_node_connections(workflow, "n2")

      assert length(connections.inputs) == 1
      assert length(connections.outputs) == 1

      [input] = connections.inputs
      assert input.from.node == "n1"

      [output] = connections.outputs
      assert output.to.node == "n3"
    end

    test "returns empty lists for unconnected node", %{workflow: workflow} do
      workflow = %{workflow | connections: []}
      connections = Workflow.get_node_connections(workflow, "n2")

      assert connections.inputs == []
      assert connections.outputs == []
    end
  end

  describe "reactor_ready?/1" do
    test "returns false when reactor is nil" do
      workflow = %Workflow{reactor: nil}
      refute Workflow.reactor_ready?(workflow)
    end

    test "returns true when reactor exists" do
      # Mock reactor
      workflow = %Workflow{reactor: %{}}
      assert Workflow.reactor_ready?(workflow)
    end
  end

  describe "to_reactor/1" do
    test "returns error for empty workflow" do
      workflow = %Workflow{nodes: [], connections: []}
      assert {:error, :empty_workflow} = Workflow.to_reactor(workflow)
    end

    test "successfully converts workflow with registered trigger node to reactor" do
      workflow = %Workflow{
        id: "wf_1",
        nodes: [
          %{id: "n1", type: "test.trigger", parameters: %{}, disabled: false}
        ],
        connections: []
      }

      assert {:ok, %Workflow{reactor: reactor}} = Workflow.to_reactor(workflow)

      # Verify the reactor was properly built
      assert reactor != nil
      assert reactor.steps != []
      assert length(reactor.steps) == 1

      # Verify the step configuration
      step = hd(reactor.steps)
      assert step.impl == GitlockWorkflows.Fixtures.Nodes.TriggerNode
      assert step.name == :n1
    end

    test "successfully converts workflow with bridged node to reactor" do
      # Create a test node using the bridged interface
      defmodule TestBridgedNode do
        use GitlockWorkflows.Runtime.Node

        @impl true
        def metadata do
          %{
            id: "test.bridged",
            displayName: "Test Bridged Node",
            group: "test",
            version: 1,
            description: "Test node with proper bridging",
            inputs: [],
            outputs: [%{name: "main", type: :any, required: false}],
            parameters: []
          }
        end

        @impl true
        def execute(_input_data, _parameters, _context) do
          {:ok, %{"main" => "test success"}}
        end

        @impl true
        def validate_parameters(_parameters) do
          :ok
        end
      end

      # Register the node
      :ok = GitlockWorkflows.Runtime.Registry.register_node(TestBridgedNode)

      workflow = %Workflow{
        id: "test_workflow",
        nodes: [
          %{id: "n1", type: "test.bridged", parameters: %{}, disabled: false}
        ],
        connections: []
      }

      assert {:ok, %Workflow{reactor: reactor}} = Workflow.to_reactor(workflow)
      assert reactor != nil
    end
  end
end
