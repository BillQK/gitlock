defmodule GitlockHolmes.Investigations.Methodology.IdentifyHotspots do
  @moduledoc """
  Use case for identifying hotspots in the codebase.
  """
  alias GitlockHolmes.Domain.Services.ComplexityCollector
  alias GitlockHolmes.Domain.Services.HotspotDetection
  @behaviour GitlockHolmes.Investigations.Investigation

  @typedoc "Module implementing the VersionControlPort behavior"
  @type vcs_port :: module()

  @typedoc "Module implementing the ReportPort behavior"
  @type reporter_port :: module()

  @typedoc "Module implementing the ComplexityAnalyzerPort behavior"
  @type analyzer_port :: module()

  @type investigation_options :: map()
  @type investigation_result :: {:ok, String.t()} | {:error, String.t()}

  @doc """
  Identifies hotspots (frequently changing files) in a codebase.

  ## Parameters
    - log_file: Path to VCS log file
    - vcs_port: Module implementing VersionControlPort
    - reporter_port: Module implementing ReportPort
    - analyzer_port: Module implement ComplexityAnalyzerPort
    - options: Additional options for analysis
  """
  @spec investigate(
          String.t(),
          vcs_port(),
          reporter_port(),
          analyzer_port(),
          investigation_options()
        ) ::
          investigation_result()
  def investigate(log_file, vcs_port, reporter_port, analyzer, options \\ %{}) do
    with {:ok, commits} <- vcs_port.get_commit_history(log_file, options),
         complexity_map = ComplexityCollector.collect_complexity(analyzer, options[:dir]),
         results = HotspotDetection.detect_hotspots(commits, complexity_map),
         {:ok, formatted_output} <- reporter_port.report(results, options) do
      {:ok, formatted_output}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
