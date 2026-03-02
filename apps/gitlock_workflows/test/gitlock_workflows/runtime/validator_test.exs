defmodule GitlockWorkflows.Runtime.ValidatorTest do
  use ExUnit.Case, async: false

  alias GitlockWorkflows.Runtime.{Validator, Workflow, Registry}
  alias GitlockWorkflows.Fixtures.Nodes.{TriggerNode, ProcessNode, OutputNode}

  # Test nodes for validation scenarios
  defmodule StringOutputNode do
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.string_output",
        displayName: "String Output Node",
        group: "test",
        version: 1,
        description: "Outputs string data",
        inputs: [%{name: "main", type: :any, required: true}],
        outputs: [%{name: "text", type: :string, required: false}],
        parameters: [
          %{name: "prefix", displayName: "Prefix", type: "string", default: "", required: false}
        ]
      }
    end

    @impl true
    def execute(_input_data, parameters, _context) do
      prefix = Map.get(parameters, "prefix", "")
      {:ok, %{"text" => "#{prefix}processed"}}
    end

    @impl true
    def validate_parameters(parameters) do
      case Map.get(parameters, "prefix") do
        nil -> :ok
        value when is_binary(value) -> :ok
        _ -> {:error, [{:invalid_type, "prefix"}]}
      end
    end
  end

  defmodule NumberInputNode do
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.number_input",
        displayName: "Number Input Node",
        group: "test",
        version: 1,
        description: "Requires number input",
        inputs: [%{name: "value", type: :number, required: true}],
        outputs: [%{name: "main", type: :any, required: false}],
        parameters: [
          %{
            name: "threshold",
            displayName: "Threshold",
            type: "number",
            default: 10,
            required: true,
            min: 1,
            max: 100
          }
        ]
      }
    end

    @impl true
    def execute(_input_data, _parameters, _context) do
      {:ok, %{"main" => "processed"}}
    end

    @impl true
    def validate_parameters(parameters) do
      case Map.get(parameters, "threshold") do
        nil ->
          {:error, [{:missing_required_parameter, "threshold"}]}

        value when is_number(value) and value >= 1 and value <= 100 ->
          :ok

        value when is_number(value) ->
          {:error, [{:invalid_parameter_value, "threshold", "out of range"}]}

        _ ->
          {:error, [{:invalid_parameter_type, "threshold", "number"}]}
      end
    end
  end

  defmodule RequiredParamsNode do
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.required_params",
        displayName: "Required Params Node",
        group: "test",
        version: 1,
        description: "Node with required parameters",
        inputs: [%{name: "main", type: :any, required: true}],
        outputs: [%{name: "main", type: :any, required: false}],
        parameters: [
          %{
            name: "required_string",
            displayName: "Required String",
            type: "string",
            required: true
          },
          %{
            name: "required_number",
            displayName: "Required Number",
            type: "number",
            required: true
          },
          %{
            name: "optional_param",
            displayName: "Optional",
            type: "string",
            required: false,
            default: "default"
          }
        ]
      }
    end

    @impl true
    def execute(_input_data, _parameters, _context) do
      {:ok, %{"main" => "processed"}}
    end

    @impl true
    def validate_parameters(parameters) do
      errors = []

      # Check required string
      errors =
        case Map.get(parameters, "required_string") do
          nil -> [{:missing_required_parameter, "required_string"} | errors]
          value when is_binary(value) -> errors
          _ -> [{:invalid_parameter_type, "required_string", "string"} | errors]
        end

      # Check required number
      errors =
        case Map.get(parameters, "required_number") do
          nil -> [{:missing_required_parameter, "required_number"} | errors]
          value when is_number(value) -> errors
          _ -> [{:invalid_parameter_type, "required_number", "number"} | errors]
        end

      if errors == [], do: :ok, else: {:error, Enum.reverse(errors)}
    end
  end

  setup do
    # Register test nodes
    Registry.register_nodes([
      TriggerNode,
      ProcessNode,
      OutputNode,
      StringOutputNode,
      NumberInputNode,
      RequiredParamsNode
    ])

    on_exit(fn ->
      # Cleanup
      Registry.unregister_node("test.trigger")
      Registry.unregister_node("test.process")
      Registry.unregister_node("test.output")
      Registry.unregister_node("test.string_output")
      Registry.unregister_node("test.number_input")
      Registry.unregister_node("test.required_params")
    end)

    :ok
  end

  describe "validate_workflow/1" do
    test "validates simple valid workflow" do
      workflow = create_simple_valid_workflow()
      assert {:ok, ^workflow} = Validator.validate_workflow(workflow)
    end

    test "returns all validation errors" do
      # Create a workflow with multiple issues
      invalid_workflow = %Workflow{
        id: "invalid",
        name: "Invalid Workflow",
        nodes: [
          # Unknown node type
          %{
            id: "bad_node",
            type: "unknown.type",
            parameters: %{},
            disabled: false,
            position: [0, 0]
          },
          # Duplicate ID
          %{
            id: "dup_id",
            type: "test.trigger",
            parameters: %{},
            disabled: false,
            position: [0, 0]
          },
          %{
            id: "dup_id",
            type: "test.process",
            parameters: %{},
            disabled: false,
            position: [100, 0]
          },
          # Missing required parameters
          %{
            id: "missing_params",
            type: "test.required_params",
            parameters: %{},
            disabled: false,
            position: [200, 0]
          }
        ],
        connections: [
          # Connection to non-existent node
          %{from: %{node: "bad_node", port: "main"}, to: %{node: "missing_node", port: "main"}}
        ],
        settings: %{},
        version: 1
      }

      assert {:error, errors} = Validator.validate_workflow(invalid_workflow)
      assert is_list(errors)
      assert length(errors) > 0

      # Should contain multiple error types
      error_types = Enum.map(errors, fn error -> elem(error, 0) end)
      assert :duplicate_node_id in error_types
      assert :unknown_node_type in error_types
      assert :missing_required_parameter in error_types
    end
  end

  describe "validate_structure/1" do
    test "rejects empty workflow" do
      empty_workflow = %Workflow{nodes: [], connections: []}
      assert {:error, [{:empty_workflow}]} = Validator.validate_structure(empty_workflow)
    end

    test "detects duplicate node IDs" do
      workflow = %Workflow{
        nodes: [
          %{id: "node1", type: "test.trigger"},
          # Duplicate ID
          %{id: "node1", type: "test.process"}
        ],
        connections: []
      }

      assert {:error, errors} = Validator.validate_structure(workflow)
      assert {:duplicate_node_id, "node1"} in errors
    end

    test "detects duplicate connections" do
      workflow = %Workflow{
        nodes: [
          %{id: "node1", type: "test.trigger"},
          %{id: "node2", type: "test.process"}
        ],
        connections: [
          %{from: %{node: "node1", port: "main"}, to: %{node: "node2", port: "main"}},
          # Duplicate
          %{from: %{node: "node1", port: "main"}, to: %{node: "node2", port: "main"}}
        ]
      }

      assert {:error, errors} = Validator.validate_structure(workflow)
      assert {:duplicate_connection, "node1.main", "node2.main"} in errors
    end

    test "passes valid structure" do
      workflow = create_simple_valid_workflow()
      assert {:ok, ^workflow} = Validator.validate_structure(workflow)
    end
  end

  describe "validate_nodes/1" do
    test "validates all nodes successfully" do
      workflow = create_simple_valid_workflow()
      assert {:ok, ^workflow} = Validator.validate_nodes(workflow)
    end

    test "skips disabled nodes" do
      workflow = %Workflow{
        nodes: [
          %{id: "enabled", type: "test.trigger", parameters: %{}, disabled: false},
          # Would fail if checked
          %{id: "disabled", type: "unknown.type", parameters: %{}, disabled: true}
        ],
        connections: []
      }

      assert {:ok, ^workflow} = Validator.validate_nodes(workflow)
    end

    test "detects unknown node types" do
      workflow = %Workflow{
        nodes: [
          %{id: "unknown", type: "unknown.type", parameters: %{}, disabled: false}
        ],
        connections: []
      }

      assert {:error, errors} = Validator.validate_nodes(workflow)
      assert {:unknown_node_type, "unknown", "unknown.type"} in errors
    end
  end

  describe "validate_single_node/2" do
    test "validates node with correct parameters" do
      node = %{
        id: "test",
        type: "test.required_params",
        parameters: %{
          "required_string" => "test",
          "required_number" => 42
        }
      }

      errors = Validator.validate_single_node(node, %Workflow{})
      assert errors == []
    end

    test "detects missing required parameters" do
      node = %{id: "test", type: "test.required_params", parameters: %{}}

      errors = Validator.validate_single_node(node, %Workflow{})
      assert {:missing_required_parameter, "test", "required_string"} in errors
      assert {:missing_required_parameter, "test", "required_number"} in errors
    end

    test "detects invalid parameter types" do
      node = %{
        id: "test",
        type: "test.number_input",
        parameters: %{
          "threshold" => "not_a_number"
        }
      }

      errors = Validator.validate_single_node(node, %Workflow{})
      assert [{:invalid_parameter_type, "test", "threshold", "number", _}] = errors
    end

    test "detects out-of-range parameter values" do
      node = %{
        id: "test",
        type: "test.number_input",
        parameters: %{
          # max is 100
          "threshold" => 150
        }
      }

      errors = Validator.validate_single_node(node, %Workflow{})
      assert [{:invalid_parameter_value, "test", "threshold", _}] = errors
    end
  end

  describe "validate_connections/1" do
    test "validates all connections successfully" do
      workflow = create_workflow_with_connections()
      assert {:ok, ^workflow} = Validator.validate_connections(workflow)
    end

    test "detects missing from node" do
      workflow = %Workflow{
        nodes: [
          %{id: "node2", type: "test.process"}
        ],
        connections: [
          %{from: %{node: "missing", port: "main"}, to: %{node: "node2", port: "main"}}
        ]
      }

      assert {:error, errors} = Validator.validate_connections(workflow)
      assert {:connection_missing_from_node, "missing"} in errors
    end

    test "detects missing to node" do
      workflow = %Workflow{
        nodes: [
          %{id: "node1", type: "test.trigger"}
        ],
        connections: [
          %{from: %{node: "node1", port: "main"}, to: %{node: "missing", port: "main"}}
        ]
      }

      assert {:error, errors} = Validator.validate_connections(workflow)
      assert {:connection_missing_to_node, "missing"} in errors
    end

    test "detects unknown output port" do
      workflow = %Workflow{
        nodes: [
          %{id: "node1", type: "test.trigger", disabled: false},
          %{id: "node2", type: "test.process", disabled: false}
        ],
        connections: [
          %{from: %{node: "node1", port: "unknown_port"}, to: %{node: "node2", port: "main"}}
        ]
      }

      assert {:error, errors} = Validator.validate_connections(workflow)
      assert {:unknown_output_port, "node1", "unknown_port"} in errors
    end

    test "detects unknown input port" do
      workflow = %Workflow{
        nodes: [
          %{id: "node1", type: "test.trigger", disabled: false},
          %{id: "node2", type: "test.process", disabled: false}
        ],
        connections: [
          %{from: %{node: "node1", port: "main"}, to: %{node: "node2", port: "unknown_port"}}
        ]
      }

      assert {:error, errors} = Validator.validate_connections(workflow)
      assert {:unknown_input_port, "node2", "unknown_port"} in errors
    end

    test "detects incompatible port types" do
      workflow = %Workflow{
        nodes: [
          %{id: "string_out", type: "test.string_output", disabled: false},
          %{id: "number_in", type: "test.number_input", disabled: false}
        ],
        connections: [
          # String output -> Number input (incompatible)
          %{from: %{node: "string_out", port: "text"}, to: %{node: "number_in", port: "value"}}
        ]
      }

      assert {:error, errors} = Validator.validate_connections(workflow)
      assert length(errors) > 0

      # Should have incompatible port types error
      assert Enum.any?(errors, fn
               {:incompatible_port_types, _, _, _} -> true
               _ -> false
             end)
    end
  end

  describe "check_port_compatibility/2" do
    test "any type is compatible with everything" do
      any_port = %{type: :any}
      string_port = %{type: :string}

      assert :compatible = Validator.check_port_compatibility(any_port, string_port)
      assert :compatible = Validator.check_port_compatibility(string_port, any_port)
    end

    test "exact type matches are compatible" do
      string_port = %{type: :string}
      number_port = %{type: :number}

      assert :compatible = Validator.check_port_compatibility(string_port, string_port)
      assert :compatible = Validator.check_port_compatibility(number_port, number_port)
    end

    test "incompatible simple types" do
      string_port = %{type: :string}
      number_port = %{type: :number}

      assert {:incompatible, _} = Validator.check_port_compatibility(string_port, number_port)
    end

    test "list type compatibility" do
      string_list = %{type: {:list, :string}}
      number_list = %{type: {:list, :number}}
      any_list = %{type: {:list, :any}}

      assert :compatible = Validator.check_port_compatibility(string_list, string_list)
      assert :compatible = Validator.check_port_compatibility(string_list, any_list)
      assert {:incompatible, _} = Validator.check_port_compatibility(string_list, number_list)
    end

    test "map type compatibility" do
      string_map = %{type: {:map, :string}}
      number_map = %{type: {:map, :number}}
      any_map = %{type: {:map, :any}}

      assert :compatible = Validator.check_port_compatibility(string_map, string_map)
      assert :compatible = Validator.check_port_compatibility(string_map, any_map)
      assert {:incompatible, _} = Validator.check_port_compatibility(string_map, number_map)
    end
  end

  describe "validate_topology/1" do
    test "validates acyclic workflow" do
      workflow = create_workflow_with_connections()
      assert {:ok, ^workflow} = Validator.validate_topology(workflow)
    end

    test "detects simple cycles" do
      workflow = %Workflow{
        nodes: [
          %{id: "node1", type: "test.process", disabled: false},
          %{id: "node2", type: "test.process", disabled: false}
        ],
        connections: [
          %{from: %{node: "node1", port: "main"}, to: %{node: "node2", port: "main"}},
          # Creates cycle
          %{from: %{node: "node2", port: "main"}, to: %{node: "node1", port: "main"}}
        ]
      }

      assert {:error, errors} = Validator.validate_topology(workflow)

      assert {:cycle_detected, path} =
               Enum.find(errors, fn
                 {:cycle_detected, _} -> true
                 _ -> false
               end)

      # Path should show the cycle
      assert is_list(path)
      # At least A -> B -> A
      assert length(path) >= 3
    end

    test "detects complex cycles" do
      workflow = %Workflow{
        nodes: [
          %{id: "a", type: "test.process", disabled: false},
          %{id: "b", type: "test.process", disabled: false},
          %{id: "c", type: "test.process", disabled: false}
        ],
        connections: [
          %{from: %{node: "a", port: "main"}, to: %{node: "b", port: "main"}},
          %{from: %{node: "b", port: "main"}, to: %{node: "c", port: "main"}},
          # Creates cycle
          %{from: %{node: "c", port: "main"}, to: %{node: "a", port: "main"}}
        ]
      }

      assert {:error, errors} = Validator.validate_topology(workflow)

      assert {:cycle_detected, _path} =
               Enum.find(errors, fn
                 {:cycle_detected, _} -> true
                 _ -> false
               end)
    end

    test "detects orphan nodes" do
      workflow = %Workflow{
        nodes: [
          # Trigger, not orphan
          %{id: "trigger", type: "test.trigger", disabled: false},
          # Connected, not orphan
          %{id: "connected", type: "test.process", disabled: false},
          # Orphan (not trigger, no connections)
          %{id: "orphan", type: "test.process", disabled: false}
        ],
        connections: [
          %{from: %{node: "trigger", port: "main"}, to: %{node: "connected", port: "main"}}
        ]
      }

      assert {:error, errors} = Validator.validate_topology(workflow)
      assert {:orphan_node, "orphan"} in errors
    end

    test "does not flag triggers as orphans" do
      workflow = %Workflow{
        nodes: [
          # Trigger without connections
          %{id: "trigger", type: "test.trigger", disabled: false}
        ],
        connections: []
      }

      # Should not be flagged as orphan since triggers can exist without connections
      case Validator.validate_topology(workflow) do
        {:ok, _} -> :ok
        {:error, errors} -> refute {:orphan_node, "trigger"} in errors
      end
    end

    test "detects multiple inputs to same port" do
      workflow = %Workflow{
        nodes: [
          %{id: "src1", type: "test.trigger", disabled: false},
          %{id: "src2", type: "test.trigger", disabled: false},
          %{id: "target", type: "test.process", disabled: false}
        ],
        connections: [
          %{from: %{node: "src1", port: "main"}, to: %{node: "target", port: "main"}},
          # Multiple inputs to same port
          %{from: %{node: "src2", port: "main"}, to: %{node: "target", port: "main"}}
        ]
      }

      assert {:error, errors} = Validator.validate_topology(workflow)
      assert {:multiple_inputs_to_port, "target", "main"} in errors
    end
  end

  describe "detect_cycles/1" do
    test "returns no cycles for acyclic graph" do
      workflow = create_workflow_with_connections()
      assert {:ok, :no_cycles} = Validator.detect_cycles(workflow)
    end

    test "detects self-loop" do
      workflow = %Workflow{
        nodes: [
          %{id: "self", type: "test.process", disabled: false}
        ],
        connections: [
          %{from: %{node: "self", port: "main"}, to: %{node: "self", port: "main"}}
        ]
      }

      assert {:error, {:cycle_detected, path}} = Validator.detect_cycles(workflow)
      assert "self" in path
    end

    test "ignores disabled nodes in cycle detection" do
      workflow = %Workflow{
        nodes: [
          %{id: "node1", type: "test.process", disabled: false},
          # Disabled
          %{id: "node2", type: "test.process", disabled: true}
        ],
        connections: [
          %{from: %{node: "node1", port: "main"}, to: %{node: "node2", port: "main"}},
          %{from: %{node: "node2", port: "main"}, to: %{node: "node1", port: "main"}}
        ]
      }

      # Should not detect cycle because node2 is disabled
      assert {:ok, :no_cycles} = Validator.detect_cycles(workflow)
    end
  end

  describe "validate_execution_readiness/1" do
    test "validates ready workflow" do
      workflow = create_workflow_with_connections()
      assert {:ok, ^workflow} = Validator.validate_execution_readiness(workflow)
    end

    test "detects missing trigger nodes" do
      workflow = %Workflow{
        nodes: [
          # No triggers
          %{id: "process", type: "test.process", disabled: false}
        ],
        connections: []
      }

      assert {:error, errors} = Validator.validate_execution_readiness(workflow)
      assert {:no_trigger_nodes} in errors
    end

    test "detects unconnected required inputs" do
      workflow = %Workflow{
        nodes: [
          %{id: "trigger", type: "test.trigger", disabled: false},
          # Has required input
          %{id: "requires_input", type: "test.number_input", disabled: false}
        ],
        # No connections
        connections: []
      }

      assert {:error, errors} = Validator.validate_execution_readiness(workflow)
      assert {:required_input_not_connected, "requires_input", "value"} in errors
    end

    test "allows workflow with trigger nodes" do
      workflow = %Workflow{
        nodes: [
          %{id: "trigger", type: "test.trigger", disabled: false}
        ],
        connections: []
      }

      case Validator.validate_execution_readiness(workflow) do
        {:ok, _} -> :ok
        {:error, errors} -> refute {:no_trigger_nodes} in errors
      end
    end
  end

  describe "validate_connection/5" do
    test "validates compatible connection" do
      workflow = %Workflow{
        nodes: [
          %{id: "node1", type: "test.trigger"},
          %{id: "node2", type: "test.process"}
        ],
        connections: []
      }

      assert :ok = Validator.validate_connection(workflow, "node1", "main", "node2", "main")
    end

    test "returns error for missing nodes" do
      workflow = %Workflow{nodes: [], connections: []}

      assert {:error, {:connection_missing_from_node, "missing1"}} =
               Validator.validate_connection(workflow, "missing1", "main", "missing2", "main")
    end

    test "returns error for incompatible ports" do
      workflow = %Workflow{
        nodes: [
          %{id: "string_out", type: "test.string_output"},
          %{id: "number_in", type: "test.number_input"}
        ],
        connections: []
      }

      assert {:error, {:incompatible_port_types, _, _, _}} =
               Validator.validate_connection(workflow, "string_out", "text", "number_in", "value")
    end
  end

  describe "validate_and_report/1" do
    test "returns workflow for valid workflow" do
      workflow = create_simple_valid_workflow()
      assert {:ok, ^workflow} = Validator.validate_and_report(workflow)
    end

    test "returns formatted error report for invalid workflow" do
      invalid_workflow = %Workflow{
        nodes: [
          %{id: "bad", type: "unknown.type", parameters: %{}, disabled: false}
        ],
        connections: []
      }

      assert {:error, report} = Validator.validate_and_report(invalid_workflow)
      assert is_binary(report)
      assert String.contains?(report, "validation failed")
      assert String.contains?(report, "unknown type")
    end
  end

  describe "format_validation_errors/1" do
    test "formats multiple errors with numbering" do
      errors = [
        {:unknown_node_type, "node1", "bad.type"},
        {:missing_required_parameter, "node2", "param1"},
        {:cycle_detected, ["a", "b", "a"]}
      ]

      report = Validator.format_validation_errors(errors)

      assert String.contains?(report, "3 error(s)")
      assert String.contains?(report, "1.")
      assert String.contains?(report, "2.")
      assert String.contains?(report, "3.")
      assert String.contains?(report, "unknown type")
      assert String.contains?(report, "missing required parameter")
      assert String.contains?(report, "Cycle detected")
    end

    test "formats each error type correctly" do
      errors = [
        {:unknown_node_type, "node1", "bad.type"},
        {:missing_required_parameter, "node1", "param1"},
        {:invalid_parameter_type, "node1", "param1", "string", "number"},
        {:invalid_parameter_value, "node1", "param1", "out of range"},
        {:connection_missing_from_node, "missing"},
        {:connection_missing_to_node, "missing"},
        {:unknown_output_port, "node1", "bad_port"},
        {:unknown_input_port, "node1", "bad_port"},
        {:incompatible_port_types, "node1.out", "node2.in", "type mismatch"},
        {:cycle_detected, ["a", "b", "a"]},
        {:orphan_node, "orphan"},
        {:duplicate_node_id, "dup"},
        {:duplicate_connection, "a.out", "b.in"},
        {:empty_workflow},
        {:no_trigger_nodes},
        {:multiple_inputs_to_port, "node1", "port1"},
        {:required_input_not_connected, "node1", "port1"},
        {:disabled_node_in_critical_path, "node1"}
      ]

      report = Validator.format_validation_errors(errors)

      # Check that all error types are properly formatted
      assert String.contains?(report, "unknown type")
      assert String.contains?(report, "missing required parameter")
      assert String.contains?(report, "wrong type")
      assert String.contains?(report, "invalid value")
      assert String.contains?(report, "non-existent source node")
      assert String.contains?(report, "non-existent target node")
      assert String.contains?(report, "does not have output port")
      assert String.contains?(report, "does not have input port")
      assert String.contains?(report, "Cannot connect")
      assert String.contains?(report, "Cycle detected")
      assert String.contains?(report, "not connected")
      assert String.contains?(report, "Duplicate")
      assert String.contains?(report, "no nodes")
      assert String.contains?(report, "no trigger nodes")
      assert String.contains?(report, "multiple incoming")
      assert String.contains?(report, "required input")
      assert String.contains?(report, "blocking workflow")
    end
  end

  # Helper functions

  defp create_simple_valid_workflow do
    %Workflow{
      id: "valid_workflow",
      name: "Valid Workflow",
      nodes: [
        %{
          id: "trigger",
          type: "test.trigger",
          parameters: %{},
          disabled: false,
          position: [0, 0]
        },
        %{
          id: "process",
          type: "test.process",
          parameters: %{},
          disabled: false,
          position: [100, 0]
        }
      ],
      connections: [
        %{
          from: %{node: "trigger", port: "main"},
          to: %{node: "process", port: "main"}
        }
      ],
      settings: %{},
      version: 1
    }
  end

  defp create_workflow_with_connections do
    %Workflow{
      id: "connected_workflow",
      name: "Connected Workflow",
      nodes: [
        %{
          id: "trigger",
          type: "test.trigger",
          parameters: %{},
          disabled: false,
          position: [0, 0]
        },
        %{
          id: "process",
          type: "test.process",
          parameters: %{},
          disabled: false,
          position: [100, 0]
        },
        %{
          id: "output",
          type: "test.output",
          parameters: %{},
          disabled: false,
          position: [200, 0]
        }
      ],
      connections: [
        %{
          from: %{node: "trigger", port: "main"},
          to: %{node: "process", port: "main"}
        },
        %{
          from: %{node: "process", port: "main"},
          to: %{node: "output", port: "main"}
        }
      ],
      settings: %{},
      version: 1
    }
  end
end
