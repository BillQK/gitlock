defmodule GitlockHolmesCore.Domain.Services.KnowledgeSiloDetection do
  @moduledoc """
  Service for detecting knowledge silos in the codebase.

  A knowledge silo exists when a single developer has contributed a disproportionate 
  amount of code to a file or component, creating a potential risk if that 
  developer leaves the team.
  """

  alias GitlockHolmesCore.Domain.Values.KnowledgeSilo
  alias GitlockHolmesCore.Domain.Entities.{Commit, Author}

  @doc """
  Identifies knowledge silos by analyzing commit history.

  ## Parameters
    * `commits` - List of commits to analyze
    
  ## Returns
    A list of knowledge silos sorted by ownership ratio (highest first)
  """
  @spec detect_knowledge_silos([Commit.t()]) :: [KnowledgeSilo.t()]
  def detect_knowledge_silos(commits) do
    # Group file changes by file path
    file_changes_by_entity =
      commits
      |> Enum.flat_map(fn %Commit{file_changes: changes, author: author} ->
        Enum.map(changes, fn change ->
          %{entity: change.entity, author: author}
        end)
      end)
      |> Enum.group_by(fn %{entity: entity} -> entity end)

    # Calculate ownership statistics for each file
    file_changes_by_entity
    |> Enum.map(fn {entity, changes} ->
      # Count contributions by author
      author_contributions =
        changes
        |> Enum.group_by(fn %{author: author} -> Author.display_name(author) end)
        |> Enum.map(fn {author, contributions} ->
          {author, length(contributions)}
        end)
        |> Enum.sort_by(fn {_author, count} -> count end, :desc)

      total_commits = length(changes)
      unique_authors = length(author_contributions)
      {main_author, main_author_commits} = List.first(author_contributions)
      ownership_ratio = main_author_commits / total_commits

      # Calculate risk level based on ownership ratio and number of commits
      risk_level = risk_level_from_metrics(ownership_ratio, total_commits, unique_authors)

      # Create result map
      %KnowledgeSilo{
        entity: entity,
        main_author: main_author,
        ownership_ratio: Float.round(ownership_ratio * 100, 1),
        num_authors: unique_authors,
        num_commits: total_commits,
        risk_level: risk_level
      }
    end)
    |> Enum.sort_by(fn %{ownership_ratio: ratio} -> ratio end, :desc)
  end

  @doc """
  Determines risk level based on ownership ratio and commit metrics.

  High risk when:
  - Ownership ratio > 80% AND number of commits > 10
  - OR Ownership ratio > 90% AND number of commits > 5

  Medium risk when:
  - Ownership ratio > 70% AND number of commits > 5
  - OR Ownership ratio > 80% AND number of commits > 3

  Low risk otherwise.
  """
  @spec risk_level_from_metrics(float(), integer(), integer()) :: :high | :medium | :low
  def risk_level_from_metrics(ownership_ratio, commit_count, author_count)
      when (ownership_ratio > 0.8 and commit_count > 10) or
             (ownership_ratio > 0.9 and commit_count > 5) or
             (author_count == 1 and commit_count > 10) do
    :high
  end

  def risk_level_from_metrics(ownership_ratio, commit_count, _author_count)
      when (ownership_ratio > 0.7 and commit_count > 5) or
             (ownership_ratio > 0.8 and commit_count > 3) do
    :medium
  end

  def risk_level_from_metrics(_, _, _), do: :low
end
