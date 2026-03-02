defmodule GitlockWorkflows.Runtime.Nodes.Output.CsvExport do
  @moduledoc """
  Flexible CSV export node that handles both direct data and nested data.
  """
  use GitlockWorkflows.Runtime.Node
  require Logger

  @impl true
  def metadata do
    %{
      id: "gitlock.output.csv_export",
      displayName: "CSV Export",
      group: "output",
      version: 1,
      description: "Exports any list data to CSV format",
      inputs: [
        %{
          name: "data",
          type: :any,
          required: true,
          description: "Data to export (can be a list or a map containing a list)"
        }
      ],
      outputs: [
        %{
          name: "file_path",
          type: :string,
          description: "Path to the exported CSV file"
        },
        %{
          name: "records_exported",
          type: :integer,
          description: "Number of records exported"
        }
      ],
      parameters: [
        %{
          name: "output_dir",
          displayName: "Output Directory",
          type: "string",
          default: "/output",
          required: true,
          description: "Directory where the CSV file will be saved"
        },
        %{
          name: "filename",
          displayName: "Filename",
          type: "string",
          default: "export.csv",
          required: false,
          description: "Name of the CSV file"
        },
        %{
          name: "columns",
          displayName: "Columns",
          type: "list",
          default: nil,
          required: false,
          description: "Specific columns to export (nil exports all)"
        }
      ]
    }
  end

  @impl true
  def execute(input_data, parameters, _context) do
    Logger.info("CSV Export started")
    Logger.debug("Input data structure: #{inspect(Map.keys(input_data))}")

    # The data comes directly on the :data port
    raw_data = Map.get(input_data, :data)

    Logger.debug(
      "Raw data type: #{inspect(is_list(raw_data))}, first item: #{inspect(List.first(raw_data || []), limit: 3)}"
    )

    # Ensure we have a list to work with
    data =
      case raw_data do
        nil ->
          Logger.error("No data received on :data port")
          nil

        list when is_list(list) ->
          Logger.info("Received list with #{length(list)} items")
          list

        other ->
          Logger.error("Expected list but got: #{inspect(other)}")
          nil
      end

    case data do
      nil ->
        {:error, "No data found to export"}

      [] ->
        {:error, "Data is empty"}

      data_list ->
        # Extract parameters
        output_dir = Map.get(parameters, "output_dir", "/output")
        filename = Map.get(parameters, "filename", "export.csv")
        columns = Map.get(parameters, "columns")

        # Ensure output directory exists
        File.mkdir_p!(output_dir)

        # Generate full file path
        file_path = Path.join(output_dir, ensure_csv_extension(filename))

        Logger.info("Exporting #{length(data_list)} records to #{file_path}")

        # Export to CSV
        case export_to_csv(data_list, file_path, columns) do
          :ok ->
            Logger.info("Successfully exported #{length(data_list)} records to #{file_path}")

            {:ok,
             %{
               file_path: file_path,
               records_exported: length(data_list)
             }}

          {:error, reason} ->
            Logger.error("Failed to export CSV: #{inspect(reason)}")
            {:error, "Failed to export CSV: #{inspect(reason)}"}
        end
    end
  end

  @impl true
  def validate_parameters(parameters) do
    output_dir = Map.get(parameters, "output_dir")

    cond do
      is_nil(output_dir) or output_dir == "" ->
        {:error, [{:missing_required_parameter, "output_dir"}]}

      true ->
        :ok
    end
  end

  # Private functions

  defp ensure_csv_extension(filename) do
    if String.ends_with?(filename, ".csv") do
      filename
    else
      filename <> ".csv"
    end
  end

  defp export_to_csv(data, file_path, specific_columns) do
    try do
      # Handle empty data
      if Enum.empty?(data) do
        File.write!(file_path, "")
        :ok
      end

      # Get all unique keys from the data
      all_keys =
        data
        |> Enum.flat_map(fn item ->
          case item do
            map when is_map(map) -> Map.keys(map)
            _ -> []
          end
        end)
        |> Enum.uniq()
        |> Enum.map(&to_string/1)
        |> Enum.sort()

      # Use specific columns if provided, otherwise use all keys
      columns = if specific_columns, do: specific_columns, else: all_keys

      Logger.debug("Using columns: #{inspect(columns)}")

      # Create CSV content
      csv_content =
        [
          # Headers
          Enum.join(columns, ","),
          # Data rows
          Enum.map(data, fn row ->
            columns
            |> Enum.map(fn col ->
              value = get_value(row, col)
              format_csv_value(value)
            end)
            |> Enum.join(",")
          end)
        ]
        |> List.flatten()
        |> Enum.join("\n")

      # Write to file
      File.write!(file_path, csv_content)

      Logger.info("CSV file written successfully")
      :ok
    rescue
      e ->
        Logger.error("Exception during CSV export: #{inspect(e)}")
        {:error, Exception.message(e)}
    end
  end

  defp get_value(row, column) when is_map(row) do
    # Try string key first, then atom key
    Map.get(row, column) || Map.get(row, String.to_atom(column)) || ""
  end

  defp get_value(_, _), do: ""

  defp format_csv_value(value) when is_binary(value) do
    # Escape quotes and wrap in quotes if contains comma, quote, or newline
    if String.contains?(value, [",", "\"", "\n", "\r"]) do
      "\"" <> String.replace(value, "\"", "\"\"") <> "\""
    else
      value
    end
  end

  defp format_csv_value(value) when is_float(value),
    do: :erlang.float_to_binary(value, decimals: 2)

  defp format_csv_value(value) when is_integer(value), do: Integer.to_string(value)
  defp format_csv_value(true), do: "true"
  defp format_csv_value(false), do: "false"
  defp format_csv_value(:high), do: "high"
  defp format_csv_value(:medium), do: "medium"
  defp format_csv_value(:low), do: "low"
  defp format_csv_value(value) when is_atom(value), do: Atom.to_string(value)
  defp format_csv_value(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp format_csv_value(%Date{} = d), do: Date.to_iso8601(d)
  defp format_csv_value(nil), do: ""
  defp format_csv_value(value), do: inspect(value)
end
