defmodule GitlockCore.Application.UseCaseFactory do
  @moduledoc """
  Factory for creating use case instances
  """

  alias GitlockCore.Application.UseCases.{
    AnalyzeHotspots,
    AnalyzeCouplings,
    AnalyzeCoupledHotspots,
    AnalyzeKnowledgeSilos,
    AnalyzeBlastRadius,
    AnalyzeCodeAge,
    GetSummary
  }

  @use_cases %{
    hotspots: AnalyzeHotspots,
    couplings: AnalyzeCouplings,
    coupled_hotspots: AnalyzeCoupledHotspots,
    knowledge_silos: AnalyzeKnowledgeSilos,
    blast_radius: AnalyzeBlastRadius,
    code_age: AnalyzeCodeAge,
    summary: GetSummary
  }

  def create_use_case(investigation_type) do
    case Map.get(@use_cases, investigation_type) do
      nil -> {:error, "Unknown investigation type: #{investigation_type}"}
      use_case_module -> {:ok, use_case_module}
    end
  end

  def available_investigations, do: Map.keys(@use_cases)
end
