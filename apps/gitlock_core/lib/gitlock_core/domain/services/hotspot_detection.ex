defmodule GitlockCore.Domain.Services.HotspotDetection do
  @moduledoc """
  Service for detecting hotspots in the codebase.
  """
  alias GitlockCore.Domain.Entities.Commit
  alias GitlockCore.Domain.Values.{FileChange, ComplexityMetrics, Hotspot}

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
    hotspots =
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
          risk_factor: :low
        }
      end)
      |> Enum.sort_by(fn %{risk_score: score} -> score end, :desc)

    normalize_scores(hotspots)
  end

  @doc """
  Normalizes raw risk scores to 0-100 scale and calculates percentiles.

  Uses min-max normalization on log-scaled scores to prevent extreme outliers
  from compressing the rest of the distribution.
  """
  @spec normalize_scores([Hotspot.t()]) :: [Hotspot.t()]
  def normalize_scores([]), do: []

  def normalize_scores([single] = _hotspots) do
    [%{single | normalized_score: 100.0, percentile: 100.0, risk_factor: risk_level_from_normalized(100.0)}]
  end

  def normalize_scores(hotspots) do
    total = length(hotspots)

    # Use log scale to prevent outliers from compressing the distribution
    log_scores = Enum.map(hotspots, fn h -> :math.log(h.risk_score + 1) end)
    min_log = Enum.min(log_scores)
    max_log = Enum.max(log_scores)
    range = max_log - min_log

    hotspots
    |> Enum.with_index()
    |> Enum.map(fn {hotspot, rank} ->
      # Normalized score: 0-100 via min-max on log scale
      normalized =
        if range == 0 do
          50.0
        else
          log_score = :math.log(hotspot.risk_score + 1)
          (log_score - min_log) / range * 100.0
        end

      # Percentile: what percentage of files score lower than this one
      # rank 0 = highest score = highest percentile
      percentile = (total - rank - 1) / max(total - 1, 1) * 100.0

      %{hotspot |
        normalized_score: Float.round(normalized, 1),
        percentile: Float.round(percentile, 1),
        risk_factor: risk_level_from_normalized(normalized)
      }
    end)
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
  Determines risk level based on normalized 0-100 score.

  - High: top 20% (score > 70)
  - Medium: middle tier (score > 40)
  - Low: bottom tier
  """
  @spec risk_level_from_normalized(float()) :: Hotspot.risk_factor()
  def risk_level_from_normalized(score) when score > 70.0, do: :high
  def risk_level_from_normalized(score) when score > 40.0, do: :medium
  def risk_level_from_normalized(_), do: :low

  # Keep for backward compatibility
  @spec risk_level_from_score(float()) :: Hotspot.risk_factor()
  def risk_level_from_score(score) when score > 2.0, do: :high
  def risk_level_from_score(score) when score > 1.0, do: :medium
  def risk_level_from_score(_), do: :low
end
