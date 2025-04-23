defmodule GitlockHolmes.Domain.Services.CouplingDetection do
  @moduledoc """
  Service for analyzing temporal coupling between files.

  Temporal coupling occurs when files tend to change together over time.
  High coupling indicates a potential dependency between files that may not
  be obvious from the code structure alone.
  """
  alias GitlockHolmes.Domain.Entities.Commit

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

  @doc """
  Detects temporal couplings between files based on commit co-changes.

  ## Parameters
  - commits: A list of `Commit` structs representing the commit history.
  - min_coupling: The minimum coupling degree (%) to include a pair (default: 1.0).
  - min_windows: The minimum number of co-change commits required to include a pair (default: 5).

  ## Returns
  - A list of coupling results sorted by descending degree.
  """
  @spec detect_couplings([Commit.t()], float(), pos_integer()) :: [coupling_result()]
  def detect_couplings(commits, min_coupling \\ 1.0, min_windows \\ 5) do
    {full, early, recent} = split_commits(commits)

    {coupling_data, file_commit_counts} = analyze_commits(full)
    {early_data, _} = analyze_commits(early)
    {recent_data, _} = analyze_commits(recent)

    calculate_coupling_strength(
      coupling_data,
      early_data,
      recent_data,
      file_commit_counts,
      min_coupling,
      min_windows
    )
  end

  # Splits a list of commits into full, early (first half), and recent (second half).
  @spec split_commits([Commit.t()]) :: {[Commit.t()], [Commit.t()], [Commit.t()]}
  defp split_commits(commits) do
    sorted = Enum.sort_by(commits, & &1.date)
    mid = div(length(sorted), 2)
    {early, recent} = Enum.split(sorted, mid)
    {sorted, early, recent}
  end

  # Analyzes co-change data for a given list of commits.
  #
  # Returns a tuple of:
  # - A map of file pairs to their co-change count.
  # - A map of individual file commit counts.
  @spec analyze_commits([Commit.t()]) ::
          {%{{String.t(), String.t()} => non_neg_integer()}, %{String.t() => non_neg_integer()}}
  defp analyze_commits(commits) do
    Enum.reduce(commits, {%{}, %{}}, fn commit, {coupling_acc, count_acc} ->
      files =
        commit.file_changes
        |> Enum.map(& &1.entity)
        |> Enum.uniq()

      updated_coupling =
        for {file1, file2} <- generate_file_pairs(files), reduce: coupling_acc do
          acc ->
            pair_key = if file1 < file2, do: {file1, file2}, else: {file2, file1}
            Map.update(acc, pair_key, 1, &(&1 + 1))
        end

      updated_counts =
        Enum.reduce(files, count_acc, fn file, acc ->
          Map.update(acc, file, 1, &(&1 + 1))
        end)

      {updated_coupling, updated_counts}
    end)
  end

  # Generates all unique pairs of files from a list (combinations).
  @spec generate_file_pairs([String.t()]) :: [{String.t(), String.t()}]
  defp generate_file_pairs(files) when length(files) <= 1, do: []
  defp generate_file_pairs(files), do: for(x <- files, y <- files, x < y, do: {x, y})

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
  defp calculate_coupling_strength(all, early, recent, file_counts, min_coupling, min_windows) do
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
