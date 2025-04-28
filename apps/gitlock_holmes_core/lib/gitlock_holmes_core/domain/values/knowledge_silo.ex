defmodule GitlockHolmesCore.Domain.Values.KnowledgeSilo do
  @moduledoc """
  Value object representing a knowledge silo in the codebase.

  A knowledge silo exists when a single developer has contributed a disproportionate 
  amount of code to a file or component, creating a potential risk if that 
  developer leaves the team.
  """

  @type t :: %__MODULE__{
          entity: String.t(),
          main_author: String.t(),
          ownership_ratio: float(),
          num_authors: integer(),
          num_commits: integer(),
          risk_level: :high | :medium | :low
        }

  defstruct [:entity, :main_author, :ownership_ratio, :num_authors, :num_commits, :risk_level]

  @doc """
  Creates a new knowledge silo value object.

  ## Parameters
    * `entity` - Path of the file with concentrated knowledge
    * `main_author` - Name of the developer with the most knowledge
    * `ownership_ratio` - Percentage of commits by the main author
    * `num_authors` - Total number of unique authors who modified the file
    * `num_commits` - Total number of commits to the file
    * `risk_level` - Calculated risk level (:high, :medium, or :low)
    
  ## Returns
    A new KnowledgeSilo struct
  """
  @spec new(String.t(), String.t(), float(), integer(), integer(), atom()) :: t()
  def new(entity, main_author, ownership_ratio, num_authors, num_commits, risk_level) do
    %__MODULE__{
      entity: entity,
      main_author: main_author,
      ownership_ratio: ownership_ratio,
      num_authors: num_authors,
      num_commits: num_commits,
      risk_level: risk_level
    }
  end

  @doc """
  Determines if the knowledge silo represents a high risk.

  ## Returns
    `true` if risk_level is :high, otherwise `false`
  """
  @spec high_risk?(t()) :: boolean()
  def high_risk?(%__MODULE__{risk_level: :high}), do: true
  def high_risk?(_), do: false

  @doc """
  Returns the ownership percentage as a formatted string.

  ## Returns
    A string representation of the ownership percentage (e.g. "85.5%")
  """
  @spec ownership_percentage(t()) :: String.t()
  def ownership_percentage(%__MODULE__{ownership_ratio: ratio}) do
    "#{ratio}%"
  end

  @doc """
  Creates a human-readable string representation of the knowledge silo.

  ## Returns
    A descriptive string about the knowledge silo
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = silo) do
    risk_text =
      case silo.risk_level do
        :high -> "HIGH RISK"
        :medium -> "Medium risk"
        :low -> "Low risk"
      end

    "#{Path.basename(silo.entity)}: #{ownership_percentage(silo)} owned by #{silo.main_author} (#{risk_text})"
  end
end
