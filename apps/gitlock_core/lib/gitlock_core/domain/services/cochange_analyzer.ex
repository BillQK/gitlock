defmodule GitlockCore.Domain.Services.CochangeAnalyzer do
  @moduledoc "Analyzes file co-changes in commits"

  alias GitlockCore.Domain.Entities.Commit

  # Analyzes co-change data for a given list of commits.
  #
  # Returns a tuple of:
  # - A map of file pairs to their co-change count.
  # - A map of individual file commit counts.
  @spec analyze_commits([Commit.t()]) ::
          {%{{String.t(), String.t()} => non_neg_integer()}, %{String.t() => non_neg_integer()}}
  def analyze_commits(commits) do
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
  def generate_file_pairs(files) when length(files) <= 1, do: []
  def generate_file_pairs(files), do: for(x <- files, y <- files, x < y, do: {x, y})
end
