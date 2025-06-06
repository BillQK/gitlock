defmodule GitlockCore.Application.UseCases.AnalyzeKnowledgeSilos do
  use GitlockCore.Application.UseCase

  alias GitlockCore.Domain.Services.{KnowledgeSiloDetection, FileHistoryService}

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
      knowledge_silos = KnowledgeSiloDetection.detect_knowledge_silos(normalizes)
      {:ok, knowledge_silos}
    end
  end

  @impl true
  def format_result(knowledge_silos, deps, options) do
    deps.reporter.report(knowledge_silos, options)
  end
end
