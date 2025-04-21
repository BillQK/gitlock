defmodule GitlockHolmes.Domain.Services.HotspotDetection do
  @moduledoc """
  Service for detecting hotspots in the codebase.
  """

  alias GitlockHolmes.Domain.Entities.Commit
  alias GitlockHolmes.Domain.Entities.FileChange

  @type risk_factor :: :high | :medium | :low
  @type hotspot :: %{
          entity: String.t(),
          revisions: non_neg_integer(),
          risk_factor: risk_factor()
        }

  @doc """
  Identifies hotspots by analyzing revision frequency.

  Returns a list of entities sorted by number of revisions,
  with entities changing most frequently at the top.
  """
  @spec detect_hotspots([Commit.t()]) :: [hotspot()]
  def detect_hotspots(commits) do
    # Extract all file changes
    file_changes =
      commits
      |> Enum.flat_map(fn %Commit{file_changes: changes} -> changes end)

    # Group by entity (file path) and count revisions
    file_changes
    |> Enum.group_by(fn %FileChange{entity: entity} -> entity end)
    |> Enum.map(fn {entity, changes} ->
      %{
        entity: entity,
        revisions: length(changes),
        risk_factor: calculate_risk_factor(changes)
      }
    end)
    |> Enum.sort_by(fn %{revisions: revs} -> revs end, :desc)
  end

  @spec calculate_risk_factor([FileChange.t()]) :: risk_factor()
  defp calculate_risk_factor(changes) do
    # Simple risk calculation: more changes = higher risk
    # In a real implementation, this would be more sophisticated
    changes_count = length(changes)

    cond do
      changes_count > 20 -> :high
      changes_count > 10 -> :medium
      true -> :low
    end
  end
end
