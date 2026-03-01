defmodule GitlockWorkflows.Executor do
  @moduledoc """
  Executes a workflow pipeline with DAG-based data flow.

  Compiles the visual Pipeline to a Runtime Workflow, then executes nodes
  in topological order, passing data between nodes through their port
  connections. This means the git source node fetches commits once and
  all downstream analyzers receive them through the DAG — no redundant fetches.

  ## Async execution (for LiveView)

  `run/4` spawns a linked Task and sends progress messages to the caller:

      {:pipeline_progress, node_id, :running}
      {:pipeline_progress, node_id, {:done, result}}
      {:pipeline_progress, node_id, {:error, reason}}
      {:pipeline_complete, results}

  ## Sync execution (for CLI and tests)

  `run_sync/3` blocks until all nodes complete and returns the results map.
  """

  alias GitlockWorkflows.{Pipeline, Node, NodeCatalog, Compiler}
  alias GitlockWorkflows.Runtime.Registry

  require Logger

  @type node_result :: {:ok, node_output()} | {:error, term()}
  @type node_output :: %{node_id: String.t(), type: atom(), label: String.t(), data: term()}
  @type results :: %{String.t() => node_result()}

  # ── Public API ───────────────────────────────────────────────

  @doc """
  Executes a pipeline asynchronously, sending progress messages to `caller`.

  Returns `:ok` immediately. The caller receives messages as nodes complete.

  ## Options

    * `:format` - Output format: `"json"` or `"csv"` (default: `"json"`)
    * `:depth` - Git log depth limit
    * `:branch` - Specific branch to analyze
  """
  @spec run(Pipeline.t(), String.t(), pid(), map()) :: :ok
  def run(%Pipeline{} = pipeline, repo_path, caller \\ self(), options \\ %{}) do
    Task.start_link(fn ->
      results = execute_dag(pipeline, repo_path, caller, options)
      send(caller, {:pipeline_complete, results})
    end)

    :ok
  end

  @doc """
  Executes a pipeline synchronously, returning the results map.

  Blocks until all nodes complete. Useful for CLI invocation and testing.
  """
  @spec run_sync(Pipeline.t(), String.t(), map()) :: {:ok, results()} | {:error, term()}
  def run_sync(%Pipeline{} = pipeline, repo_path, options \\ %{}) do
    results = execute_dag(pipeline, repo_path, nil, options)
    {:ok, results}
  rescue
    e -> {:error, Exception.message(e)}
  end

  @doc """
  Returns the list of executable nodes from a pipeline.
  Useful for progress tracking — tells the UI how many steps to expect.
  """
  @spec executable_nodes(Pipeline.t()) :: [Node.t()]
  def executable_nodes(%Pipeline{nodes: nodes}) do
    nodes
    |> Map.values()
    |> Enum.filter(fn node -> Compiler.runtime_type(node.type) != nil end)
  end

  # ── DAG Execution Engine ─────────────────────────────────────

  defp execute_dag(pipeline, repo_path, caller, _options) do
    case Compiler.to_workflow(pipeline, repo_path: repo_path) do
      {:ok, workflow} ->
        run_workflow(workflow, pipeline, caller)

      {:error, reason} ->
        Logger.error("Failed to compile pipeline: #{inspect(reason)}")
        %{}
    end
  end

  defp run_workflow(workflow, pipeline, caller) do
    # Build execution structures
    node_index = Map.new(workflow.nodes, &{&1.id, &1})
    sorted_ids = topological_sort(workflow)
    # Map of node_id → %{port_name => data}
    outputs = %{}

    sorted_ids
    |> Enum.reduce({outputs, %{}}, fn node_id, {outputs_acc, results_acc} ->
      node_def = Map.fetch!(node_index, node_id)
      pipeline_node = Map.get(pipeline.nodes, node_id)

      notify(caller, {:pipeline_progress, node_id, :running})

      # Gather input data from upstream nodes via connections
      input_data = gather_inputs(node_id, workflow.connections, outputs_acc)

      # Pass caller, node_id, and repo_path in context so nodes can send
      # sub-step progress and access the repo without explicit wiring
      context = %{caller: caller, node_id: node_id, repo_path: workflow.repo_path}

      case execute_runtime_node(node_def, input_data, context) do
        {:ok, output_data} ->
          label = if pipeline_node, do: pipeline_node.label, else: node_def.type
          type = if pipeline_node, do: pipeline_node.type, else: String.to_atom(node_def.type)

          notify(caller, {:pipeline_progress, node_id, {:done, output_data}})

          result = {:ok, %{node_id: node_id, type: type, label: label, data: output_data}}
          {Map.put(outputs_acc, node_id, output_data), Map.put(results_acc, node_id, result)}

        {:error, reason} = err ->
          Logger.warning("Node #{node_id} (#{node_def.type}) failed: #{inspect(reason)}")
          notify(caller, {:pipeline_progress, node_id, {:error, reason}})

          {outputs_acc, Map.put(results_acc, node_id, err)}
      end
    end)
    |> elem(1)
  end

  defp execute_runtime_node(node_def, input_data, context) do
    case Registry.get_node(node_def.type) do
      {:ok, module} ->
        params = node_def.parameters || %{}

        try do
          module.execute(input_data, params, context)
        rescue
          e ->
            Logger.error("Node #{node_def.id} raised: #{Exception.message(e)}")
            {:error, Exception.message(e)}
        end

      {:error, :not_found} ->
        {:error, "Runtime node not found: #{node_def.type}"}
    end
  end

  @doc false
  def report_status(context, message) when is_map(context) and is_binary(message) do
    case context do
      %{caller: caller, node_id: node_id} when is_pid(caller) ->
        notify(caller, {:pipeline_progress, node_id, {:status, message}})

      _ ->
        :ok
    end
  end

  # ── DAG helpers ──────────────────────────────────────────────

  # Gather input data for a node from upstream outputs via connections
  defp gather_inputs(node_id, connections, outputs) do
    connections
    |> Enum.filter(&(&1.to.node == node_id))
    |> Enum.reduce(%{}, fn conn, acc ->
      case Map.get(outputs, conn.from.node) do
        nil ->
          acc

        upstream_output when is_map(upstream_output) ->
          # Extract the specific port's data from upstream output
          port_key = String.to_atom(conn.from.port)
          value = Map.get(upstream_output, port_key) || Map.get(upstream_output, conn.from.port)

          if value do
            input_key = String.to_atom(conn.to.port)
            Map.put(acc, input_key, value)
          else
            acc
          end

        _ ->
          acc
      end
    end)
  end

  # Topological sort using Kahn's algorithm
  defp topological_sort(workflow) do
    nodes = workflow.nodes
    connections = workflow.connections

    # Build adjacency list and in-degree count
    node_ids = MapSet.new(nodes, & &1.id)

    in_degree =
      Enum.reduce(node_ids, %{}, fn id, acc -> Map.put(acc, id, 0) end)

    {adjacency, in_degree} =
      Enum.reduce(connections, {%{}, in_degree}, fn conn, {adj, deg} ->
        adj = Map.update(adj, conn.from.node, [conn.to.node], &[conn.to.node | &1])
        deg = Map.update(deg, conn.to.node, 1, &(&1 + 1))
        {adj, deg}
      end)

    # Start with nodes that have no incoming edges
    queue =
      in_degree
      |> Enum.filter(fn {_id, deg} -> deg == 0 end)
      |> Enum.map(fn {id, _} -> id end)

    do_topological_sort(queue, adjacency, in_degree, [])
  end

  defp do_topological_sort([], _adjacency, _in_degree, result), do: Enum.reverse(result)

  defp do_topological_sort([current | rest], adjacency, in_degree, result) do
    neighbors = Map.get(adjacency, current, [])

    {new_queue_additions, updated_in_degree} =
      Enum.reduce(neighbors, {[], in_degree}, fn neighbor, {additions, deg} ->
        new_deg = Map.update!(deg, neighbor, &(&1 - 1))

        if Map.get(new_deg, neighbor) == 0 do
          {[neighbor | additions], new_deg}
        else
          {additions, new_deg}
        end
      end)

    do_topological_sort(
      rest ++ Enum.reverse(new_queue_additions),
      adjacency,
      updated_in_degree,
      [current | result]
    )
  end

  # ── Notify ───────────────────────────────────────────────────

  defp notify(nil, _msg), do: :ok
  defp notify(pid, msg), do: send(pid, msg)
end
