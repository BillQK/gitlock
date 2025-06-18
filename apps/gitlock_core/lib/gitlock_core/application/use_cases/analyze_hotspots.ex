defmodule GitlockCore.Application.UseCases.AnalyzeHotspots do
  use GitlockCore.Application.UseCase

  alias GitlockCore.Domain.Services.{HotspotDetection, ComplexityCollector, FileHistoryService}
  alias GitlockCore.Infrastructure.Workspace

  @impl true
  def resolve_dependencies(options) do
    with {:ok, vcs} <- AdapterRegistry.get_adapter(:vcs, options[:vcs] || "git"),
         {:ok, reporter} <- AdapterRegistry.get_adapter(:reporter, options[:format] || "csv"),
         {:ok, analyzer} <- resolve_complexity_analyzer(options) do
      {:ok, %{vcs: vcs, reporter: reporter, analyzer: analyzer}}
    end
  end

  @impl true
  def run_domain_logic(repo_path, deps, options) do
    with {:ok, commits} <- deps.vcs.get_commit_history(repo_path, options),
         complexity_map <- get_complexity_map(deps.analyzer, repo_path) do
      history = FileHistoryService.build_history(commits)
      normalizes = FileHistoryService.normalize_commits(commits, history)

      results = HotspotDetection.detect_hotspots(normalizes, complexity_map)
      {:ok, results}
    end
  end

  @impl true
  def format_result(results, deps, options) do
    deps.reporter.report(results, options)
  end

  defp resolve_complexity_analyzer(options) do
    AdapterRegistry.get_adapter(
      :complexity_analyzer,
      options[:complexity_analyzer] || "dispatch"
    )
  end

  defp get_complexity_map(analyzer, repo_path) do
    ComplexityCollector.collect_complexity(analyzer, repo_path)
  end
end
