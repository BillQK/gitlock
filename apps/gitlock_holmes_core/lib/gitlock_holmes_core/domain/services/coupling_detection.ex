defmodule GitlockHolmesCore.Domain.Services.CouplingDetection do
  @moduledoc """
  Service for analyzing temporal coupling between files.

  Temporal coupling occurs when files tend to change together over time.
  High coupling indicates a potential dependency between files that may not
  be obvious from the code structure alone.
  """
  alias GitlockHolmesCore.Domain.Values.CouplingMetrics
  alias GitlockHolmesCore.Domain.Services.{CommitSplitter, CochangeAnalyzer, ComputeCouplings}
  alias GitlockHolmesCore.Domain.Entities.Commit

  @doc """
  Detects temporal couplings between files based on commit co-changes.

  ## Parameters
  - commits: A list of `Commit` structs representing the commit history.
  - min_coupling: The minimum coupling degree (%) to include a pair (default: 1.0).
  - min_windows: The minimum number of co-change commits required to include a pair (default: 5).

  ## Returns
  - A list of coupling results sorted by descending degree.
  - Returns empty list for empty input or insufficient data.
  """
  @spec detect_couplings([Commit.t()], float(), pos_integer()) :: [CouplingMetrics.t()]
  def detect_couplings(commits, min_coupling \\ 1.0, min_windows \\ 5)

  def detect_couplings([], _min_coupling, _min_windows), do: []

  def detect_couplings(commits, _min_coupling, _min_windows) when length(commits) < 2 do
    []
  end

  def detect_couplings(commits, min_coupling, min_windows) do
    {full, early, recent} = CommitSplitter.split_commits(commits)

    {coupling_data, file_commit_counts} = CochangeAnalyzer.analyze_commits(full)

    {early_data, _} = CochangeAnalyzer.analyze_commits(early)

    {recent_data, _} = CochangeAnalyzer.analyze_commits(recent)

    ComputeCouplings.calculate_coupling_strength(
      coupling_data,
      early_data,
      recent_data,
      file_commit_counts,
      min_coupling,
      min_windows
    )
  end
end
