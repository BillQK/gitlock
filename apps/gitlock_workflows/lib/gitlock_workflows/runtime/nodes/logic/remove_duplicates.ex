defmodule GitlockWorkflows.Runtime.Nodes.Logic.RemoveDuplicates do
  @moduledoc """
  Removes duplicate items based on a field value.

  Keeps the first occurrence of each unique value.

  ## Examples

  Deduplicate coupled hotspots by entity:

      parameters: %{"field" => "entity"}
  """
  use GitlockWorkflows.Runtime.Node
  require Logger

  @impl true
  def metadata do
    %{
      id: "gitlock.logic.remove_duplicates",
      displayName: "Remove Duplicates",
      group: "logic",
      version: 1,
      description: "Removes duplicate items based on a field value",
      inputs: [%{name: "items", type: :any, required: true}],
      outputs: [%{name: "items", type: :any}],
      parameters: [
        %{name: "field", displayName: "Deduplicate By", type: "string", required: true,
          description: "Field to check for duplicates"}
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
      unique =
        items
        |> Enum.uniq_by(&get_field(&1, field))

      Logger.info("Deduplicate by '#{field}': #{length(items)} → #{length(unique)}")
      {:ok, %{items: unique}}
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
    Map.get(item, field) || Map.get(item, String.to_atom(field))
  end

  defp get_field(_, _), do: nil

  defp resolve_items(input_data) do
    case Map.get(input_data, :items) do
      list when is_list(list) -> list
      _ -> input_data |> Map.values() |> Enum.find([], &is_list/1)
    end
  end
end
