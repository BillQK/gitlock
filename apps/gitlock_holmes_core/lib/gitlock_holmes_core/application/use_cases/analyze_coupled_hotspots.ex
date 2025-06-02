defmodule GitlockHolmesCore.Application.UseCases.AnalyzeCoupledHotspots do
  use GitlockHolmesCore.Application.UseCase

  alias GitlockHolmesCore.Domain.Services.{CoupledHotspotAnalysis, ComplexityCollector}

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
         complexity_map <- get_complexity_map(deps.analyzer, options) do
      coupled_hotspots = CoupledHotspotAnalysis.detect_combined(commits, complexity_map)
      {:ok, coupled_hotspots}
    end
  end

  @impl true
  def format_result(coupled_hotspots, deps, options) do
    deps.reporter.report(coupled_hotspots, options)
  end

  defp resolve_complexity_analyzer(options) do
    if Map.has_key?(options, :dir) do
      AdapterRegistry.get_adapter(
        :complexity_analyzer,
        options[:complexity_analyzer] || "dispatch"
      )
    else
      {:error, "Directory path required for coupled hotspot analysis"}
    end
  end

  defp get_complexity_map(analyzer, options) do
    case Map.get(options, :dir) do
      nil -> %{}
      dir -> ComplexityCollector.collect_complexity(analyzer, dir)
    end
  end
end
