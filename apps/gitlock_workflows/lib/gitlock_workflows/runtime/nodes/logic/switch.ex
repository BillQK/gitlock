defmodule GitlockWorkflows.Runtime.Nodes.Logic.Switch do
  @moduledoc """
  Multi-way branch based on a field's value.

  Like n8n's Switch node. Routes items to named output ports based on
  which value a field holds. Items that don't match any case go to the
  `default` output.

  ## Examples

  Route hotspots by risk level:

      parameters: %{
        "field" => "risk_factor",
        "cases" => "high,medium,low"
      }
      # Outputs: high, medium, low, default
  """
  use GitlockWorkflows.Runtime.Node
  require Logger

  @impl true
  def metadata do
    %{
      id: "gitlock.logic.switch",
      displayName: "Switch",
      group: "logic",
      version: 1,
      description: "Routes items to different outputs based on a field's value",
      inputs: [%{name: "items", type: :any, required: true}],
      outputs: [
        %{name: "case_0", type: :any, description: "First case"},
        %{name: "case_1", type: :any, description: "Second case"},
        %{name: "case_2", type: :any, description: "Third case"},
        %{name: "case_3", type: :any, description: "Fourth case"},
        %{name: "default", type: :any, description: "Items not matching any case"}
      ],
      parameters: [
        %{name: "field", displayName: "Field", type: "string", required: true,
          description: "Field name to switch on"},
        %{name: "cases", displayName: "Cases", type: "string", required: true,
          placeholder: "high,medium,low",
          description: "Comma-separated values to match (maps to case_0, case_1, ...)"}
      ]
    }
  end

  @impl true
  def execute(input_data, parameters, _context) do
    items = resolve_items(input_data)
    field = Map.get(parameters, "field", "")
    cases_str = Map.get(parameters, "cases", "")

    if field == "" or cases_str == "" do
      {:error, "field and cases parameters are required"}
    else
      case_values =
        cases_str
        |> String.split(",", trim: true)
        |> Enum.map(&String.trim/1)

      # Group items by which case they match
      grouped = Enum.group_by(items, fn item ->
        item_val = get_field(item, field) |> to_string()
        Enum.find_index(case_values, &(&1 == item_val))
      end)

      # Build output map with case_0, case_1, ... and default
      output =
        case_values
        |> Enum.with_index()
        |> Enum.reduce(%{}, fn {_val, idx}, acc ->
          port = String.to_atom("case_#{idx}")
          Map.put(acc, port, Map.get(grouped, idx, []))
        end)
        |> Map.put(:default, Map.get(grouped, nil, []))

      counts = Enum.map(output, fn {k, v} -> "#{k}=#{length(v)}" end) |> Enum.join(", ")
      Logger.info("Switch on '#{field}': #{counts}")
      {:ok, output}
    end
  end

  @impl true
  def validate_parameters(params) do
    cond do
      (Map.get(params, "field") || "") == "" -> {:error, [{:missing_required_parameter, "field"}]}
      (Map.get(params, "cases") || "") == "" -> {:error, [{:missing_required_parameter, "cases"}]}
      true -> :ok
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
