defmodule GitlockHolmesCore.Application.UseCases.AnalyzeKnowledgeSilos do
  use GitlockHolmesCore.Application.UseCase

  alias GitlockHolmesCore.Domain.Services.KnowledgeSiloDetection

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
      knowledge_silos = KnowledgeSiloDetection.detect_knowledge_silos(commits)
      {:ok, knowledge_silos}
    end
  end

  @impl true
  def format_result(knowledge_silos, deps, options) do
    deps.reporter.report(knowledge_silos, options)
  end
end
