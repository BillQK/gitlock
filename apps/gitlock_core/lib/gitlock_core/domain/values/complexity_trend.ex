defmodule GitlockCore.Domain.Values.ComplexityTrend do
  @moduledoc """
  Represents the complexity trajectory of a file over time.

  Each trend contains a series of data points showing how a file's
  complexity and size have evolved. The trend direction and magnitude
  indicate whether the file is getting harder to maintain.
  """

  @type data_point :: %{
          date: Date.t(),
          revision: String.t(),
          complexity: non_neg_integer(),
          loc: non_neg_integer()
        }

  @type direction :: :rising | :stable | :declining

  @type t :: %__MODULE__{
          entity: String.t(),
          points: [data_point()],
          direction: direction(),
          complexity_change: float(),
          complexity_start: non_neg_integer(),
          complexity_end: non_neg_integer(),
          loc_change: float(),
          num_samples: non_neg_integer()
        }

  @enforce_keys [:entity]
  defstruct [
    :entity,
    points: [],
    direction: :stable,
    complexity_change: 0.0,
    complexity_start: 0,
    complexity_end: 0,
    loc_change: 0.0,
    num_samples: 0
  ]

  @doc """
  Creates a ComplexityTrend from a list of data points.

  Calculates direction and change metrics from the points.
  """
  @spec from_points(String.t(), [data_point()]) :: t()
  def from_points(entity, []) do
    %__MODULE__{entity: entity}
  end

  def from_points(entity, points) when length(points) == 1 do
    [p] = points

    %__MODULE__{
      entity: entity,
      points: points,
      direction: :stable,
      complexity_change: 0.0,
      complexity_start: p.complexity,
      complexity_end: p.complexity,
      loc_change: 0.0,
      num_samples: 1
    }
  end

  def from_points(entity, points) do
    sorted = Enum.sort_by(points, & &1.date, Date)
    first = List.first(sorted)
    last = List.last(sorted)

    complexity_change = percentage_change(first.complexity, last.complexity)
    loc_change = percentage_change(first.loc, last.loc)
    direction = classify_direction(complexity_change)

    %__MODULE__{
      entity: entity,
      points: sorted,
      direction: direction,
      complexity_change: Float.round(complexity_change, 1),
      complexity_start: first.complexity,
      complexity_end: last.complexity,
      loc_change: Float.round(loc_change, 1),
      num_samples: length(sorted)
    }
  end

  defp percentage_change(0, 0), do: 0.0
  defp percentage_change(0, _to), do: 100.0

  defp percentage_change(from, to) do
    (to - from) / from * 100.0
  end

  defp classify_direction(change) when change > 15.0, do: :rising
  defp classify_direction(change) when change < -15.0, do: :declining
  defp classify_direction(_), do: :stable
end
