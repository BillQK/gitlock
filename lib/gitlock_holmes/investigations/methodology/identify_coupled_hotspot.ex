defmodule GitlockHolmes.Investigations.Methodology.IdentifyCoupledHotspots do
  @moduledoc "Use case for identifying coupled hotspots."

  @behaviour GitlockHolmes.Investigations.Investigation

  alias GitlockHolmes.Domain.Services.ComplexityCollector
  alias GitlockHolmes.Domain.Services.CoupledHotspotAnalysis

  @impl true
  def investigate(log_file, vcs_port, reporter_port, analyzer, options \\ %{}) do
    with {:ok, commits} <- vcs_port.get_commit_history(log_file, options),
         complexity_map = ComplexityCollector.collect_complexity(analyzer, options[:dir]),
         results <- CoupledHotspotAnalysis.detect_combined(commits, complexity_map),
         {:ok, output} <- reporter_port.report(results, options) do
      {:ok, output}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
