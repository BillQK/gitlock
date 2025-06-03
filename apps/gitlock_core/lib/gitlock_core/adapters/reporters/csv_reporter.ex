defmodule GitlockCore.Adapters.Reporters.CsvReporter do
  @moduledoc """
  CSV reporter for formatting analysis results.
  """
  @behaviour GitlockCore.Ports.ReportPort

  @type report_options :: %{optional(:rows) => non_neg_integer()}

  @impl true
  @spec report(list(map()), report_options()) :: {:ok, String.t()} | {:error, String.t()}
  def report(results, options) do
    with {:ok, validated_results} <- validate_results(results),
         {:ok, validated_options} <- validate_options(options) do
      try do
        # Apply row limit if specified
        limited_results =
          if validated_options[:rows],
            do: Enum.take(validated_results, validated_options[:rows]),
            else: validated_results

        # Handle empty results case
        if Enum.empty?(limited_results) do
          {:ok, "No results found"}
        else
          # Determine headers dynamically from the first result
          headers = extract_headers(List.first(limited_results))

          # Convert each result to a list of values in the same order as headers
          rows = format_rows(limited_results, headers)

          # Format as CSV
          csv_content =
            [headers | rows]
            |> Enum.map_join("\n", &Enum.join(&1, ","))

          {:ok, csv_content}
        end
      rescue
        e -> {:error, "CSV generation failed: #{Exception.message(e)}"}
      end
    end
  end

  @spec validate_results(any()) :: {:ok, list(map())} | {:error, String.t()}
  defp validate_results(results) when is_list(results), do: {:ok, results}
  defp validate_results(results), do: {:error, "Results must be a list, got: #{inspect(results)}"}

  @spec validate_options(any()) :: {:ok, report_options()} | {:error, String.t()}
  defp validate_options(options) when is_map(options) do
    case validate_rows_option(options) do
      {:ok, _} -> {:ok, options}
      error -> error
    end
  end

  defp validate_options(options), do: {:error, "Options must be a map, got: #{inspect(options)}"}

  @spec validate_rows_option(map()) :: {:ok, map()} | {:error, String.t()}
  defp validate_rows_option(%{rows: rows}) when is_integer(rows) and rows >= 0,
    do: {:ok, %{rows: rows}}

  defp validate_rows_option(%{rows: rows}),
    do: {:error, "rows must be a non-negative integer, got: #{inspect(rows)}"}

  defp validate_rows_option(options), do: {:ok, options}

  @spec extract_headers(map()) :: [String.t()]
  defp extract_headers(first_result) do
    first_result
    |> Map.keys()
    |> Enum.reject(&(&1 == :__struct__))
    |> Enum.map(&to_string/1)
  end

  @spec format_rows(list(map()), [String.t()]) :: [[String.t()]]
  defp format_rows(results, headers) do
    Enum.map(results, fn result ->
      Enum.map(headers, fn header ->
        result
        |> get_value(header)
        |> format_value()
      end)
    end)
  end

  @spec get_value(map(), String.t()) :: any()
  defp get_value(result, header) do
    case header do
      header when is_binary(header) ->
        # Try atom key first, then string key
        atom_key = String.to_existing_atom(header)
        Map.get(result, atom_key, Map.get(result, header))

      _ ->
        Map.get(result, header)
    end
  rescue
    # If String.to_existing_atom fails
    _ -> Map.get(result, header)
  end

  # Helper function to format different types of values
  @spec format_value(any()) :: String.t()
  defp format_value(value) when is_atom(value), do: to_string(value)
  defp format_value(value) when is_integer(value), do: to_string(value)
  defp format_value(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)

  defp format_value(value) when is_binary(value) do
    # Escape commas and quotes in string values
    if String.contains?(value, [",", "\""]) do
      "\"#{String.replace(value, "\"", "\"\"")}\""
    else
      value
    end
  end

  defp format_value(nil), do: ""
  defp format_value(value), do: inspect(value)
end
