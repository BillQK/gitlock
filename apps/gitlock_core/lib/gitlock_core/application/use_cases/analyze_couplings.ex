defmodule GitlockCore.Application.UseCases.AnalyzeCouplings do
  use GitlockCore.Application.UseCase

  alias GitlockCore.Domain.Services.{FileHistoryService, CouplingDetection}

  @impl true
  def resolve_dependencies(options) do
    with {:ok, vcs} <- AdapterRegistry.get_adapter(:vcs, options[:vcs] || "git"),
         {:ok, reporter} <- AdapterRegistry.get_adapter(:reporter, options[:format] || "csv") do
      {:ok, %{vcs: vcs, reporter: reporter}}
    end
  end

  @impl true
  def run_domain_logic(repo_path, deps, options) do
    with {:ok, commits} <- deps.vcs.get_commit_history(repo_path, options) do
      min_coupling = Map.get(options, :min_coupling, 1.0)
      min_windows = Map.get(options, :min_windows, 5)

      history = FileHistoryService.build_history(commits)
      normalizes = FileHistoryService.normalize_commits(commits, history)

      results = CouplingDetection.detect_couplings(normalizes, min_coupling, min_windows)
      {:ok, results}
    end
  end

  @impl true
  def format_result(results, deps, options) do
    deps.reporter.report(results, options)
  end
end
