defmodule GitlockCore.Domain.Values.Hotspot do
  @moduledoc """
  Value object representing a hotspot in the codebase.

  A hotspot is a file that exhibits signs of risk based on both its change 
  history and complexity metrics. Hotspots require particular attention during
  development and may benefit from refactoring.

  This struct contains the following information:
  * `entity` - The file path identifier
  * `revisions` - Number of times the file has been modified
  * `complexity` - Cyclomatic complexity measure of the file
  * `loc` - Lines of code in the file
  * `risk_factor` - Categorized risk level (:high, :medium, or :low)
  * `risk_score` - Calculated numeric risk score

  This struct is used within the domain layer for calculations and analysis.
  When passing through ports to external adapters, it should be converted to a
  plain map to maintain a clean boundary between domain and external layers.
  """

  @type risk_factor :: :high | :medium | :low
  @type t :: %__MODULE__{
          entity: String.t(),
          revisions: non_neg_integer(),
          complexity: non_neg_integer(),
          loc: non_neg_integer(),
          risk_factor: risk_factor(),
          risk_score: float(),
          normalized_score: float(),
          percentile: float()
        }

  defstruct [:entity, :revisions, :complexity, :loc, :risk_factor, :risk_score,
             normalized_score: 0.0, percentile: 0.0]

  @doc """
  Creates a new hotspot value object.

  ## Parameters
    * `entity` - File path of the hotspot
    * `revisions` - Number of times the file has been changed
    * `complexity` - Cyclomatic complexity measure
    * `loc` - Lines of code 
    * `risk_factor` - Assessed risk level
    * `risk_score` - Calculated risk score
    
  ## Returns
    A new immutable Hotspot struct
  """
  def new(entity, revisions, complexity, loc, risk_factor, risk_score, opts \\ []) do
    %__MODULE__{
      entity: entity,
      revisions: revisions,
      complexity: complexity,
      loc: loc,
      risk_factor: risk_factor,
      risk_score: risk_score,
      normalized_score: Keyword.get(opts, :normalized_score, 0.0),
      percentile: Keyword.get(opts, :percentile, 0.0)
    }
  end

  @doc """
  Converts the struct to a plain map for serialization at the port boundary.

  ## Returns
    A plain map representation without the __struct__ field
  """
  def to_map(%__MODULE__{} = hotspot) do
    Map.from_struct(hotspot)
  end

  @doc """
  Determines if this hotspot is considered high risk.

  ## Returns
    `true` if the risk_factor is :high, otherwise `false`
  """
  def high_risk?(%__MODULE__{risk_factor: :high}), do: true
  def high_risk?(_), do: false

  @doc """
  Returns a string representation of the hotspot for display purposes.

  ## Returns
    A formatted string summarizing the hotspot
  """
  def to_string(%__MODULE__{} = hotspot) do
    risk_text =
      case hotspot.risk_factor do
        :high -> "HIGH RISK"
        :medium -> "Medium risk"
        :low -> "Low risk"
      end

    "#{Path.basename(hotspot.entity)}: #{hotspot.revisions} revisions, " <>
      "complexity: #{hotspot.complexity}, " <>
      "score: #{Float.round(hotspot.normalized_score, 1)}/100 " <>
      "(top #{Float.round(100.0 - hotspot.percentile, 1)}%) (#{risk_text})"
  end
end
