defmodule GitlockWorkflows.Runtime.Validator do
  @moduledoc """
  Validates workflow structure, node connections, and execution readiness.

  This module provides comprehensive validation for workflows including:
  - Structural validation (nodes, connections, parameters)
  - Port type compatibility checking
  - Circular dependency detection
  - Node parameter validation
  - Workflow execution readiness checks

  ## Examples

      iex> workflow = %Workflow{nodes: [...], connections: [...]}
      iex> Validator.validate_workflow(workflow)
      {:ok, workflow}

      iex> Validator.validate_workflow(invalid_workflow)
      {:error, [
        {:missing_required_parameter, "node_1", "threshold"},
        {:cycle_detected, ["node_1", "node_2", "node_3", "node_1"]}
      ]}
  """

  alias GitlockWorkflows.Runtime.{Workflow, Registry}
  require Logger

  @typedoc "Validation error types"
  @type validation_error ::
          {:unknown_node_type, node_id :: String.t(), type :: String.t()}
          | {:missing_required_parameter, node_id :: String.t(), param_name :: String.t()}
          | {:invalid_parameter_type, node_id :: String.t(), param_name :: String.t(),
             expected :: String.t(), actual :: any()}
          | {:invalid_parameter_value, node_id :: String.t(), param_name :: String.t(),
             reason :: String.t()}
          | {:connection_missing_from_node, node_id :: String.t()}
          | {:connection_missing_to_node, node_id :: String.t()}
          | {:unknown_output_port, node_id :: String.t(), port :: String.t()}
          | {:unknown_input_port, node_id :: String.t(), port :: String.t()}
          | {:incompatible_port_types, from :: String.t(), to :: String.t(), reason :: String.t()}
          | {:cycle_detected, path :: [String.t()]}
          | {:orphan_node, node_id :: String.t()}
          | {:duplicate_node_id, node_id :: String.t()}
          | {:duplicate_connection, from :: String.t(), to :: String.t()}
          | {:empty_workflow}
          | {:no_trigger_nodes}
          | {:multiple_inputs_to_port, node_id :: String.t(), port :: String.t()}
          | {:required_input_not_connected, node_id :: String.t(), port :: String.t()}
          | {:disabled_node_in_critical_path, node_id :: String.t()}

  @typedoc "Port compatibility result"
  @type compatibility_result :: :compatible | {:incompatible, reason :: String.t()}

  @doc """
  Performs comprehensive validation of a workflow.

  Validates:
  - Workflow structure
  - Node definitions and parameters
  - Connection validity and port compatibility
  - Circular dependencies
  - Execution readiness

  ## Examples

      iex> Validator.validate_workflow(workflow)
      {:ok, workflow}

      iex> Validator.validate_workflow(invalid_workflow)
      {:error, [{:unknown_node_type, "node_1", "invalid.type"}]}
  """
  @spec validate_workflow(Workflow.t()) :: {:ok, Workflow.t()} | {:error, [validation_error()]}
  def validate_workflow(%Workflow{} = workflow) do
    Logger.debug("Validating workflow: #{workflow.id}")

    # Collect ALL errors from all validation steps
    all_errors = []

    # Structure validation
    all_errors =
      case validate_structure(workflow) do
        {:ok, _} -> all_errors
        {:error, errors} -> all_errors ++ errors
      end

    # Node validation
    all_errors =
      case validate_nodes(workflow) do
        {:ok, _} -> all_errors
        {:error, errors} -> all_errors ++ errors
      end

    # Connection validation
    all_errors =
      case validate_connections(workflow) do
        {:ok, _} -> all_errors
        {:error, errors} -> all_errors ++ errors
      end

    # Topology validation
    all_errors =
      case validate_topology(workflow) do
        {:ok, _} -> all_errors
        {:error, errors} -> all_errors ++ errors
      end

    # Execution readiness validation
    all_errors =
      case validate_execution_readiness(workflow) do
        {:ok, _} -> all_errors
        {:error, errors} -> all_errors ++ errors
      end

    if all_errors == [] do
      Logger.info("Workflow validation successful: #{workflow.id}")
      {:ok, workflow}
    else
      Logger.warning(
        "Workflow validation failed with #{length(all_errors)} errors: #{inspect(all_errors)}"
      )

      {:error, all_errors}
    end
  end

  @doc """
  Validates basic workflow structure.
  """
  @spec validate_structure(Workflow.t()) :: {:ok, Workflow.t()} | {:error, [validation_error()]}
  def validate_structure(%Workflow{nodes: []} = _workflow) do
    {:error, [{:empty_workflow}]}
  end

  def validate_structure(%Workflow{} = workflow) do
    errors = []

    # Check for duplicate node IDs
    node_ids = Enum.map(workflow.nodes, & &1.id)
    duplicate_ids = node_ids -- Enum.uniq(node_ids)

    errors =
      if duplicate_ids == [] do
        errors
      else
        duplicate_errors = Enum.map(duplicate_ids, fn id -> {:duplicate_node_id, id} end)
        errors ++ duplicate_errors
      end

    # Check for duplicate connections
    connections =
      Enum.map(workflow.connections, fn conn ->
        {conn.from.node, conn.from.port, conn.to.node, conn.to.port}
      end)

    duplicate_connections = connections -- Enum.uniq(connections)

    errors =
      if duplicate_connections == [] do
        errors
      else
        duplicate_conn_errors =
          Enum.map(duplicate_connections, fn {from_node, from_port, to_node, to_port} ->
            {:duplicate_connection, "#{from_node}.#{from_port}", "#{to_node}.#{to_port}"}
          end)

        errors ++ duplicate_conn_errors
      end

    if errors == [] do
      {:ok, workflow}
    else
      {:error, errors}
    end
  end

  @doc """
  Validates all nodes in the workflow.
  """
  @spec validate_nodes(Workflow.t()) :: {:ok, Workflow.t()} | {:error, [validation_error()]}
  def validate_nodes(%Workflow{} = workflow) do
    errors =
      workflow.nodes
      |> Enum.reject(& &1.disabled)
      |> Enum.flat_map(&validate_single_node(&1, workflow))

    if errors == [] do
      {:ok, workflow}
    else
      {:error, errors}
    end
  end

  @doc """
  Validates a single node.
  """
  @spec validate_single_node(map(), Workflow.t()) :: [validation_error()]
  def validate_single_node(node, _workflow) do
    case Registry.get_metadata(node.type) do
      {:ok, metadata} ->
        validate_node_parameters(node, metadata)

      {:error, :not_found} ->
        [{:unknown_node_type, node.id, node.type}]
    end
  end

  @doc """
  Validates node parameters against metadata.
  """
  @spec validate_node_parameters(map(), map()) :: [validation_error()]
  def validate_node_parameters(node, metadata) do
    parameter_defs = Map.get(metadata, :parameters, [])

    # Check required parameters
    required_errors =
      parameter_defs
      |> Enum.filter(& &1[:required])
      |> Enum.reject(fn param_def ->
        Map.has_key?(node.parameters, param_def[:name])
      end)
      |> Enum.map(fn param_def ->
        {:missing_required_parameter, node.id, param_def[:name]}
      end)

    # Validate parameter types and values
    type_errors =
      node.parameters
      |> Enum.flat_map(fn {param_name, param_value} ->
        case find_parameter_def(parameter_defs, param_name) do
          nil ->
            # Unknown parameter - could be a warning, but we'll allow it
            []

          param_def ->
            validate_parameter_value(node.id, param_name, param_value, param_def)
        end
      end)

    required_errors ++ type_errors
  end

  defp find_parameter_def(parameter_defs, param_name) do
    Enum.find(parameter_defs, fn def -> def[:name] == param_name end)
  end

  defp validate_parameter_value(node_id, param_name, value, param_def) do
    expected_type = param_def[:type]
    options = param_def[:options]

    cond do
      # Check if value is in allowed options
      options != nil and value not in options ->
        [
          {:invalid_parameter_value, node_id, param_name,
           "Value must be one of: #{inspect(options)}"}
        ]

      # Type validation
      not type_matches?(value, expected_type) ->
        [{:invalid_parameter_type, node_id, param_name, expected_type, type_of(value)}]

      # Additional validations based on type
      expected_type == "number" and param_def[:min] != nil and value < param_def[:min] ->
        [{:invalid_parameter_value, node_id, param_name, "Value must be >= #{param_def[:min]}"}]

      expected_type == "number" and param_def[:max] != nil and value > param_def[:max] ->
        [{:invalid_parameter_value, node_id, param_name, "Value must be <= #{param_def[:max]}"}]

      expected_type == "string" and param_def[:pattern] != nil ->
        pattern = Regex.compile!(param_def[:pattern])

        if Regex.match?(pattern, value) do
          []
        else
          [
            {:invalid_parameter_value, node_id, param_name,
             "Value must match pattern: #{param_def[:pattern]}"}
          ]
        end

      true ->
        []
    end
  end

  defp type_matches?(value, expected_type) do
    case expected_type do
      "string" -> is_binary(value)
      "number" -> is_number(value)
      "boolean" -> is_boolean(value)
      "array" -> is_list(value)
      "object" -> is_map(value)
      "integer" -> is_integer(value)
      "float" -> is_float(value)
      _ -> true
    end
  end

  defp type_of(value) do
    cond do
      is_binary(value) -> "string"
      is_integer(value) -> "integer"
      is_float(value) -> "float"
      is_boolean(value) -> "boolean"
      is_list(value) -> "array"
      is_map(value) -> "object"
      true -> "unknown"
    end
  end

  @doc """
  Validates all connections in the workflow.
  """
  @spec validate_connections(Workflow.t()) :: {:ok, Workflow.t()} | {:error, [validation_error()]}
  def validate_connections(%Workflow{} = workflow) do
    errors = Enum.flat_map(workflow.connections, &validate_single_connection(&1, workflow))

    if errors == [] do
      {:ok, workflow}
    else
      {:error, errors}
    end
  end

  @doc """
  Validates a single connection.
  """
  @spec validate_single_connection(map(), Workflow.t()) :: [validation_error()]
  def validate_single_connection(connection, workflow) do
    from_node = find_node(workflow, connection.from.node)
    to_node = find_node(workflow, connection.to.node)

    cond do
      from_node == nil ->
        [{:connection_missing_from_node, connection.from.node}]

      to_node == nil ->
        [{:connection_missing_to_node, connection.to.node}]

      from_node.disabled or to_node.disabled ->
        # Skip validation for disabled nodes
        []

      true ->
        validate_port_connection(from_node, to_node, connection)
    end
  end

  defp find_node(workflow, node_id) do
    Enum.find(workflow.nodes, fn n -> n.id == node_id end)
  end

  @doc """
  Validates port compatibility between connected nodes.
  """
  @spec validate_port_connection(map(), map(), map()) :: [validation_error()]
  def validate_port_connection(from_node, to_node, connection) do
    with {:ok, from_metadata} <- Registry.get_metadata(from_node.type),
         {:ok, to_metadata} <- Registry.get_metadata(to_node.type),
         {:ok, output_port} <- find_port(from_metadata[:outputs], connection.from.port),
         {:ok, input_port} <- find_port(to_metadata[:inputs], connection.to.port) do
      case check_port_compatibility(output_port, input_port) do
        :compatible ->
          []

        {:incompatible, reason} ->
          [
            {:incompatible_port_types, "#{from_node.id}.#{connection.from.port}",
             "#{to_node.id}.#{connection.to.port}", reason}
          ]
      end
    else
      {:error, {:port_not_found, port_name}} when port_name == connection.from.port ->
        [{:unknown_output_port, from_node.id, connection.from.port}]

      {:error, {:port_not_found, port_name}} when port_name == connection.to.port ->
        [{:unknown_input_port, to_node.id, connection.to.port}]

      {:error, :not_found} ->
        # Node type not found - should have been caught in node validation
        []
    end
  end

  defp find_port(ports, port_name) do
    case Enum.find(ports, fn p -> p.name == port_name end) do
      nil -> {:error, {:port_not_found, port_name}}
      port -> {:ok, port}
    end
  end

  @doc """
  Checks if two port types are compatible.
  """
  @spec check_port_compatibility(map(), map()) :: compatibility_result()
  def check_port_compatibility(output_port, input_port) do
    output_type = output_port[:type]
    input_type = input_port[:type]

    cond do
      # Any type is compatible with everything
      output_type == :any or input_type == :any ->
        :compatible

      # Exact match
      output_type == input_type ->
        :compatible

      # List compatibility
      match?({:list, _}, output_type) and match?({:list, _}, input_type) ->
        {:list, out_elem} = output_type
        {:list, in_elem} = input_type
        check_type_compatibility(out_elem, in_elem)

      # Map compatibility
      match?({:map, _}, output_type) and match?({:map, _}, input_type) ->
        {:map, out_elem} = output_type
        {:map, in_elem} = input_type
        check_type_compatibility(out_elem, in_elem)

      true ->
        {:incompatible, "Type #{inspect(output_type)} cannot connect to #{inspect(input_type)}"}
    end
  end

  defp check_type_compatibility(type1, type2) do
    cond do
      type1 == :any or type2 == :any -> :compatible
      type1 == type2 -> :compatible
      true -> {:incompatible, "Incompatible types: #{inspect(type1)} and #{inspect(type2)}"}
    end
  end

  @doc """
  Validates workflow topology (cycles, orphans, etc).
  """
  @spec validate_topology(Workflow.t()) :: {:ok, Workflow.t()} | {:error, [validation_error()]}
  def validate_topology(%Workflow{} = workflow) do
    errors = []

    # Check for cycles
    errors =
      case detect_cycles(workflow) do
        {:ok, :no_cycles} -> errors
        {:error, {:cycle_detected, path}} -> [{:cycle_detected, path} | errors]
      end

    # Check for orphan nodes (except triggers)
    orphan_errors = find_orphan_nodes(workflow)
    errors = errors ++ orphan_errors

    # Check for multiple inputs to same port
    multi_input_errors = find_multiple_inputs_to_port(workflow)
    errors = errors ++ multi_input_errors

    if errors == [] do
      {:ok, workflow}
    else
      {:error, errors}
    end
  end

  # Helper function to determine if a node is a trigger
  # Define this before it's used in other functions
  defp trigger_node?(node) do
    # Check against known trigger types
    known_trigger_types = [
      "gitlock.trigger.git_commits",
      "gitlock.trigger.file_change",
      "gitlock.trigger.webhook",
      "gitlock.trigger.schedule"
    ]

    if node.type in known_trigger_types do
      true
    else
      # Check if it's registered as a trigger via metadata
      case Registry.get_metadata(node.type) do
        {:ok, metadata} ->
          # Node is a trigger if it has group "trigger"
          Map.get(metadata, :group) == "trigger"

        {:error, :not_found} ->
          # If not found in registry, check if type contains "trigger"
          String.contains?(node.type, "trigger")
      end
    end
  end

  @doc """
  Detects cycles in the workflow graph using DFS.
  """
  @spec detect_cycles(Workflow.t()) ::
          {:ok, :no_cycles} | {:error, {:cycle_detected, [String.t()]}}
  def detect_cycles(%Workflow{} = workflow) do
    graph = build_adjacency_list(workflow)
    active_nodes = get_active_node_ids(workflow)

    case dfs_detect_cycles(graph, active_nodes) do
      nil -> {:ok, :no_cycles}
      cycle_path -> {:error, {:cycle_detected, cycle_path}}
    end
  end

  defp build_adjacency_list(workflow) do
    workflow.connections
    |> Enum.filter(fn conn ->
      from_node = find_node(workflow, conn.from.node)
      to_node = find_node(workflow, conn.to.node)
      from_node && to_node && !from_node.disabled && !to_node.disabled
    end)
    |> Enum.reduce(%{}, fn conn, acc ->
      Map.update(acc, conn.from.node, [conn.to.node], fn existing ->
        [conn.to.node | existing]
      end)
    end)
  end

  defp get_active_node_ids(workflow) do
    workflow.nodes
    |> Enum.reject(& &1.disabled)
    |> Enum.map(& &1.id)
  end

  defp dfs_detect_cycles(graph, nodes) do
    initial_state = %{
      visited: MapSet.new(),
      rec_stack: MapSet.new(),
      parent_map: %{}
    }

    Enum.find_value(nodes, fn node ->
      if node not in initial_state.visited do
        dfs_visit(node, graph, initial_state)
      end
    end)
  end

  defp dfs_visit(node, graph, state) do
    state = %{
      state
      | visited: MapSet.put(state.visited, node),
        rec_stack: MapSet.put(state.rec_stack, node)
    }

    neighbors = Map.get(graph, node, [])

    result =
      Enum.find_value(neighbors, fn neighbor ->
        cond do
          neighbor in state.rec_stack ->
            # Found a cycle - reconstruct path
            reconstruct_cycle_path(neighbor, node, state.parent_map)

          neighbor not in state.visited ->
            new_state = %{state | parent_map: Map.put(state.parent_map, neighbor, node)}
            dfs_visit(neighbor, graph, new_state)

          true ->
            nil
        end
      end)

    if result do
      result
    else
      # Remove from recursion stack when backtracking
      nil
    end
  end

  defp reconstruct_cycle_path(cycle_start, current, parent_map) do
    # Build path from current back to cycle_start
    path = build_path_to_cycle_start(current, cycle_start, parent_map, [current])

    # The path is built backwards, so reverse it and add cycle_start at the end to close the cycle
    reversed_path = Enum.reverse(path)

    # Only add cycle_start at the beginning if it's not already there
    final_path =
      if List.first(reversed_path) == cycle_start do
        reversed_path
      else
        [cycle_start | reversed_path]
      end

    # Add cycle_start at the end to show the cycle
    final_path ++ [cycle_start]
  end

  defp build_path_to_cycle_start(current, cycle_start, parent_map, acc) do
    case Map.get(parent_map, current) do
      nil ->
        # No parent, shouldn't happen in a proper cycle
        acc

      ^cycle_start ->
        # Found the cycle start, add it to path
        [cycle_start | acc]

      parent ->
        # Continue building path
        build_path_to_cycle_start(parent, cycle_start, parent_map, [parent | acc])
    end
  end

  @doc """
  Finds orphan nodes (nodes with no connections except triggers).
  """
  @spec find_orphan_nodes(Workflow.t()) :: [validation_error()]
  def find_orphan_nodes(%Workflow{} = workflow) do
    workflow.nodes
    |> Enum.reject(& &1.disabled)
    |> Enum.filter(fn node ->
      is_trigger = trigger_node?(node)
      has_incoming = Enum.any?(workflow.connections, fn c -> c.to.node == node.id end)
      has_outgoing = Enum.any?(workflow.connections, fn c -> c.from.node == node.id end)

      not is_trigger and not has_incoming and not has_outgoing
    end)
    |> Enum.map(fn node -> {:orphan_node, node.id} end)
  end

  @doc """
  Finds ports that have multiple incoming connections.
  """
  @spec find_multiple_inputs_to_port(Workflow.t()) :: [validation_error()]
  def find_multiple_inputs_to_port(%Workflow{} = workflow) do
    workflow.connections
    |> Enum.group_by(fn conn -> {conn.to.node, conn.to.port} end)
    |> Enum.filter(fn {_key, conns} -> length(conns) > 1 end)
    |> Enum.map(fn {{node_id, port}, _conns} ->
      {:multiple_inputs_to_port, node_id, port}
    end)
  end

  @doc """
  Validates that the workflow is ready for execution.
  """
  @spec validate_execution_readiness(Workflow.t()) ::
          {:ok, Workflow.t()} | {:error, [validation_error()]}
  def validate_execution_readiness(%Workflow{} = workflow) do
    errors = []

    active_triggers =
      workflow.nodes
      |> Enum.filter(fn node ->
        trigger_node?(node)
      end)

    errors =
      if active_triggers == [] do
        [{:no_trigger_nodes} | errors]
      else
        errors
      end

    # Check required inputs are connected
    required_input_errors = check_required_inputs_connected(workflow)
    errors = errors ++ required_input_errors

    # Check for disabled nodes in critical paths
    disabled_critical_errors = check_disabled_nodes_in_critical_paths(workflow)
    errors = errors ++ disabled_critical_errors

    if errors == [] do
      {:ok, workflow}
    else
      {:error, errors}
    end
  end

  defp check_required_inputs_connected(workflow) do
    workflow.nodes
    |> Enum.reject(& &1.disabled)
    |> Enum.flat_map(fn node ->
      case Registry.get_metadata(node.type) do
        {:ok, metadata} ->
          required_inputs =
            metadata[:inputs]
            |> Enum.filter(& &1[:required])
            |> Enum.map(& &1[:name])

          connected_inputs =
            workflow.connections
            |> Enum.filter(fn conn -> conn.to.node == node.id end)
            |> Enum.map(fn conn -> conn.to.port end)

          missing_inputs = required_inputs -- connected_inputs

          Enum.map(missing_inputs, fn input ->
            {:required_input_not_connected, node.id, input}
          end)

        {:error, _} ->
          []
      end
    end)
  end

  defp check_disabled_nodes_in_critical_paths(workflow) do
    # Find paths from triggers to outputs
    # If any disabled node blocks all paths, it's a critical error

    # For now, simple check: warn if disabled node has active connections
    workflow.nodes
    |> Enum.filter(fn node ->
      has_active_incoming =
        Enum.any?(workflow.connections, fn conn ->
          conn.to.node == node.id and
            case find_node(workflow, conn.from.node) do
              nil -> false
              from_node -> not from_node.disabled
            end
        end)

      has_active_outgoing =
        Enum.any?(workflow.connections, fn conn ->
          conn.from.node == node.id and
            case find_node(workflow, conn.to.node) do
              nil -> false
              to_node -> not to_node.disabled
            end
        end)

      has_active_incoming and has_active_outgoing and node.disabled
    end)
    |> Enum.map(fn node -> {:disabled_node_in_critical_path, node.id} end)
  end

  @doc """
  Validates that two nodes can be connected on specific ports.

  This is useful for real-time validation in the UI.

  ## Examples

      iex> Validator.validate_connection(workflow, "node1", "output", "node2", "input")
      :ok

      iex> Validator.validate_connection(workflow, "node1", "output", "node2", "input")
      {:error, {:incompatible_port_types, "string", "number"}}
  """
  @spec validate_connection(Workflow.t(), String.t(), String.t(), String.t(), String.t()) ::
          :ok | {:error, validation_error()}
  def validate_connection(workflow, from_node_id, from_port, to_node_id, to_port) do
    from_node = find_node(workflow, from_node_id)
    to_node = find_node(workflow, to_node_id)

    cond do
      from_node == nil ->
        {:error, {:connection_missing_from_node, from_node_id}}

      to_node == nil ->
        {:error, {:connection_missing_to_node, to_node_id}}

      true ->
        connection = %{
          from: %{node: from_node_id, port: from_port},
          to: %{node: to_node_id, port: to_port}
        }

        case validate_port_connection(from_node, to_node, connection) do
          [] -> :ok
          [error | _] -> {:error, error}
        end
    end
  end

  @doc """
  Validates a workflow and returns a formatted error report.

  Useful for debugging validation issues.

  ## Examples

      iex> Validator.validate_and_report(workflow)
      {:ok, workflow}
      
      iex> Validator.validate_and_report(invalid_workflow)
      {:error, 
       \"\"\"
       Workflow validation failed with 3 errors:
       1. Node 'node_1' has unknown type 'invalid.type'
       2. Node 'node_2' is missing required parameter 'threshold'
       3. No trigger nodes found in workflow
       \"\"\"}
  """
  @spec validate_and_report(Workflow.t()) :: {:ok, Workflow.t()} | {:error, String.t()}
  def validate_and_report(%Workflow{} = workflow) do
    case validate_workflow(workflow) do
      {:ok, workflow} ->
        {:ok, workflow}

      {:error, errors} ->
        report = format_validation_errors(errors)
        {:error, report}
    end
  end

  @doc """
  Formats validation errors into a human-readable report.
  """
  @spec format_validation_errors([validation_error()]) :: String.t()
  def format_validation_errors(errors) do
    header = "Workflow validation failed with #{length(errors)} error(s):\n"

    formatted_errors =
      errors
      |> Enum.with_index(1)
      |> Enum.map_join("\n", fn {error, index} ->
        "#{index}. #{format_single_error(error)}"
      end)

    header <> formatted_errors
  end

  defp format_single_error(error) do
    case error do
      {:unknown_node_type, node_id, type} ->
        "Node '#{node_id}' has unknown type '#{type}'"

      {:missing_required_parameter, node_id, param} ->
        "Node '#{node_id}' is missing required parameter '#{param}'"

      {:invalid_parameter_type, node_id, param, expected, actual} ->
        "Node '#{node_id}' parameter '#{param}' has wrong type: expected #{expected}, got #{actual}"

      {:invalid_parameter_value, node_id, param, reason} ->
        "Node '#{node_id}' parameter '#{param}' has invalid value: #{reason}"

      {:connection_missing_from_node, node_id} ->
        "Connection references non-existent source node '#{node_id}'"

      {:connection_missing_to_node, node_id} ->
        "Connection references non-existent target node '#{node_id}'"

      {:unknown_output_port, node_id, port} ->
        "Node '#{node_id}' does not have output port '#{port}'"

      {:unknown_input_port, node_id, port} ->
        "Node '#{node_id}' does not have input port '#{port}'"

      {:incompatible_port_types, from, to, reason} ->
        "Cannot connect #{from} to #{to}: #{reason}"

      {:cycle_detected, path} ->
        "Cycle detected: #{Enum.join(path, " -> ")}"

      {:orphan_node, node_id} ->
        "Node '#{node_id}' is not connected to any other nodes"

      {:duplicate_node_id, node_id} ->
        "Duplicate node ID '#{node_id}'"

      {:duplicate_connection, from, to} ->
        "Duplicate connection from #{from} to #{to}"

      {:empty_workflow} ->
        "Workflow has no nodes"

      {:no_trigger_nodes} ->
        "Workflow has no trigger nodes"

      {:multiple_inputs_to_port, node_id, port} ->
        "Node '#{node_id}' port '#{port}' has multiple incoming connections"

      {:required_input_not_connected, node_id, port} ->
        "Node '#{node_id}' required input port '#{port}' is not connected"

      {:disabled_node_in_critical_path, node_id} ->
        "Disabled node '#{node_id}' is blocking workflow execution"

      other ->
        inspect(other)
    end
  end
end
