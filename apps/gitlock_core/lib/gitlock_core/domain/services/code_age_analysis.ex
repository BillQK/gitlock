defmodule GitlockCore.Domain.Services.CodeAgeAnalysis do
  @moduledoc """
  Service for analyzing code age in the codebase.

  This service processes commit data to identify file age patterns
  based on Adam Tornhill's Code Maat methodology.
  """

  alias GitlockCore.Domain.Values.CodeAge
  alias GitlockCore.Domain.Entities.Commit

  @doc """
  Identifies code age by analyzing commits over time period.

  Takes a list of commits and calculates the age of each file based on
  its last modification date. Extracts file changes from each commit,
  groups by file entity, and finds the most recent modification.

  ## Parameters 
  * `commits` - List of Commit entities to analyze

  ## Returns
  List of CodeAge value objects, one for each unique file found in the commits.

  ## Examples

      commits = [
        %Commit{
          date: ~D[2024-01-15], 
          file_changes: [
            %FileChange{entity: "src/user.ex"},
            %FileChange{entity: "src/auth.ex"}
          ]
        },
        %Commit{
          date: ~D[2024-02-01], 
          file_changes: [
            %FileChange{entity: "src/user.ex"}  # More recent
          ]
        }
      ]
      
      code_ages = CodeAgeAnalysis.calculate_code_age(commits)
      # Returns [
      #   %CodeAge{entity: "src/user.ex", age_months: 8.5},   # Uses 2024-02-01
      #   %CodeAge{entity: "src/auth.ex", age_months: 16.2}   # Uses 2024-01-15
      # ]
  """
  @spec calculate_code_age([Commit.t()]) :: [CodeAge.t()]
  def calculate_code_age(commits) when is_list(commits) do
    commits
    |> extract_file_changes_with_dates()
    |> group_by_file_entity()
    |> find_latest_date_per_file()
    |> create_code_age_struct()
    |> sort_code_age_struct()
  end

  # Private functions
  defp extract_file_changes_with_dates(commits) do
    Enum.flat_map(commits, fn commit ->
      Enum.map(commit.file_changes, fn file_change ->
        {file_change.entity, commit.date}
      end)
    end)
  end

  defp group_by_file_entity(file_changes_with_dates) do
    Enum.group_by(file_changes_with_dates, fn {entity, _date} -> entity end)
  end

  defp find_latest_date_per_file(grouped_file_changes) do
    Enum.map(grouped_file_changes, fn {entity, entity_changes} ->
      latest_date =
        entity_changes
        |> Enum.map(fn {_entity, date} -> date end)
        |> Enum.max(Date)

      {entity, latest_date}
    end)
  end

  defp create_code_age_struct(files_with_latest_dates) do
    Enum.map(files_with_latest_dates, fn {entity, latest_date} ->
      age_months = CodeAge.calculate_age_months(latest_date)
      risk_score = CodeAge.calculate_risk(age_months)
      CodeAge.new(entity, age_months, risk_score)
    end)
  end

  defp sort_code_age_struct(code_ages) do
    Enum.sort_by(code_ages, & &1.age_months, :asc)
  end
end
