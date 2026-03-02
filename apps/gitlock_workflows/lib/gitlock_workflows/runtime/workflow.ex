defmodule GitlockWorkflows.Runtime.Workflow do
  @moduledoc """
  Workflow data structure and Reactor conversion.

  This module: 
  - Define the workflow structure compatible with n8n format
  - Converts between JSON and internal representation
  - Transforms workflows into executable Reactor instances
  """
  require Logger

  alias Reactor.{Builder, Argument, Template}

  @type node_definition :: %{
          id: String.t(),
          type: String.t(),
          position: [number()],
          parameters: map(),
          disabled: boolean()
        }

  @type connection :: %{
          from: %{node: String.t(), port: String.t()},
          to: %{node: String.t(), port: String.t()}
        }

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t() | nil,
          nodes: [node_definition()],
          connections: [connection()],
          settings: map(),
          reactor: Reactor.t() | nil,
          repo_path: String.t() | nil,
          version: integer()
        }

  defstruct [
    :id,
    :name,
    :description,
    :nodes,
    :connections,
    :settings,
    :reactor,
    :repo_path,
    version: 1
  ]

  @doc """
  Parse workflow from n8n-compatible JSON format. 

  ## Example 
      iex> json = ~s({"name": "My Workflow", "nodes": [], "connections": []})
      iex> {:ok, workflow} = Workflow.from_json(json)
      iex> workflow.name
      "My Workflow"
  """
  @spec from_json(String.t()) :: {:ok, t()} | {:error, term()}
  def from_json(json) when is_binary(json) do
    with {:ok, data} <- Jason.decode(json),
         {:ok, workflow} <- parse_workflow_data(data) do
      {:ok, workflow}
    else
      {:error, %Jason.DecodeError{} = error} ->
        {:error, {:invalid_json, error}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_workflow_data(data) when is_map(data) do
    workflow = %__MODULE__{
      id: data["id"] || generate_workflow_id(),
      name: data["name"] || "Untitled Workflow",
      description: data["description"],
      nodes: parse_nodes(data["nodes"] || []),
      connections: parse_connections(data["connections"] || []),
      settings: data["settings"] || %{},
      version: data["version"] || 1
    }

    {:ok, workflow}
  rescue
    e -> {:error, {:parse_error, Exception.message(e)}}
  end

  defp generate_workflow_id do
    "wf_" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end

  defp parse_nodes(nodes) when is_list(nodes) do
    Enum.map(nodes, fn node ->
      %{
        id: node["id"] || raise("Node missing id"),
        type: node["type"] || raise("Node missing type"),
        position: node["position"] || [0, 0],
        parameters: node["parameters"] || %{},
        disabled: node["disabled"] || false
      }
    end)
  end

  defp parse_connections(connections) when is_list(connections) do
    Enum.map(connections, fn conn ->
      %{
        from: %{
          node: get_in(conn, ["from", "node"]) || raise("Connection missing from.node"),
          port: get_in(conn, ["from", "output"]) || "main"
        },
        to: %{
          node: get_in(conn, ["to", "node"]) || raise("Connection missing to.node"),
          port: get_in(conn, ["to", "input"]) || "main"
        }
      }
    end)
  end

  @doc """
  Convert workflow to n8n-compatible JSON format.
  """
  @spec to_json(t()) :: {:ok, String.t()} | {:error, term()}
  def to_json(%__MODULE__{} = workflow) do
    data = %{
      "id" => workflow.id,
      "name" => workflow.name,
      "description" => workflow.description,
      "nodes" => serialize_nodes(workflow.nodes),
      "connections" => serialize_connections(workflow.connections),
      "settings" => workflow.settings,
      "version" => workflow.version
    }

    case Jason.encode(data) do
      {:ok, json} -> {:ok, json}
      {:error, error} -> {:error, {:encode_error, error}}
    end
  end

  defp serialize_nodes(nodes) do
    Enum.map(nodes, fn node ->
      %{
        "id" => node[:id] || node.id,
        "type" => node[:type] || node.type,
        "position" => node[:position] || node.position || [0, 0],
        "parameters" => node[:parameters] || node.parameters || %{},
        "disabled" => node[:disabled] || node.disabled || false
      }
    end)
  end

  defp serialize_connections(connections) do
    Enum.map(connections, fn conn ->
      %{
        "from" => %{
          "node" => conn.from.node,
          "output" => conn.from.port
        },
        "to" => %{
          "node" => conn.to.node,
          "input" => conn.to.port
        }
      }
    end)
  end

  @spec to_reactor(t()) :: {:ok, t()} | {:error, term()}
  def to_reactor(%__MODULE__{nodes: []}), do: {:error, :empty_workflow}

  def to_reactor(%__MODULE__{} = workflow) do
    Logger.info("Converting workflow #{workflow.id} to Reactor")

    case build_reactor_from_workflow(workflow) do
      {:ok, reactor} ->
        {:ok, %{workflow | reactor: reactor}}

      {:error, reason} ->
        Logger.error("Failed to convert workflow to Reactor: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp build_reactor_from_workflow(workflow) do
    reactor = Reactor.Builder.new()

    # Don't add inputs - just add steps
    with {:ok, reactor} <- add_workflow_steps(reactor, workflow),
         {:ok, reactor} <- add_workflow_return(reactor, workflow) do
      {:ok, reactor}
    end
  rescue
    e -> {:error, {:reactor_build_error, Exception.message(e)}}
  end

  defp add_workflow_steps(reactor, workflow) do
    workflow.nodes
    |> Enum.reject(& &1.disabled)
    |> Enum.reduce_while({:ok, reactor}, fn node, {:ok, acc} ->
      case add_single_step(acc, node, workflow) do
        {:ok, new_r} -> {:cont, {:ok, new_r}}
        err -> {:halt, err}
      end
    end)
  end

  defp add_single_step(reactor, %{id: id, type: type, parameters: parameters} = node, workflow) do
    step_name = String.to_atom(id)
    args = build_step_arguments(node, workflow)

    # Pass parameters directly in the step context
    # Reactor will merge this into the execution context
    step_options = [
      context: %{
        parameters: parameters || %{}
      }
    ]

    case GitlockWorkflows.Runtime.Registry.get_node(type) do
      {:ok, mod} ->
        Reactor.Builder.add_step(reactor, step_name, mod, args, step_options)

      {:error, :not_found} ->
        {:error, {:unknown_node_type, id, type}}
    end
  end

  defp build_step_arguments(node, workflow) do
    incoming_connections =
      workflow.connections
      |> Enum.filter(fn conn -> conn.to.node == node.id end)

    if incoming_connections == [] do
      # Trigger nodes have no arguments
      []
    else
      # Build arguments from connections
      Enum.map(incoming_connections, fn conn ->
        %Reactor.Argument{
          name: String.to_atom(conn.to.port),
          source: %Reactor.Template.Result{
            name: String.to_atom(conn.from.node),
            sub_path: [String.to_atom(conn.from.port)]
          }
        }
      end)
    end
  end

  defp add_workflow_return(reactor, workflow) do
    return_id = find_return_step(workflow) || List.first(workflow.nodes).id
    Reactor.Builder.return(reactor, String.to_atom(return_id))
  end

  defp find_return_step(workflow) do
    workflow.nodes
    |> Enum.reject(& &1.disabled)
    |> Enum.find_value(fn node ->
      if not Enum.any?(workflow.connections, &(&1.from.node == node.id)), do: node.id
    end)
  end

  @doc """
  Add a node to the workflow.
  """
  @spec add_node(t(), node_definition() | map()) :: t()
  def add_node(%__MODULE__{} = workflow, node) do
    # Convert to map if needed
    node_map = if is_struct(node), do: Map.from_struct(node), else: node

    # Validate node has required fields
    unless node_map[:id] && node_map[:type] do
      raise ArgumentError, "Node must have id and type"
    end

    # Check for duplicate ID
    if Enum.any?(workflow.nodes, fn n -> n.id == node_map[:id] end) do
      raise ArgumentError, "Node with id #{node_map[:id]} already exists"
    end

    %{
      workflow
      | nodes: workflow.nodes ++ [normalize_node(node_map)],
        # Clear reactor as workflow changed
        reactor: nil
    }
  end

  @doc """
  Add a connection between nodes.
  """
  @spec add_connection(t(), String.t(), String.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def add_connection(%__MODULE__{} = workflow, from_node_id, to_node_id, opts \\ []) do
    from_port = Keyword.get(opts, :from_port, "main")
    to_port = Keyword.get(opts, :to_port, "main")

    # Validate nodes exist
    cond do
      not node_exists?(workflow, from_node_id) ->
        {:error, {:node_not_found, from_node_id}}

      not node_exists?(workflow, to_node_id) ->
        {:error, {:node_not_found, to_node_id}}

      true ->
        connection = %{
          from: %{node: from_node_id, port: from_port},
          to: %{node: to_node_id, port: to_port}
        }

        # Check for duplicate connection
        if connection_exists?(workflow, connection) do
          {:error, :connection_already_exists}
        else
          updated_workflow = %{
            workflow
            | connections: workflow.connections ++ [connection],
              reactor: nil
          }

          {:ok, updated_workflow}
        end
    end
  end

  defp normalize_node(node) do
    %{
      id: node[:id] || node["id"],
      type: node[:type] || node["type"],
      position: node[:position] || node["position"] || [0, 0],
      parameters: node[:parameters] || node["parameters"] || %{},
      disabled: node[:disabled] || node["disabled"] || false
    }
  end

  defp node_exists?(workflow, node_id) do
    Enum.any?(workflow.nodes, fn n -> n.id == node_id end)
  end

  defp connection_exists?(workflow, connection) do
    Enum.any?(workflow.connections, fn c ->
      c.from.node == connection.from.node &&
        c.from.port == connection.from.port &&
        c.to.node == connection.to.node &&
        c.to.port == connection.to.port
    end)
  end

  @doc """
  Get all nodes of a specific type.
  """
  @spec get_nodes_by_type(t(), String.t()) :: [node_definition()]
  def get_nodes_by_type(%__MODULE__{} = workflow, type) do
    Enum.filter(workflow.nodes, fn node -> node.type == type end)
  end

  @doc """
  Get node by ID.
  """
  @spec get_node(t(), String.t()) :: node_definition() | nil
  def get_node(%__MODULE__{} = workflow, node_id) do
    Enum.find(workflow.nodes, fn node -> node.id == node_id end)
  end

  @doc """
  Get all connections for a node.
  """
  @spec get_node_connections(t(), String.t()) :: %{
          inputs: [connection()],
          outputs: [connection()]
        }
  def get_node_connections(%__MODULE__{} = workflow, node_id) do
    %{
      inputs: Enum.filter(workflow.connections, fn c -> c.to.node == node_id end),
      outputs: Enum.filter(workflow.connections, fn c -> c.from.node == node_id end)
    }
  end

  @doc """
  Check if workflow has been converted to Reactor.
  """
  @spec reactor_ready?(t()) :: boolean()
  def reactor_ready?(%__MODULE__{reactor: nil}), do: false
  def reactor_ready?(%__MODULE__{reactor: _}), do: true
end
