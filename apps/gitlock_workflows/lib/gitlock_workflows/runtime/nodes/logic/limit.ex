defmodule GitlockWorkflows.Runtime.Nodes.Logic.Limit do
  @moduledoc """
  Takes the first or last N items from a list.

  ## Examples

  Top 20 hotspots:

      parameters: %{"count" => 20, "from" => "start"}

  Bottom 5 by risk:

      parameters: %{"count" => 5, "from" => "end"}
  """
  use GitlockWorkflows.Runtime.Node
  require Logger

  @impl true
  def metadata do
    %{
      id: "gitlock.logic.limit",
      displayName: "Limit",
      group: "logic",
      version: 1,
      description: "Takes the first or last N items",
      inputs: [%{name: "items", type: :any, required: true}],
      outputs: [%{name: "items", type: :any}],
      parameters: [
        %{
          name: "count",
          displayName: "Count",
          type: "number",
          required: true,
          default: 10,
          description: "Number of items to keep"
        },
        %{
          name: "from",
          displayName: "From",
          type: "select",
          required: false,
          default: "start",
          options: [%{value: "start", label: "First N"}, %{value: "end", label: "Last N"}],
          description: "Take from start or end of list"
        }
      ]
    }
  end

  @impl true
  def execute(input_data, parameters, _context) do
    items = resolve_items(input_data)
    count = to_int(Map.get(parameters, "count", 10))
    from = Map.get(parameters, "from", "start")

    limited =
      case from do
        "end" -> Enum.take(items, -count)
        _ -> Enum.take(items, count)
      end

    Logger.info("Limit: #{length(limited)} of #{length(items)} items (#{from})")
    {:ok, %{items: limited}}
  end

  @impl true
  def validate_parameters(_), do: :ok

  defp to_int(v) when is_integer(v), do: v
  defp to_int(v) when is_float(v), do: round(v)

  defp to_int(v) when is_binary(v) do
    case Integer.parse(v) do
      {n, _} -> n
      :error -> 10
    end
  end

  defp to_int(_), do: 10

  defp resolve_items(input_data) do
    case Map.get(input_data, :items) do
      list when is_list(list) -> list
      _ -> input_data |> Map.values() |> Enum.find([], &is_list/1)
    end
  end
end
