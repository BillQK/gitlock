defmodule GitlockWorkflows.Pipeline do
  @moduledoc """
  A directed acyclic graph of workflow nodes connected by edges.

  The pipeline is the top-level domain object. It maintains a graph of
  typed nodes connected through ports, validates structural integrity,
  and can be compiled into an executable Reactor workflow.
  """

  alias GitlockWorkflows.{Node, Edge, Port}

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          description: String.t(),
          nodes: %{String.t() => Node.t()},
          edges: %{String.t() => Edge.t()}
        }

  @enforce_keys [:id, :name]
  defstruct [:id, :name, description: "", nodes: %{}, edges: %{}]

  # ── Construction ────────────────────────────────────────────────

  @doc "Creates a new empty pipeline."
  @spec new(String.t(), keyword()) :: t()
  def new(name, opts \\ []) do
    %__MODULE__{
      id: gen_id(),
      name: name,
      description: Keyword.get(opts, :description, "")
    }
  end

  # ── Node Operations ────────────────────────────────────────────

  @doc "Adds a node to the pipeline. Returns `{:error, :duplicate_node}` if id exists."
  @spec add_node(t(), Node.t()) :: t() | {:error, :duplicate_node}
  def add_node(%__MODULE__{nodes: nodes} = pipeline, %Node{id: id} = node) do
    if Map.has_key?(nodes, id) do
      {:error, :duplicate_node}
    else
      %{pipeline | nodes: Map.put(nodes, id, node)}
    end
  end

  @doc """
  Removes a node and all edges connected to it.
  Returns the pipeline unchanged if the node doesn't exist.
  """
  @spec remove_node(t(), String.t()) :: t()
  def remove_node(%__MODULE__{nodes: nodes, edges: edges} = pipeline, node_id) do
    if Map.has_key?(nodes, node_id) do
      pruned_edges =
        edges
        |> Enum.reject(fn {_id, edge} ->
          edge.source_node_id == node_id or edge.target_node_id == node_id
        end)
        |> Map.new()

      %{pipeline | nodes: Map.delete(nodes, node_id), edges: pruned_edges}
    else
      pipeline
    end
  end

  # ── Edge Operations ────────────────────────────────────────────

  @doc """
  Adds an edge connecting two node ports.

  Validates that:
  - Both nodes exist in the pipeline
  - The source port exists on the source node (as an output)
  - The target port exists on the target node (as an input)
  - The port data types are compatible
  """
  @spec add_edge(t(), Edge.t()) :: t() | {:error, atom()}
  def add_edge(%__MODULE__{} = pipeline, %Edge{} = edge) do
    with {:ok, source_node} <- fetch_node(pipeline, edge.source_node_id, :source_node_not_found),
         {:ok, target_node} <- fetch_node(pipeline, edge.target_node_id, :target_node_not_found),
         {:ok, source_port} <- find_output_port(source_node, edge.source_port_id),
         {:ok, target_port} <- find_input_port(target_node, edge.target_port_id),
         :ok <- check_compatibility(source_port, target_port) do
      %{pipeline | edges: Map.put(pipeline.edges, edge.id, edge)}
    end
  end

  @doc "Removes an edge by id."
  @spec remove_edge(t(), String.t()) :: t()
  def remove_edge(%__MODULE__{edges: edges} = pipeline, edge_id) do
    %{pipeline | edges: Map.delete(edges, edge_id)}
  end

  # ── Validation ─────────────────────────────────────────────────

  @doc """
  Validates the pipeline graph structure.

  Checks:
  - All nodes with input ports have those ports connected by an edge

  Returns `:ok` or `{:error, errors}` where errors is a keyword list.
  """
  @spec validate(t()) :: :ok | {:error, keyword()}
  def validate(%__MODULE__{} = pipeline) do
    errors = check_unconnected_inputs(pipeline)

    if errors == [] do
      :ok
    else
      {:error, errors}
    end
  end

  # ── Private Helpers ────────────────────────────────────────────

  defp fetch_node(%__MODULE__{nodes: nodes}, node_id, error_tag) do
    case Map.fetch(nodes, node_id) do
      {:ok, node} -> {:ok, node}
      :error -> {:error, error_tag}
    end
  end

  defp find_output_port(node, port_id) do
    case Node.find_output_port(node, port_id) do
      {:ok, _} = ok -> ok
      :error -> {:error, :source_port_not_found}
    end
  end

  defp find_input_port(node, port_id) do
    case Node.find_input_port(node, port_id) do
      {:ok, _} = ok -> ok
      :error -> {:error, :target_port_not_found}
    end
  end

  defp check_compatibility(source_port, target_port) do
    if Port.compatible?(source_port, target_port) do
      :ok
    else
      {:error, :incompatible_port_types}
    end
  end

  defp check_unconnected_inputs(%__MODULE__{nodes: nodes, edges: edges}) do
    # Collect all target port ids that have an incoming edge
    connected_input_ports =
      edges
      |> Map.values()
      |> MapSet.new(& &1.target_port_id)

    # Find nodes with input ports that aren't connected
    nodes
    |> Map.values()
    |> Enum.flat_map(fn node ->
      node.input_ports
      |> Enum.reject(&(&1.optional || MapSet.member?(connected_input_ports, &1.id)))
      |> Enum.map(fn port ->
        {:unconnected_inputs, "#{node.label} port '#{port.name}' has no incoming connection"}
      end)
    end)
  end

  defp gen_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
