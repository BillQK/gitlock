defmodule GitlockCore.Domain.Services.CoupledHotspotAnalysis do
  @moduledoc """
  Service for detecting *coupled hotspots* in a codebase.

  A **coupled hotspot** is a pair of files that are both:
  - Individually risky (frequently changed and/or complex)
  - Frequently changed together (high temporal coupling)

  This service combines hotspot and coupling analysis to identify
  risky dependencies that are likely to cause maintenance or
  architectural pain over time.

  The result includes:
    - Each file in a risky pair
    - The other file it is coupled with
    - A combined risk score (multiplicative risk of both files)
    - A trend value (change in coupling over time)
    - Individual risk scores for both files
  """

  alias GitlockCore.Domain.Values.CombinedRisk
  alias GitlockCore.Domain.Values.ComplexityMetrics
  alias GitlockCore.Domain.Services.{HotspotDetection, CouplingDetection}
  alias GitlockCore.Domain.Entities.{Commit}

  @doc """
  Runs combined analysis to identify coupled hotspots.

  This function performs both hotspot and coupling detection,
  then filters to find file pairs that are both coupled and
  independently risky.

  ## Parameters

    - `commits`: A list of parsed `%Commit{}` structs from version control
    - `complexity_metrics`: Optional map of file paths to complexity scores

  ## Returns

    - A sorted list of coupled hotspot results, with highest combined risk first

  ## Example

      iex> CoupledHotspotAnalysis.detect_combined(commits, complexity_metrics)
      [
        %{
          entity: "lib/foo.ex",
          coupled: "lib/bar.ex",
          trend: 12.5,
          combined_risk_score: 30.25,
          individual_risks: %{"lib/foo.ex" => 5.5, "lib/bar.ex" => 5.5}
        }
      ]

  """
  @spec detect_combined([Commit.t()], %{String.t() => ComplexityMetrics.t()}) :: [
          CombinedRisk.t()
        ]
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

      %CombinedRisk{
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
