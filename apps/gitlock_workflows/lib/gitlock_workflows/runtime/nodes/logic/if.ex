defmodule GitlockWorkflows.Runtime.Nodes.Logic.If do
  @moduledoc """
  Conditional branch — splits items into two output ports based on a condition.

  Like n8n's IF node. Each item is evaluated against the condition and routed
  to either the `true` or `false` output port. Downstream nodes connected to
  each port receive only the matching items.

  ## Examples

  Split hotspots into high-risk and low-risk:

      parameters: %{"field" => "risk_factor", "operator" => "eq", "value" => "high"}
      # true port: items where risk_factor == "high"
      # false port: items where risk_factor != "high"

  Branch on revision count threshold:

      parameters: %{"field" => "revisions", "operator" => "gte", "value" => "50"}
  """
  use GitlockWorkflows.Runtime.Node
  require Logger

  @operators ~w(eq neq gt lt gte lte contains not_contains is_empty is_not_empty)

  @impl true
  def metadata do
    %{
      id: "gitlock.logic.if",
      displayName: "IF",
      group: "logic",
      version: 1,
      description: "Routes items to 'true' or 'false' output based on a condition",
      inputs: [%{name: "items", type: :any, required: true}],
      outputs: [
        %{name: "true", type: :any, description: "Items matching the condition"},
        %{name: "false", type: :any, description: "Items not matching"}
      ],
      parameters: [
        %{name: "field", displayName: "Field", type: "string", required: true,
          description: "Field name to evaluate"},
        %{name: "operator", displayName: "Operator", type: "select", required: true,
          default: "eq",
          options: Enum.map(@operators, &%{value: &1, label: format_op(&1)}),
          description: "Comparison operator"},
        %{name: "value", displayName: "Value", type: "string", required: false,
          default: "", description: "Value to compare against (not needed for is_empty/is_not_empty)"}
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
      {true_items, false_items} = Enum.split_with(items, &matches?(&1, field, operator, value))
      Logger.info("IF: #{length(true_items)} true, #{length(false_items)} false")
      {:ok, %{true: true_items, false: false_items}}
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
  defp compare(a, "not_contains", b) when is_binary(a) and is_binary(b), do: not String.contains?(a, b)
  defp compare(nil, "is_empty", _), do: true
  defp compare("", "is_empty", _), do: true
  defp compare([], "is_empty", _), do: true
  defp compare(_, "is_empty", _), do: false
  defp compare(v, "is_not_empty", _), do: not compare(v, "is_empty", nil)
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
      list when is_list(list) -> list
      _ -> input_data |> Map.values() |> Enum.find([], &is_list/1)
    end
  end

  defp format_op("eq"), do: "Equals"
  defp format_op("neq"), do: "Not Equals"
  defp format_op("gt"), do: "Greater Than"
  defp format_op("lt"), do: "Less Than"
  defp format_op("gte"), do: "≥"
  defp format_op("lte"), do: "≤"
  defp format_op("contains"), do: "Contains"
  defp format_op("not_contains"), do: "Not Contains"
  defp format_op("is_empty"), do: "Is Empty"
  defp format_op("is_not_empty"), do: "Is Not Empty"
  defp format_op(other), do: other
end
