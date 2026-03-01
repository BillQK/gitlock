defmodule GitlockWorkflows.Executor.DagFlowTest do
  @moduledoc """
  Integration tests proving DAG-based data flow works end-to-end.
  Registers mock runtime nodes, builds workflows, and verifies data passes through connections.
  """
  use ExUnit.Case

  alias GitlockWorkflows.Runtime.Registry

  # ── Test runtime nodes ───────────────────────────────────────

  defmodule SourceNode do
    use GitlockWorkflows.Runtime.Node

    def metadata do
      %{
        id: "test.dag.source",
        displayName: "DAG Source",
        group: "trigger",
        version: 1,
        description: "Emits test data",
        inputs: [],
        outputs: [%{name: "items", type: {:list, :map}}],
        parameters: []
      }
    end

    def execute(_input, _params, _ctx) do
      {:ok, %{items: [%{name: "a", score: 10}, %{name: "b", score: 20}]}}
    end

    def validate_parameters(_), do: :ok
  end

  defmodule TransformNode do
    use GitlockWorkflows.Runtime.Node

    def metadata do
      %{
        id: "test.dag.transform",
        displayName: "DAG Transform",
        group: "analysis",
        version: 1,
        description: "Doubles scores",
        inputs: [%{name: "items", type: {:list, :map}, required: true}],
        outputs: [%{name: "results", type: {:list, :map}}],
        parameters: []
      }
    end

    def execute(input_data, _params, _ctx) do
      items = input_data[:items] || []
      {:ok, %{results: Enum.map(items, &Map.update!(&1, :score, fn s -> s * 2 end))}}
    end

    def validate_parameters(_), do: :ok
  end

  defmodule SinkNode do
    use GitlockWorkflows.Runtime.Node

    def metadata do
      %{
        id: "test.dag.sink",
        displayName: "DAG Sink",
        group: "analysis",
        version: 1,
        description: "Sums scores",
        inputs: [%{name: "results", type: {:list, :map}, required: true}],
        outputs: [%{name: "summary", type: :map}],
        parameters: []
      }
    end

    def execute(input_data, _params, _ctx) do
      results = input_data[:results] || []
      total = Enum.reduce(results, 0, fn item, acc -> acc + item.score end)
      {:ok, %{summary: %{count: length(results), total_score: total}}}
    end

    def validate_parameters(_), do: :ok
  end

  defmodule CountingSource do
    use GitlockWorkflows.Runtime.Node

    def metadata do
      %{
        id: "test.dag.counting_source",
        displayName: "Counting Source",
        group: "trigger",
        version: 1,
        description: "Counts executions",
        inputs: [],
        outputs: [%{name: "items", type: {:list, :map}}],
        parameters: []
      }
    end

    def execute(_input, _params, _ctx) do
      Agent.update(:source_exec_count, &(&1 + 1))
      {:ok, %{items: [%{name: "x", score: 5}]}}
    end

    def validate_parameters(_), do: :ok
  end

  # ── Setup ────────────────────────────────────────────────────

  setup do
    Registry.register_node(SourceNode)
    Registry.register_node(TransformNode)
    Registry.register_node(SinkNode)
    :ok
  end

  # ── Tests ────────────────────────────────────────────────────

  describe "DAG data flow" do
    test "linear chain: source → transform → sink" do
      workflow =
        build_workflow(
          [
            node("src", "test.dag.source"),
            node("xform", "test.dag.transform"),
            node("sink", "test.dag.sink")
          ],
          [
            conn("src", "items", "xform", "items"),
            conn("xform", "results", "sink", "results")
          ]
        )

      results = run_dag(workflow)

      assert {:ok, src} = results["src"]
      assert length(src.data.items) == 2

      assert {:ok, xform} = results["xform"]
      assert Enum.map(xform.data.results, & &1.score) == [20, 40]

      assert {:ok, sink} = results["sink"]
      assert sink.data.summary == %{count: 2, total_score: 60}
    end

    test "fan-out: source feeds two transforms independently" do
      workflow =
        build_workflow(
          [
            node("src", "test.dag.source"),
            node("a", "test.dag.transform"),
            node("b", "test.dag.transform")
          ],
          [
            conn("src", "items", "a", "items"),
            conn("src", "items", "b", "items")
          ]
        )

      results = run_dag(workflow)

      assert {:ok, ra} = results["a"]
      assert {:ok, rb} = results["b"]
      assert Enum.map(ra.data.results, & &1.score) == [20, 40]
      assert Enum.map(rb.data.results, & &1.score) == [20, 40]
    end

    test "source executes exactly once despite multiple downstream consumers" do
      Registry.register_node(CountingSource)
      Agent.start_link(fn -> 0 end, name: :source_exec_count)

      workflow =
        build_workflow(
          [
            node("src", "test.dag.counting_source"),
            node("a", "test.dag.transform"),
            node("b", "test.dag.transform"),
            node("c", "test.dag.transform")
          ],
          [
            conn("src", "items", "a", "items"),
            conn("src", "items", "b", "items"),
            conn("src", "items", "c", "items")
          ]
        )

      results = run_dag(workflow)

      assert map_size(results) == 4
      assert Agent.get(:source_exec_count, & &1) == 1

      Agent.stop(:source_exec_count)
    end

    test "progress messages sent in topological order" do
      workflow =
        build_workflow(
          [
            node("src", "test.dag.source"),
            node("xform", "test.dag.transform")
          ],
          [
            conn("src", "items", "xform", "items")
          ]
        )

      me = self()

      Task.start_link(fn ->
        results = run_dag(workflow, me)
        send(me, {:pipeline_complete, results})
      end)

      messages = collect_messages(10)

      events =
        Enum.map(messages, fn
          {:pipeline_progress, id, :running} -> {:running, id}
          {:pipeline_progress, id, {:done, _}} -> {:done, id}
          {:pipeline_complete, _} -> :complete
        end)

      # src finishes before xform starts
      src_done = Enum.find_index(events, &(&1 == {:done, "src"}))
      xform_run = Enum.find_index(events, &(&1 == {:running, "xform"}))
      assert src_done < xform_run
    end
  end

  # ── Workflow builder helpers ─────────────────────────────────

  defp node(id, type),
    do: %{id: id, type: type, position: [0, 0], parameters: %{}, disabled: false}

  defp conn(from_node, from_port, to_node, to_port) do
    %{from: %{node: from_node, port: from_port}, to: %{node: to_node, port: to_port}}
  end

  defp build_workflow(nodes, connections) do
    %GitlockWorkflows.Runtime.Workflow{
      id: "test-#{:erlang.unique_integer([:positive])}",
      name: "Test Workflow",
      nodes: nodes,
      connections: connections,
      settings: %{},
      version: 1
    }
  end

  # ── DAG execution (mirrors Executor internals) ───────────────

  defp run_dag(workflow, caller \\ nil) do
    node_index = Map.new(workflow.nodes, &{&1.id, &1})
    sorted = topo_sort(workflow)

    sorted
    |> Enum.reduce({%{}, %{}}, fn node_id, {outputs, results} ->
      node_def = Map.fetch!(node_index, node_id)
      notify(caller, {:pipeline_progress, node_id, :running})

      input_data = gather_inputs(node_id, workflow.connections, outputs)

      case run_node(node_def, input_data) do
        {:ok, output_data} ->
          notify(caller, {:pipeline_progress, node_id, {:done, output_data}})

          result =
            {:ok,
             %{node_id: node_id, type: node_def.type, label: node_def.type, data: output_data}}

          {Map.put(outputs, node_id, output_data), Map.put(results, node_id, result)}

        {:error, _} = err ->
          notify(caller, {:pipeline_progress, node_id, err})
          {outputs, Map.put(results, node_id, err)}
      end
    end)
    |> elem(1)
  end

  defp run_node(node_def, input_data) do
    {:ok, mod} = Registry.get_node(node_def.type)
    mod.execute(input_data, node_def.parameters, %{})
  end

  defp gather_inputs(node_id, connections, outputs) do
    connections
    |> Enum.filter(&(&1.to.node == node_id))
    |> Enum.reduce(%{}, fn conn, acc ->
      case Map.get(outputs, conn.from.node) do
        upstream when is_map(upstream) ->
          key = String.to_atom(conn.from.port)

          case Map.get(upstream, key) do
            nil -> acc
            val -> Map.put(acc, String.to_atom(conn.to.port), val)
          end

        _ ->
          acc
      end
    end)
  end

  defp topo_sort(workflow) do
    ids = MapSet.new(workflow.nodes, & &1.id)
    deg = Map.new(ids, &{&1, 0})

    {adj, deg} =
      Enum.reduce(workflow.connections, {%{}, deg}, fn c, {a, d} ->
        {Map.update(a, c.from.node, [c.to.node], &[c.to.node | &1]),
         Map.update(d, c.to.node, 1, &(&1 + 1))}
      end)

    queue = for {id, 0} <- deg, do: id
    do_topo(queue, adj, deg, [])
  end

  defp do_topo([], _, _, r), do: Enum.reverse(r)

  defp do_topo([h | t], adj, deg, r) do
    {q, d} =
      Enum.reduce(Map.get(adj, h, []), {[], deg}, fn n, {q, d} ->
        d = Map.update!(d, n, &(&1 - 1))
        if d[n] == 0, do: {[n | q], d}, else: {q, d}
      end)

    do_topo(t ++ Enum.reverse(q), adj, d, [h | r])
  end

  defp notify(nil, _), do: :ok
  defp notify(pid, msg), do: send(pid, msg)

  defp collect_messages(max, acc \\ [])
  defp collect_messages(0, acc), do: Enum.reverse(acc)

  defp collect_messages(n, acc) do
    receive do
      msg -> collect_messages(n - 1, [msg | acc])
    after
      2000 -> Enum.reverse(acc)
    end
  end
end
