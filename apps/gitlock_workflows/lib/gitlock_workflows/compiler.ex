defmodule GitlockWorkflows.Compiler do
  @moduledoc """
  Compiles a visual Pipeline into an executable Runtime.Workflow.

  The Pipeline model (Node, Edge, Port) serves the SvelteFlow UI and DB persistence.
  The Runtime.Workflow model serves execution via Reactor. This module bridges them.

  Node type mapping is derived from `NodeCatalog.runtime_type/1` — there is no
  separate mapping table. Adding a new node type to the catalog with a `runtime_module`
  automatically makes it compilable.
  """

  alias GitlockWorkflows.{Pipeline, NodeCatalog}
  alias GitlockWorkflows.Runtime.Workflow

  require Logger

  @doc """
  Compiles a Pipeline into a Reactor-ready Workflow.

  ## Options

    * `:repo_path` - Repository path injected into trigger node parameters
  """
  @spec compile(Pipeline.t(), keyword()) :: {:ok, Workflow.t()} | {:error, term()}
  def compile(%Pipeline{} = pipeline, opts \\ []) do
    with {:ok, workflow} <- to_workflow(pipeline, opts),
         {:ok, compiled} <- Workflow.to_reactor(workflow) do
      {:ok, compiled}
    end
  end

  @doc "Converts a Pipeline to a Runtime.Workflow without compiling to Reactor."
  @spec to_workflow(Pipeline.t(), keyword()) :: {:ok, Workflow.t()} | {:error, term()}
  def to_workflow(%Pipeline{} = pipeline, opts \\ []) do
    repo_path = Keyword.get(opts, :repo_path)
    nodes = compile_nodes(pipeline, repo_path)
    compiled_node_ids = MapSet.new(nodes, & &1.id)
    connections = compile_connections(pipeline, compiled_node_ids)

    workflow = %Workflow{
      id: pipeline.id,
      name: pipeline.name,
      description: pipeline.description,
      nodes: nodes,
      connections: connections,
      settings: %{},
      repo_path: repo_path,
      version: 1
    }

    {:ok, workflow}
  rescue
    e -> {:error, {:compilation_error, Exception.message(e)}}
  end

  @doc """
  Returns the Runtime Registry node type string for a NodeCatalog type atom.

  Delegates to `NodeCatalog.runtime_type/1`.
  """
  @spec runtime_type(atom()) :: String.t() | nil
  def runtime_type(catalog_type), do: NodeCatalog.runtime_type(catalog_type)

  # ── Private ──────────────────────────────────────────────────

  defp compile_nodes(%Pipeline{nodes: nodes}, repo_path) do
    nodes
    |> Map.values()
    |> Enum.map(&compile_node(&1, repo_path))
    |> Enum.reject(&is_nil/1)
  end

  defp compile_node(node, repo_path) do
    case NodeCatalog.runtime_type(node.type) do
      nil ->
        Logger.debug("Skipping node #{node.id} (#{node.type}): no runtime module")
        nil

      runtime_type ->
        {x, y} = node.position
        params = build_parameters(node, runtime_type, repo_path)

        %{
          id: node.id,
          type: runtime_type,
          position: [x, y],
          parameters: params,
          disabled: false
        }
    end
  end

  defp build_parameters(node, "gitlock.trigger.git_commits", repo_path) do
    params = node.config || %{}

    params =
      if repo_path do
        Map.put(params, "repo_path", repo_path)
      else
        url = Map.get(params, "repo_url") || Map.get(params, :repo_url)
        if url, do: Map.put(params, "repo_path", url), else: params
      end

    # Build git_options from config fields for the runtime node
    git_options =
      %{}
      |> maybe_put_option(:since, params, "since")
      |> maybe_put_option(:until, params, "until")
      |> maybe_put_option(:max_count, params, "depth")
      |> maybe_put_option(:path, params, "path_filter")

    branch = get_nonempty(params, "branch")

    params
    |> Map.put("git_options", git_options)
    |> then(fn p -> if branch, do: Map.put(p, "branch", branch), else: p end)
  end

  defp maybe_put_option(opts, _key, params, config_key) do
    case get_nonempty(params, config_key) do
      nil -> opts
      value -> Map.put(opts, config_key, value)
    end
  end

  defp get_nonempty(params, key) do
    value = Map.get(params, key) || Map.get(params, String.to_atom(key))

    case value do
      nil -> nil
      "" -> nil
      v when is_integer(v) and v > 0 -> v
      v when is_binary(v) -> v
      _ -> nil
    end
  end

  # Complexity trend analysis needs repo_path for `git show` on historical files
  defp build_parameters(node, "gitlock.analysis.complexity_trend", repo_path) do
    params = node.config || %{}
    if repo_path, do: Map.put(params, "repo_path", repo_path), else: params
  end

  defp build_parameters(node, _runtime_type, _repo_path) do
    node.config || %{}
  end

  defp compile_connections(%Pipeline{nodes: nodes, edges: edges}, compiled_node_ids) do
    port_name_lookup = build_port_name_lookup(nodes)

    edges
    |> Map.values()
    |> Enum.map(&compile_edge(&1, port_name_lookup, compiled_node_ids))
    |> Enum.reject(&is_nil/1)
  end

  defp compile_edge(edge, port_name_lookup, compiled_node_ids) do
    with true <- MapSet.member?(compiled_node_ids, edge.source_node_id),
         true <- MapSet.member?(compiled_node_ids, edge.target_node_id),
         {:ok, src_port_name} <- Map.fetch(port_name_lookup, edge.source_port_id),
         {:ok, tgt_port_name} <- Map.fetch(port_name_lookup, edge.target_port_id) do
      %{
        from: %{node: edge.source_node_id, port: src_port_name},
        to: %{node: edge.target_node_id, port: tgt_port_name}
      }
    else
      _ ->
        Logger.debug("Skipping edge #{edge.id}: endpoint not in compiled set")
        nil
    end
  end

  defp build_port_name_lookup(nodes) do
    nodes
    |> Map.values()
    |> Enum.flat_map(fn node ->
      Enum.map(node.input_ports ++ node.output_ports, fn port ->
        {port.id, port.name}
      end)
    end)
    |> Map.new()
  end
end
