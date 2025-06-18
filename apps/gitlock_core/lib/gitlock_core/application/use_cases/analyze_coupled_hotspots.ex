defmodule GitlockCore.Application.UseCases.AnalyzeCoupledHotspots do
  use GitlockCore.Application.UseCase

  alias GitlockCore.Domain.Services.{
    CoupledHotspotAnalysis,
    ComplexityCollector,
    FileHistoryService
  }

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

      coupled_hotspots = CoupledHotspotAnalysis.detect_combined(normalizes, complexity_map)
      {:ok, coupled_hotspots}
    end
  end

  @impl true
  def format_result(coupled_hotspots, deps, options) do
    deps.reporter.report(coupled_hotspots, options)
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
