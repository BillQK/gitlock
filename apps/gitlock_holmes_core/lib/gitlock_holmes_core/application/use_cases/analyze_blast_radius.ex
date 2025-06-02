defmodule GitlockHolmesCore.Application.UseCases.AnalyzeBlastRadius do
  alias GitlockHolmesCore.Domain.Values.ChangeImpact
  use GitlockHolmesCore.Application.UseCase

  alias GitlockHolmesCore.Domain.Services.{ChangeAnalyzer, FileGraphBuilder, ComplexityCollector}

  @impl true
  def resolve_dependencies(options) do
    with {:ok, vcs} <- AdapterRegistry.get_adapter(:vcs, options[:vcs] || "git"),
         {:ok, reporter} <- AdapterRegistry.get_adapter(:reporter, options[:format] || "csv"),
         {:ok, file_system} <-
           AdapterRegistry.get_adapter(:file_system, options[:file_system] || "local_file_system"),
         {:ok, analyzer} <-
           resolve_complexity_analyzer(options) do
      {:ok, %{vcs: vcs, reporter: reporter, analyzer: analyzer, file_system: file_system}}
    end
  end

  @impl true
  def run_domain_logic(repo_path, deps, options) do
    target_files = options[:target_files] || []

    if Enum.empty?(target_files) do
      {:error, "No target_files specified. Use --target-files option"}
    else
      with {:ok, commits} <- deps.vcs.get_commit_history(repo_path, options),
           complexity_map <- get_complexity_map(deps.analyzer, options),
           active_files <- get_active_files(deps.file_system, options) do
        graph =
          FileGraphBuilder.create_from_commits(commits, complexity_map, active_files, options)

        impacts = ChangeAnalyzer.analyze_changes(target_files, graph, options)

        {:ok, impacts}
      end
    end
  end

  @impl true
  def format_result(results, deps, options) do
    format = Map.get(options, :format, "summary")

    formatted_results =
      case format do
        "json" -> Enum.map(results, &format_as_map/1)
        _ -> Enum.map(results, &format_as_summary/1)
      end

    deps.reporter.report(formatted_results, options)
  end

  defp resolve_complexity_analyzer(options) do
    if Map.has_key?(options, :dir) do
      AdapterRegistry.get_adapter(
        :complexity_analyzer,
        options[:complexity_analyzer] || "dispatch"
      )
    else
      {:error, "Directory path required for blast radius analysis"}
    end
  end

  defp get_complexity_map(analyzer, options) do
    case Map.get(options, :dir) do
      nil -> %{}
      dir -> ComplexityCollector.collect_complexity(analyzer, dir)
    end
  end

  defp get_active_files(file_system, options) do
    base_path = options[:dir] || "."
    files = file_system.list_all_files(base_path)
    MapSet.new(files)
  end

  defp format_as_map(impact) do
    ChangeImpact.to_map(impact)
  end

  defp format_as_summary(impact) do
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
