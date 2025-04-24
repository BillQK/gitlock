defmodule GitlockHolmes.Domain.Services.CoupledHotspotAnalysis do
  alias GitlockHolmes.Domain.Services.{HotspotDetection, CouplingDetection}
  alias GitlockHolmes.Domain.Entities.{Commit, ComplexityMetrics}

  @type combined_risk :: %{
          entity: String.t(),
          coupled: String.t(),
          combined_risk_score: float(),
          trend: float(),
          individual_risks: %{String.t() => float()}
        }

  @spec detect_combined([Commit.t()], %{String.t() => ComplexityMetrics.t()}) :: [combined_risk()]
  def detect_combined(commits, complexity_metrics \\ %{}) do
    hotspots = HotspotDetection.detect_hotspots(commits, complexity_metrics)
    couplings = CouplingDetection.detect_couplings(commits)

    hotspot_map = Map.new(hotspots, &{&1.entity, &1})

    couplings
    |> Enum.filter(fn %{entity: a, coupled: b} ->
      Map.has_key?(hotspot_map, a) and Map.has_key?(hotspot_map, b)
    end)
    |> Enum.map(fn %{entity: a, coupled: b, trend: trend} = _coupling ->
      risk_a = hotspot_map[a].risk_score
      risk_b = hotspot_map[b].risk_score

      %{
        entity: a,
        coupled: b,
        trend: trend,
        combined_risk_score: risk_a * risk_b,
        individual_risks: %{a => risk_a, b => risk_b}
      }
    end)
    |> Enum.sort_by(& &1.combined_risk_score, :desc)
  end
end
