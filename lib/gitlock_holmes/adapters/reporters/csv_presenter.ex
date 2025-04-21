defmodule GitlockHolmes.Adapters.Reporters.CsvReporter do
  @moduledoc """
  CSV reporter for formatting analysis results.
  """

  @behaviour GitlockHolmes.Ports.ReportPort

  @type report_options :: %{optional(:rows) => non_neg_integer()}
  @type result_item :: %{
          entity: String.t(),
          revisions: non_neg_integer(),
          risk_factor: atom()
        }

  @impl true
  @spec report([result_item()], report_options()) :: {:ok, String.t()} | {:error, String.t()}
  def report(results, options) do
    headers = ["entity", "revisions", "risk_factor"]

    # Apply row limit if specified
    limited_results =
      if options[:rows],
        do: Enum.take(results, options[:rows]),
        else: results

    # Format as CSV
    rows =
      Enum.map(limited_results, fn %{entity: e, revisions: r, risk_factor: rf} ->
        [e, to_string(r), to_string(rf)]
      end)

    csv_content =
      [headers | rows]
      |> Enum.map_join("\n", &Enum.join(&1, ","))

    {:ok, csv_content}
  end
end
