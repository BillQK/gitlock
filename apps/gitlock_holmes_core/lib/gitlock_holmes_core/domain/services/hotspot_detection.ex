defmodule GitlockHolmesCore.Domain.Services.HotspotDetection do
  @moduledoc """
  Service for detecting hotspots in the codebase.
  """
  alias GitlockHolmesCore.Domain.Entities.Commit
  alias GitlockHolmesCore.Domain.Values.{FileChange, ComplexityMetrics, Hotspot}

  @doc """
  Identifies hotspots by analyzing revision frequency.

  When complexity_metrics are provided, it includes complexity factors in risk assessment.

  ## Parameters
    * `commits` - List of commits to analyze
    * `complexity_metrics` - Optional map of file paths to complexity metrics
    
  ## Returns
    A list of hotspots sorted by risk (highest risk first)
  """
  @spec detect_hotspots([Commit.t()], %{String.t() => ComplexityMetrics.t()}) :: [Hotspot]
  def detect_hotspots(commits, complexity_metrics \\ %{}) do
    # Extract all file changes
    file_changes =
      commits
      |> Enum.flat_map(fn %Commit{file_changes: changes} -> changes end)

    # Group by entity (file path) and count revisions
    file_changes
    |> Enum.group_by(fn %FileChange{entity: entity} -> entity end)
    |> Enum.map(fn {entity, changes} ->
      # Get complexity metrics if available
      metrics = Map.get(complexity_metrics, entity)
      complexity = if metrics, do: metrics.cyclomatic_complexity, else: 1
      loc = if metrics, do: metrics.loc, else: 0

      # Calculate risk based on both change frequency and complexity
      risk_score = calculate_risk_score(changes, complexity, loc)

      %Hotspot{
        entity: entity,
        revisions: length(changes),
        complexity: complexity,
        loc: loc,
        risk_score: risk_score,
        risk_factor: risk_level_from_score(risk_score)
      }
    end)
    |> Enum.sort_by(fn %{risk_score: score} -> score end, :desc)
  end

  @doc """
  Calculates a risk score based on change frequency and complexity.

  The formula weighs both factors to identify files that are both complex
  and frequently changed.
  """
  @spec calculate_risk_score([FileChange.t()], non_neg_integer(), non_neg_integer()) :: float()
  def calculate_risk_score(changes, complexity, loc) do
    revisions = length(changes)

    # Base score from revisions
    revision_factor = :math.log(revisions + 1) / :math.log(10)

    # Complexity factor - higher complexity increases risk
    complexity_factor = complexity / 10

    # Size factor - larger files with many changes are riskier
    size_factor = :math.log(loc + 1) / :math.log(100)

    # Combined score giving weight to all factors
    revision_factor * (1 + complexity_factor) * (1 + size_factor)
  end

  @doc """
  Determines risk level based on calculated score.
  """
  @spec risk_level_from_score(float()) :: Hotspot.risk_factor()
  def risk_level_from_score(score) when score > 2.0, do: :high
  def risk_level_from_score(score) when score > 1.0, do: :medium
  def risk_level_from_score(_), do: :low
end
