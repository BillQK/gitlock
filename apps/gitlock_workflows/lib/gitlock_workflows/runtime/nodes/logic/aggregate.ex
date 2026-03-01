defmodule GitlockWorkflows.Runtime.Nodes.Logic.Aggregate do
  @moduledoc """
  Computes aggregate statistics over a list of items.

  Outputs a summary map with computed values. Useful for dashboards
  and reports that need totals, averages, or distributions.

  ## Examples

  Count and sum revisions across hotspots:

      parameters: %{"operations" => "count,sum:revisions,avg:risk_score,max:complexity"}
  """
  use GitlockWorkflows.Runtime.Node
  require Logger

  @impl true
  def metadata do
    %{
      id: "gitlock.logic.aggregate",
      displayName: "Aggregate",
      group: "logic",
      version: 1,
      description: "Computes statistics: count, sum, average, min, max over items",
      inputs: [%{name: "items", type: :any, required: true}],
      outputs: [%{name: "result", type: :any}],
      parameters: [
        %{name: "operations", displayName: "Operations", type: "string", required: true,
          default: "count", placeholder: "count,sum:revisions,avg:risk_score,max:complexity",
          description: "Comma-separated: count, sum:field, avg:field, min:field, max:field"}
      ]
    }
  end

  @impl true
  def execute(input_data, parameters, _context) do
    items = resolve_items(input_data)
    ops_string = Map.get(parameters, "operations", "count")

    ops = parse_operations(ops_string)
    result = compute(items, ops)

    Logger.info("Aggregate: #{length(ops)} operations over #{length(items)} items")
    {:ok, %{result: result}}
  end

  @impl true
  def validate_parameters(_), do: :ok

  defp parse_operations(ops_string) do
    ops_string
    |> String.split(",", trim: true)
    |> Enum.map(&String.trim/1)
    |> Enum.map(fn op ->
      case String.split(op, ":", parts: 2) do
        [func, field] -> {func, field}
        [func] -> {func, nil}
      end
    end)
  end

  defp compute(items, ops) do
    Enum.reduce(ops, %{}, fn {func, field}, acc ->
      key = if field, do: "#{func}_#{field}", else: func
      value = run_op(func, field, items)
      Map.put(acc, key, value)
    end)
  end

  defp run_op("count", _field, items), do: length(items)

  defp run_op("sum", field, items) do
    items |> Enum.map(&get_number(&1, field)) |> Enum.sum()
  end

  defp run_op("avg", field, items) do
    values = Enum.map(items, &get_number(&1, field))
    if values == [], do: 0, else: Enum.sum(values) / length(values)
  end

  defp run_op("min", field, items) do
    items |> Enum.map(&get_number(&1, field)) |> Enum.min(fn -> 0 end)
  end

  defp run_op("max", field, items) do
    items |> Enum.map(&get_number(&1, field)) |> Enum.max(fn -> 0 end)
  end

  defp run_op(unknown, _, _), do: {:error, "unknown operation: #{unknown}"}

  defp get_number(item, field) when is_map(item) do
    val = Map.get(item, field) || Map.get(item, String.to_atom(field))
    to_number(val)
  end

  defp get_number(_, _), do: 0

  defp to_number(v) when is_number(v), do: v
  defp to_number(v) when is_binary(v) do
    case Float.parse(v) do
      {n, _} -> n
      :error -> 0
    end
  end
  defp to_number(_), do: 0

  defp resolve_items(input_data) do
    case Map.get(input_data, :items) do
      list when is_list(list) -> list
      _ -> input_data |> Map.values() |> Enum.find([], &is_list/1)
    end
  end
end
