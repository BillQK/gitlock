defmodule GitlockHolmesCore.Core.Investigations.Methodology.IdentifyBlastRadius do
  @moduledoc """
  Investigation that analyzes the blast radius of changing specific files.
  """
  alias GitlockHolmesCore.Domain.Values.ChangeImpact
  alias GitlockHolmesCore.Domain.Services.ChangeAnalyzer
  alias GitlockHolmesCore.Domain.Services.FileGraphBuilder
  use GitlockHolmesCore.Core.Investigations.Investigation, complexity: true

  @impl true
  def analyze(commits, complexity_map, options) do
    target_files = options[:target_files] || []

    if Enum.empty?(target_files),
      do: raise("Non target_files specified. Use --target-files options")

    graph = FileGraphBuilder.create_from_commits(commits, complexity_map, options)

    impacts = ChangeAnalyzer.analyze_changes(target_files, graph, options)
    IO.inspect(impacts, pretty: true)

    format_results(impacts, options)
  end

  defp format_results(impacts, options) do
    format = Map.get(options, :format, "summary")

    case format do
      "json" ->
        Enum.map(impacts, &ChangeImpact.to_map/1)

      "summary" ->
        Enum.map(impacts, &format_summary/1)

      _ ->
        Enum.map(impacts, &format_summary/1)
    end
  end

  defp format_summary(impact) do
    %{
      entity: impact.entity,
      risk_score: impact.risk_score,
      impact_severity: impact.impact_severity,
      affected_files_count: length(impact.affected_files),
      affected_components_count: map_size(impact.affected_components),
      suggested_reviewers: impact.suggested_reviewers
    }
  end
end
