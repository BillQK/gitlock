defmodule GitlockCore.Domain.Values.CombinedRisk do
  @moduledoc """
  Value object representing the combined risk analysis between two coupled files.

  This immutable structure represents the risk assessment when two files are both
  risky individually and strongly coupled together.
  """

  @type t :: %__MODULE__{
          entity: String.t(),
          coupled: String.t(),
          combined_risk_score: float(),
          trend: float(),
          individual_risks: %{String.t() => float()}
        }

  defstruct [:entity, :coupled, :combined_risk_score, :trend, :individual_risks]

  @doc """
  Creates a new combined risk value object.

  ## Parameters
    * `entity` - Primary file in the pair
    * `coupled` - Coupled file that changes with the primary file
    * `combined_risk_score` - Product of the individual risk scores
    * `trend` - Change in coupling over time (positive = increasing)
    * `individual_risks` - Map of file path to individual risk score
    
  ## Returns
    A new immutable CombinedRisk value object
  """
  @spec new(String.t(), String.t(), float(), float(), %{String.t() => float()}) :: t()
  def new(entity, coupled, combined_risk_score, trend, individual_risks) do
    %__MODULE__{
      entity: entity,
      coupled: coupled,
      combined_risk_score: combined_risk_score,
      trend: trend,
      individual_risks: individual_risks
    }
  end

  @doc """
  Determines the risk level category based on the combined risk score.

  ## Returns
    One of `:critical`, `:high`, `:medium`, or `:low`
  """
  @spec risk_category(t()) :: :critical | :high | :medium | :low
  def risk_category(%__MODULE__{combined_risk_score: score}) when score > 15.0, do: :critical
  def risk_category(%__MODULE__{combined_risk_score: score}) when score > 8.0, do: :high
  def risk_category(%__MODULE__{combined_risk_score: score}) when score > 4.0, do: :medium
  def risk_category(_), do: :low

  @doc """
  Checks if this represents an increasing risk (positive trend).

  ## Returns
    `true` if trend is positive, otherwise `false`
  """
  @spec increasing_risk?(t()) :: boolean()
  def increasing_risk?(%__MODULE__{trend: trend}), do: trend > 0

  @doc """
  Checks if two combined risk objects are equal in value.

  Two combined risks are equal when all their attributes are equal.
  """
  @spec equal?(t(), t()) :: boolean()
  def equal?(%__MODULE__{} = a, %__MODULE__{} = b) do
    a.entity == b.entity &&
      a.coupled == b.coupled &&
      a.combined_risk_score == b.combined_risk_score &&
      a.trend == b.trend &&
      Map.equal?(a.individual_risks, b.individual_risks)
  end

  @doc """
  Creates a human-readable string representation of the combined risk.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = risk) do
    # Default values for nil fields
    entity = risk.entity || "unknown"
    coupled = risk.coupled || "unknown"
    # Handle nil values for score
    score = risk.combined_risk_score || 0.0
    # Handle nil values for trend
    trend = risk.trend || 0.0
    trend_sign = if trend >= 0, do: "+", else: ""

    "#{Path.basename(entity)} & #{Path.basename(coupled)}: " <>
      "score=#{Float.round(score, 1)}, " <>
      "trend=#{trend_sign}#{Float.round(trend, 1)}, " <>
      "category=#{risk_category(risk)}"
  end
end
