defmodule GitlockWorkflows.Runtime.Nodes.Logic.Sort do
  @moduledoc """
  Sorts items by a field value.

  ## Examples

  Sort hotspots by risk score descending (worst first):

      parameters: %{"field" => "risk_score", "direction" => "desc"}
  """
  use GitlockWorkflows.Runtime.Node
  require Logger

  @impl true
  def metadata do
    %{
      id: "gitlock.logic.sort",
      displayName: "Sort",
      group: "logic",
      version: 1,
      description: "Sorts items by a field value",
      inputs: [%{name: "items", type: :any, required: true}],
      outputs: [%{name: "items", type: :any}],
      parameters: [
        %{
          name: "field",
          displayName: "Sort By",
          type: "string",
          required: true,
          description: "Field name to sort by"
        },
        %{
          name: "direction",
          displayName: "Direction",
          type: "select",
          required: false,
          default: "asc",
          options: [%{value: "asc", label: "Ascending"}, %{value: "desc", label: "Descending"}],
          description: "Sort direction"
        }
      ]
    }
  end

  @impl true
  def execute(input_data, parameters, _context) do
    items = resolve_items(input_data)
    field = Map.get(parameters, "field", "")
    direction = Map.get(parameters, "direction", "asc")

    if field == "" do
      {:error, "field parameter is required"}
    else
      sorter = fn item -> get_field(item, field) end

      sorted =
        case direction do
          "desc" -> Enum.sort_by(items, sorter, :desc)
          _ -> Enum.sort_by(items, sorter, :asc)
        end

      Logger.info("Sorted #{length(sorted)} items by #{field} #{direction}")
      {:ok, %{items: sorted}}
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
