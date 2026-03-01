defmodule GitlockWorkflows.Runtime.Nodes.Transform.ExtractField do
  @moduledoc """
  Transform node that extracts a specific field from input data.

  Useful for reshaping data between nodes when output/input ports don't match.
  For example, extracting the 'hotspots' field to pass just the list to another node.
  """
  use GitlockWorkflows.Runtime.Node
  require Logger

  @impl true
  def metadata do
    %{
      id: "gitlock.transform.extract_field",
      displayName: "Extract Field",
      group: "transform",
      version: 1,
      description: "Extracts a specific field from the input data",
      inputs: [
        %{
          name: "input",
          type: :any,
          required: true,
          description: "Input data containing the field to extract"
        }
      ],
      outputs: [
        %{
          name: "output",
          type: :any,
          description: "The extracted field value"
        }
      ],
      parameters: [
        %{
          name: "field_name",
          displayName: "Field Name",
          type: "string",
          required: true,
          description: "Name of the field to extract (e.g., 'hotspots', 'results')"
        },
        %{
          name: "default_value",
          displayName: "Default Value",
          type: "any",
          default: nil,
          required: false,
          description: "Value to use if field doesn't exist"
        }
      ]
    }
  end

  @impl true
  def execute(input_data, parameters, _context) do
    field_name = Map.get(parameters, "field_name") || Map.get(parameters, :field_name)
    default_value = Map.get(parameters, "default_value", nil)

    if is_nil(field_name) or field_name == "" do
      {:error, "field_name parameter is required"}
    else
      # Extract the field value
      value = extract_field_value(input_data, field_name, default_value)

      Logger.info("Extracted field '#{field_name}': #{inspect(value, limit: 5)}")

      {:ok, %{output: value}}
    end
  end

  @impl true
  def validate_parameters(parameters) do
    field_name = Map.get(parameters, "field_name") || Map.get(parameters, :field_name)

    if is_nil(field_name) or field_name == "" do
      {:error, [{:missing_required_parameter, "field_name"}]}
    else
      :ok
    end
  end

  defp extract_field_value(data, field_name, default) when is_map(data) do
    # Try both string and atom keys
    # Check the 'input' port
    Map.get(data, field_name) ||
      Map.get(data, String.to_atom(field_name)) ||
      Map.get(data, :input) ||
      default
  end

  defp extract_field_value(_data, _field_name, default), do: default
end
