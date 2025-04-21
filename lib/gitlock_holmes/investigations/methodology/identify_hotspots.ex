defmodule GitlockHolmes.Investigations.Methodology.IdentifyHotspots do
  @moduledoc """
  Use case for identifying hotspots in the codebase.
  """
  alias GitlockHolmes.Domain.Services.HotspotDetection
  alias GitlockHolmes.Domain.Entities.ComplexityMetrics
  @behaviour GitlockHolmes.Investigations.Investigation

  @typedoc "Module implementing the VersionControlPort behavior"
  @type vcs_port :: module()

  @typedoc "Module implementing the ReportPort behavior"
  @type reporter_port :: module()

  @typedoc "Module implementing the ComplexityAnalyzerPort behavior"
  @type complexity_analyzer_port :: module()

  @type investigation_options :: map()
  @type investigation_result :: {:ok, String.t()} | {:error, String.t()}

  @doc """
  Identifies hotspots (frequently changing files) in a codebase.

  ## Parameters
    - log_file: Path to VCS log file
    - vcs_port: Module implementing VersionControlPort
    - reporter_port: Module implementing ReportPort
    - options: Additional options for analysis
  """
  @spec investigate(
          String.t(),
          vcs_port(),
          reporter_port(),
          complexity_analyzer_port(),
          investigation_options()
        ) ::
          investigation_result()
  def investigate(log_file, vcs_port, reporter_port, complexity_port, options \\ %{}) do
    with {:ok, commits} <- vcs_port.get_commit_history(log_file, options),
         complexity_metrics <- build_complexity_map(commits, complexity_port),
         results = HotspotDetection.detect_hotspots(commits, complexity_metrics),
         {:ok, formatted_output} <- reporter_port.report(results, options) do
      {:ok, formatted_output}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp build_complexity_map(commits, complexity_port) do
    commits
    |> Enum.flat_map(& &1.file_changes)
    |> Enum.map(& &1.entity)
    |> Enum.uniq()
    |> Enum.map(fn path ->
      metrics = complexity_port.analyze_file(path)

      {path,
       %ComplexityMetrics{
         file_path: path,
         loc: metrics.loc,
         cyclomatic_complexity: metrics.cyclomatic_complexity
       }}
    end)
    |> Enum.into(%{})
  end
end

