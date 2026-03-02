defmodule GitlockWorkflows.Runtime.Nodes.Logic.GroupBy do
  @moduledoc """
  Groups items by a field value.

  Outputs a map where keys are field values and values are lists of matching items.
  Also outputs a flat list of group summaries for downstream processing.

  ## Examples

  Group hotspots by risk_factor:

      parameters: %{"field" => "risk_factor"}
      # groups: %{"high" => [...], "medium" => [...], "low" => [...]}
  """
  use GitlockWorkflows.Runtime.Node
  require Logger

  @impl true
  def metadata do
    %{
      id: "gitlock.logic.group_by",
      displayName: "Group By",
      group: "logic",
      version: 1,
      description: "Groups items by a field value",
      inputs: [%{name: "items", type: :any, required: true}],
      outputs: [
        %{name: "groups", type: :any, description: "Map of group_value → items"},
        %{name: "items", type: :any, description: "Flat list of group summaries"}
      ],
      parameters: [
        %{
          name: "field",
          displayName: "Group By",
          type: "string",
          required: true,
          description: "Field name to group by"
        }
      ]
    }
  end

  @impl true
  def execute(input_data, parameters, _context) do
    items = resolve_items(input_data)
    field = Map.get(parameters, "field", "")

    if field == "" do
      {:error, "field parameter is required"}
    else
      groups = Enum.group_by(items, &get_field(&1, field))

      summaries =
        Enum.map(groups, fn {key, group_items} ->
          %{group: key, count: length(group_items), items: group_items}
        end)
        |> Enum.sort_by(& &1.count, :desc)

      Logger.info("Group by '#{field}': #{map_size(groups)} groups from #{length(items)} items")
      {:ok, %{groups: groups, items: summaries}}
    end
  end

  @impl true
  def validate_parameters(params) do
    if (Map.get(params, "field") || "") == "" do
      {:error, [{:missing_required_parameter, "field"}]}
    else
      :ok
    end
  end

  defp get_field(item, field) when is_map(item) do
    val = Map.get(item, field) || Map.get(item, String.to_atom(field))
    to_string(val || "unknown")
  end

  defp get_field(_, _), do: "unknown"

  defp resolve_items(input_data) do
    case Map.get(input_data, :items) do
      list when is_list(list) -> list
      _ -> input_data |> Map.values() |> Enum.find([], &is_list/1)
    end
  end
end
