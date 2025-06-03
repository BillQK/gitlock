defmodule GitlockCore.Domain.Values.CouplingMetrics do
  @moduledoc """
  Value object representing temporal coupling between two files.

  - entity: The first file in the coupling relationship
  - coupled: The second file that changes together with the first one
  - degree: Coupling strength (percentage of co-changes)
  - windows: Number of commits where both files changed together
  - trend: Change in coupling over time (higher values indicate increasing coupling)
  """

  @type t :: %__MODULE__{
          entity: String.t(),
          coupled: String.t(),
          degree: float(),
          windows: non_neg_integer(),
          trend: float()
        }

  defstruct [:entity, :coupled, :degree, :windows, :trend]

  def new(entity, coupled, degree, windows, trend) do
    %__MODULE__{
      entity: entity,
      coupled: coupled,
      degree: degree,
      windows: windows,
      trend: trend
    }
  end
end
