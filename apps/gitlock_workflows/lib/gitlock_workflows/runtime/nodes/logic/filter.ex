defmodule GitlockWorkflows.Runtime.Nodes.Logic.Filter do
  @moduledoc """
  Filters items based on a field condition.

  Like n8n's Filter node — keeps items where a field matches a condition,
  and sends rejected items to a separate output port.

  ## Examples

  Filter hotspots to only high-risk:

      parameters: %{"field" => "risk_factor", "operator" => "eq", "value" => "high"}

  Filter files with more than 10 revisions:

      parameters: %{"field" => "revisions", "operator" => "gt", "value" => "10"}
  """
  use GitlockWorkflows.Runtime.Node
  require Logger

  @operators ~w(eq neq gt lt gte lte contains not_contains)

  @impl true
  def metadata do
    %{
      id: "gitlock.logic.filter",
      displayName: "Filter",
      group: "logic",
      version: 1,
      description: "Keeps items matching a condition, sends rejected items to a separate output",
      inputs: [%{name: "items", type: :any, required: true}],
      outputs: [
        %{name: "kept", type: :any, description: "Items matching the condition"},
        %{name: "rejected", type: :any, description: "Items not matching"}
      ],
      parameters: [
        %{
          name: "field",
          displayName: "Field",
          type: "string",
          required: true,
          description: "Field name to check (e.g., 'risk_factor', 'revisions')"
        },
        %{
          name: "operator",
          displayName: "Operator",
          type: "select",
          required: true,
          default: "eq",
          options: Enum.map(@operators, &%{value: &1, label: format_op(&1)}),
          description: "Comparison operator"
        },
        %{
          name: "value",
          displayName: "Value",
          type: "string",
          required: true,
          description: "Value to compare against"
        }
      ]
    }
  end

  @impl true
  def execute(input_data, parameters, _context) do
    items = resolve_items(input_data)
    field = Map.get(parameters, "field", "")
    operator = Map.get(parameters, "operator", "eq")
    value = Map.get(parameters, "value", "")

    if field == "" do
      {:error, "field parameter is required"}
    else
      {kept, rejected} = Enum.split_with(items, &matches?(&1, field, operator, value))
      Logger.info("Filter: #{length(kept)} kept, #{length(rejected)} rejected")
      {:ok, %{kept: kept, rejected: rejected}}
    end
  end

  @impl true
  def validate_parameters(params) do
    cond do
      blank?(params, "field") -> {:error, [{:missing_required_parameter, "field"}]}
      blank?(params, "operator") -> {:error, [{:missing_required_parameter, "operator"}]}
      true -> :ok
    end
  end

  defp matches?(item, field, operator, value) when is_map(item) do
    item_value = get_field(item, field)
    compare(item_value, operator, coerce(value, item_value))
  end

  defp matches?(_, _, _, _), do: false

  defp compare(a, "eq", b), do: a == b
  defp compare(a, "neq", b), do: a != b
  defp compare(a, "gt", b) when is_number(a) and is_number(b), do: a > b
  defp compare(a, "lt", b) when is_number(a) and is_number(b), do: a < b
  defp compare(a, "gte", b) when is_number(a) and is_number(b), do: a >= b
  defp compare(a, "lte", b) when is_number(a) and is_number(b), do: a <= b
  defp compare(a, "contains", b) when is_binary(a) and is_binary(b), do: String.contains?(a, b)

  defp compare(a, "not_contains", b) when is_binary(a) and is_binary(b),
    do: not String.contains?(a, b)

  defp compare(_, _, _), do: false

  defp coerce(value, reference) when is_number(reference) do
    case Float.parse(value) do
      {num, _} -> num
      :error -> value
    end
  end

  defp coerce(value, reference) when is_atom(reference) and not is_nil(reference) do
    try do
      String.to_existing_atom(value)
    rescue
      _ -> value
    end
  end

  defp coerce(value, _), do: value

  defp get_field(item, field) do
    Map.get(item, field) || Map.get(item, String.to_atom(field))
  end

  defp resolve_items(input_data) do
    case Map.get(input_data, :items) do
      list when is_list(list) ->
        list

      _ ->
        # Try to find the first list value in input data
        input_data |> Map.values() |> Enum.find([], &is_list/1)
    end
  end

  defp blank?(params, key), do: (Map.get(params, key) || "") == ""

  defp format_op("eq"), do: "Equals"
  defp format_op("neq"), do: "Not Equals"
  defp format_op("gt"), do: "Greater Than"
  defp format_op("lt"), do: "Less Than"
  defp format_op("gte"), do: "Greater or Equal"
  defp format_op("lte"), do: "Less or Equal"
  defp format_op("contains"), do: "Contains"
  defp format_op("not_contains"), do: "Not Contains"
  defp format_op(other), do: other
end
