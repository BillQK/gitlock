defmodule GitlockCore.Application.UseCases.GetSummary do
  use GitlockCore.Application.UseCase

  alias GitlockCore.Domain.Services.{Summary, FileHistoryService}

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
      history = FileHistoryService.build_history(commits)
      normalizes = FileHistoryService.normalize_commits(commits, history)
      summary_stats = Summary.summarize(normalizes)
      {:ok, summary_stats}
    end
  end

  @impl true
  def format_result(summary_stats, deps, options) do
    deps.reporter.report(summary_stats, options)
  end
end
