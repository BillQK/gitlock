defmodule GitlockHolmes.Adapters.Reporters.CsvReporter do
  @moduledoc """
  CSV reporter for formatting analysis results.
  """
  @behaviour GitlockHolmes.Ports.ReportPort

  @type report_options :: %{optional(:rows) => non_neg_integer()}

  @impl true
  @spec report(list(map()), report_options()) :: {:ok, String.t()} | {:error, String.t()}
  def report(results, options) do
    # Determine headers dynamically from the first result
    headers =
      case List.first(results) do
        # Default if no results
        nil -> ["entity", "revisions", "risk_factor"]
        first -> first |> Map.keys() |> Enum.map(&to_string/1)
      end

    # Apply row limit if specified
    limited_results =
      if options[:rows],
        do: Enum.take(results, options[:rows]),
        else: results

    # Convert each result to a list of values in the same order as headers
    rows =
      Enum.map(limited_results, fn result ->
        Enum.map(headers, fn header ->
          format_value(Map.get(result, String.to_existing_atom(header)))
        end)
      end)

    # Format as CSV
    csv_content =
      [headers | rows]
      |> Enum.map_join("\n", &Enum.join(&1, ","))

    {:ok, csv_content}
  end

  # Helper function to format different types of values
  @spec format_value(any()) :: String.t()
  defp format_value(value) when is_atom(value), do: to_string(value)
  defp format_value(value) when is_integer(value), do: to_string(value)
  defp format_value(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 2)
  defp format_value(value) when is_binary(value), do: value
  defp format_value(nil), do: ""
  defp format_value(value), do: inspect(value)
end

