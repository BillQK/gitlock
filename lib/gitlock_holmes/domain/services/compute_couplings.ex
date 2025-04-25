defmodule GitlockHolmes.Domain.Services.ComputeCouplings do
  @moduledoc "Calculates coupling metrics between files"

  @typedoc """
  Result of temporal coupling analysis between two files.

  Fields:
  - entity: The first file in the coupling relationship
  - coupled: The second file that changes together with the first one
  - degree: Coupling strength (percentage of co-changes)
  - windows: Number of commits where both files changed together
  - trend: Change in coupling over time (higher values indicate increasing coupling)
  """
  @type coupling_result :: %{
          entity: String.t(),
          coupled: String.t(),
          degree: float(),
          windows: non_neg_integer(),
          trend: float()
        }

  # Calculates the coupling strength, trend, and filters results based on thresholds.
  #
  # ## Parameters
  # - all: Full co-change data map.
  # - early: Early commit co-change data.
  # - recent: Recent commit co-change data.
  # - file_counts: Map of file to total commit counts.
  # - min_coupling: Minimum coupling degree to include a result.
  # - min_windows: Minimum number of co-change windows.
  #
  # ## Returns
  # - List of `coupling_result` sorted by descending degree.
  @spec calculate_coupling_strength(
          %{{String.t(), String.t()} => integer()},
          %{{String.t(), String.t()} => integer()},
          %{{String.t(), String.t()} => integer()},
          %{String.t() => integer()},
          float(),
          integer()
        ) :: [coupling_result()]
  def calculate_coupling_strength(all, early, recent, file_counts, min_coupling, min_windows) do
    Enum.map(all, fn {{file1, file2}, shared} ->
      total1 = Map.get(file_counts, file1, 1)
      total2 = Map.get(file_counts, file2, 1)
      avg = (total1 + total2) / 2.0

      degree = shared / avg * 100.0

      early_shared = Map.get(early, {file1, file2}, 0)
      early_avg = avg / 2
      early_degree = if early_avg > 0, do: early_shared / early_avg * 100.0, else: 0.0

      recent_shared = Map.get(recent, {file1, file2}, 0)
      recent_avg = avg / 2
      recent_degree = if recent_avg > 0, do: recent_shared / recent_avg * 100.0, else: 0.0

      trend = Float.round(recent_degree - early_degree, 1)

      %{
        entity: file1,
        coupled: file2,
        degree: Float.round(degree, 1),
        windows: shared,
        trend: trend
      }
    end)
    |> Enum.filter(fn %{degree: degree, windows: windows} ->
      degree >= min_coupling and windows >= min_windows
    end)
    |> Enum.sort_by(& &1.degree, :desc)
  end
end
