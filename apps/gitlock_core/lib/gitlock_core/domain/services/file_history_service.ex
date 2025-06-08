defmodule GitlockCore.Domain.Services.FileHistoryService do
  @moduledoc """
  Service for building and analyzing file history from commits.

  This service creates FileHistory value objects that track file evolution
  across renames and moves, providing a consolidated view of file changes.
  """

  alias GitlockCore.Domain.Entities.Commit
  alias GitlockCore.Domain.Values.{FileHistory}

  @doc """
  Builds a FileHistory value object from a list of commits.

  This analyzes all commits to:
  - Detect and track file renames
  - Consolidate changes under canonical (current) names
  - Filter out pure rename noise

  ## Example

      iex> history = FileHistoryService.build_history(commits)
      iex> FileHistory.get_canonical_name(history, "old_auth.ex")
      "authentication.ex"
  """
  @spec build_history([Commit.t()]) :: FileHistory.t()
  def build_history(commits) do
    rename_map = build_rename_map(commits)
    canonical_changes = build_canonical_changes(commits, rename_map)

    FileHistory.new(rename_map, canonical_changes)
  end

  @doc """
  Checks if a file path represents a rename pattern.

  Git represents renames as "{old => new}" in the file path.
  """
  @spec is_rename_pattern?(String.t()) :: boolean()
  def is_rename_pattern?(path) do
    String.contains?(path, " => ")
  end

  @doc """
  Parses a rename pattern to extract old and new paths.

  ## Examples

      iex> FileHistoryService.parse_rename("{old.ex => new.ex}")
      {"old.ex", "new.ex"}
      
      iex> FileHistoryService.parse_rename("lib/{auth.ex => authentication.ex}")  
      {"lib/auth.ex", "lib/authentication.ex"}
      
      iex> FileHistoryService.parse_rename("normal_file.ex")
      nil
  """
  @spec parse_rename(String.t()) :: {String.t(), String.t()} | nil
  def parse_rename(path) do
    cond do
      # Handle pattern: {old => new}
      match = Regex.run(~r/^{(.*) => (.*)}$/, path) ->
        [_, old, new] = match
        {old, new}

      # Handle pattern: prefix/{old => new}/suffix
      match = Regex.run(~r/(.*){\s*(.*?)\s*=>\s*(.*?)\s*}(.*)/, path) ->
        [_, prefix, old, new, suffix] = match
        {prefix <> old <> suffix, prefix <> new <> suffix}

      true ->
        nil
    end
  end

  @doc """
  Normalizes commits to use canonical file names based on the file history.

  This function:
  - Replaces all file paths with their canonical (current) names
  - Filters out pure rename entries (0 additions, 0 deletions)
  - Preserves renames with modifications but uses the canonical name

  ## Parameters
    - commits: List of commits to normalize
    - history: FileHistory value object containing rename mappings
    
  ## Returns
    List of commits with normalized file paths
    
  ## Example

      iex> history = FileHistoryService.build_history(commits)
      iex> normalized = FileHistoryService.normalize_commits(commits, history)
  """
  @spec normalize_commits([Commit.t()], FileHistory.t()) :: [Commit.t()]
  def normalize_commits(commits, history) do
    Enum.map(commits, fn commit ->
      normalized_changes =
        commit.file_changes
        |> Enum.map(&normalize_file_change(&1, history))
        |> Enum.reject(&is_nil/1)

      %{commit | file_changes: normalized_changes}
    end)
  end

  # Private implementation

  defp build_rename_map(commits) do
    commits
    |> extract_renames()
    |> follow_rename_chains()
  end

  defp extract_renames(commits) do
    commits
    |> Enum.flat_map(& &1.file_changes)
    |> Enum.map(& &1.entity)
    |> Enum.filter(&is_rename_pattern?/1)
    |> Enum.map(&parse_rename/1)
    |> Enum.reject(&is_nil/1)
  end

  defp follow_rename_chains(renames) do
    # Build a map that follows transitive renames
    # e.g., if a->b and b->c, then a->c and b->c
    Enum.reduce(renames, %{}, fn {old, new}, map ->
      # If 'new' was already renamed, follow the chain
      final_name = Map.get(map, new, new)

      # Update all files that point to 'old' to point to final_name
      map
      |> Enum.map(fn {k, v} ->
        if v == old, do: {k, final_name}, else: {k, v}
      end)
      |> Enum.into(%{})
      |> Map.put(old, final_name)
    end)
  end

  defp build_canonical_changes(commits, rename_map) do
    commits
    |> Enum.flat_map(fn %Commit{file_changes: changes} ->
      normalize_changes(changes, rename_map)
    end)
    |> Enum.group_by(& &1.entity)
  end

  defp normalize_changes(changes, rename_map) do
    changes
    |> Enum.map(&normalize_single_change(&1, rename_map))
    |> Enum.reject(&is_nil/1)
  end

  defp normalize_single_change(change, rename_map) do
    cond do
      # Skip pure renames (0 additions, 0 deletions)
      is_pure_rename?(change) ->
        nil

      # Handle rename patterns in the entity path
      is_rename_pattern?(change.entity) ->
        case parse_rename(change.entity) do
          {_old, new} ->
            canonical = Map.get(rename_map, new, new)
            %{change | entity: canonical}

          nil ->
            change
        end

      # Normal file - map to canonical name
      true ->
        canonical = Map.get(rename_map, change.entity, change.entity)
        %{change | entity: canonical}
    end
  end

  defp normalize_file_change(change, history) do
    cond do
      # Skip pure renames (0 additions, 0 deletions)
      is_pure_rename?(change) ->
        nil

      # Handle rename patterns in the entity path
      is_rename_pattern?(change.entity) ->
        case parse_rename(change.entity) do
          {_old, new} ->
            canonical = FileHistory.get_canonical_name(history, new)
            %{change | entity: canonical}

          nil ->
            change
        end

      # Normal file - map to canonical name
      true ->
        canonical = FileHistory.get_canonical_name(history, change.entity)
        %{change | entity: canonical}
    end
  end

  defp is_pure_rename?(change) do
    is_rename_pattern?(change.entity) and
      change.loc_added in ["0", 0] and
      change.loc_deleted in ["0", 0]
  end
end
