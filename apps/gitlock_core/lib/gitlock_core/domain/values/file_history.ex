defmodule GitlockCore.Domain.Values.FileHistory do
  @moduledoc """
  Value object representing the complete history of file changes,
  including renames and moves.

  This immutable data structure tracks:
  - File rename mappings (old names to current names)
  - Consolidated changes grouped by canonical file names
  - Metadata about the file evolution
  """

  alias GitlockCore.Domain.Values.FileChange

  @type rename_map :: %{String.t() => String.t()}
  @type canonical_changes :: %{String.t() => [FileChange.t()]}

  @type t :: %__MODULE__{
          rename_map: rename_map(),
          canonical_changes: canonical_changes(),
          total_files: non_neg_integer(),
          total_renames: non_neg_integer()
        }

  @enforce_keys [:rename_map, :canonical_changes, :total_files, :total_renames]
  defstruct [:rename_map, :canonical_changes, :total_files, :total_renames]

  @doc """
  Creates a new FileHistory value object.

  ## Parameters
    - rename_map: Maps historical file names to their current canonical names
    - canonical_changes: File changes grouped by canonical (current) names
  """
  @spec new(rename_map(), canonical_changes()) :: t()
  def new(rename_map, canonical_changes) do
    %__MODULE__{
      rename_map: rename_map,
      canonical_changes: canonical_changes,
      total_files: map_size(canonical_changes),
      total_renames: map_size(rename_map)
    }
  end

  @doc """
  Gets the canonical (current) name for a file path.

  If the file has been renamed, returns the most recent name.
  Otherwise returns the original name.
  """
  @spec get_canonical_name(t(), String.t()) :: String.t()
  def get_canonical_name(%__MODULE__{rename_map: rename_map}, file_path) do
    Map.get(rename_map, file_path, file_path)
  end

  @doc """
  Gets all changes for a file, including its history under previous names.

  Returns an empty list if the file is not found.
  """
  @spec get_file_changes(t(), String.t()) :: [FileChange.t()]
  def get_file_changes(%__MODULE__{canonical_changes: canonical_changes}, file_path) do
    Map.get(canonical_changes, file_path, [])
  end

  @doc """
  Gets all canonical file paths that have changes.

  This returns only the current names of files, not historical names.
  """
  @spec get_all_files(t()) :: [String.t()]
  def get_all_files(%__MODULE__{canonical_changes: canonical_changes}) do
    Map.keys(canonical_changes)
  end

  @doc """
  Checks if a file was renamed at some point in history.
  """
  @spec was_renamed?(t(), String.t()) :: boolean()
  def was_renamed?(%__MODULE__{rename_map: rename_map}, file_path) do
    # Check if this file appears as either source or target of rename
    Map.has_key?(rename_map, file_path) or
      file_path in Map.values(rename_map)
  end

  @doc """
  Gets the number of changes for a specific file.
  """
  @spec get_revision_count(t(), String.t()) :: non_neg_integer()
  def get_revision_count(%__MODULE__{} = history, file_path) do
    canonical_name = get_canonical_name(history, file_path)

    history
    |> get_file_changes(canonical_name)
    |> length()
  end

  @doc """
  Finds the canonical name for a file that might be referenced by an old name.
  Useful when looking up metrics that were calculated before a rename.
  """
  @spec find_canonical_for_any_name(t(), String.t()) :: String.t() | nil
  def find_canonical_for_any_name(%__MODULE__{rename_map: rename_map} = history, search_name) do
    cond do
      # Direct lookup - search_name is already canonical
      Map.has_key?(history.canonical_changes, search_name) ->
        search_name

      # search_name is an old name that was renamed
      Map.has_key?(rename_map, search_name) ->
        Map.get(rename_map, search_name)

      # search_name might be a middle name in a rename chain
      # Find if any rename maps to a canonical that then maps to something else
      true ->
        rename_map
        |> Enum.find_value(fn {_old, canonical} ->
          if get_canonical_name(history, canonical) == search_name do
            canonical
          end
        end)
    end
  end

  @doc """
  Returns statistics about the file history.
  """
  @spec stats(t()) :: map()
  def stats(%__MODULE__{} = history) do
    %{
      total_files: history.total_files,
      total_renames: history.total_renames,
      total_changes: history.canonical_changes |> Map.values() |> List.flatten() |> length(),
      avg_changes_per_file: calculate_avg_changes(history)
    }
  end

  defp calculate_avg_changes(history) do
    if history.total_files == 0 do
      0.0
    else
      total_changes =
        history.canonical_changes
        |> Map.values()
        |> Enum.map(&length/1)
        |> Enum.sum()

      Float.round(total_changes / history.total_files, 2)
    end
  end
end
