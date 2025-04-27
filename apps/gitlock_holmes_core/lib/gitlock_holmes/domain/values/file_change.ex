defmodule GitlockHolmesCore.Domain.Values.FileChange do
  @moduledoc """
  Represents a change to a file in a commit.

  This entity tracks modifications to a file including the file path and
  the number of lines added and deleted.
  """

  @type t :: %__MODULE__{
          entity: String.t(),
          loc_added: String.t() | non_neg_integer(),
          loc_deleted: String.t() | non_neg_integer()
        }

  defstruct [:entity, :loc_added, :loc_deleted]

  @doc """
  Creates a new file change entity.

  ## Parameters
    * `entity` - Path of the file that was changed
    * `loc_added` - Lines of code added
    * `loc_deleted` - Lines of code deleted 
    
  ## Returns 
    A new FileChange struct
    
  ## Examples
      
      iex> FileChange.new("src/main.ex", 10, 5)
      %FileChange{entity: "src/main.ex", loc_added: 10, loc_deleted: 5}
      
      iex> FileChange.new("binary.bin", "-", "-")
      %FileChange{entity: "binary.bin", loc_added: "-", loc_deleted: "-"}
  """
  @spec new(String.t(), String.t() | non_neg_integer(), String.t() | non_neg_integer()) :: t()
  def new(entity, loc_added, loc_deleted) do
    %__MODULE__{
      entity: entity,
      loc_added: loc_added,
      loc_deleted: loc_deleted
    }
  end

  @doc """
  Calculates the total churn (sum of additions and deletions).

  Returns 0 for binary files where additions and deletions are represented as "-".

  ## Returns
    Total number of lines changed
    
  ## Examples
      
      iex> change = FileChange.new("src/main.ex", 10, 5)
      iex> FileChange.total_churn(change)
      15
      
      iex> binary_change = FileChange.new("binary.bin", "-", "-")
      iex> FileChange.total_churn(binary_change)
      0
  """
  @spec total_churn(t()) :: non_neg_integer()
  def total_churn(%__MODULE__{loc_added: added, loc_deleted: deleted}) do
    added_int = parse_loc(added)
    deleted_int = parse_loc(deleted)

    added_int + deleted_int
  end

  @doc """
  Determines if this file change represents a binary file modification.

  ## Returns
    `true` if the file is binary, `false` otherwise
    
  ## Examples
      
      iex> change = FileChange.new("src/main.ex", 10, 5)
      iex> FileChange.binary?(change)
      false
      
      iex> binary_change = FileChange.new("binary.bin", "-", "-")
      iex> FileChange.binary?(binary_change)
      true
  """
  @spec binary?(t()) :: boolean()
  def binary?(%__MODULE__{loc_added: "-", loc_deleted: "-"}), do: true
  def binary?(_), do: false

  # Private helper for parsing LOC values
  @spec parse_loc(String.t() | non_neg_integer()) :: non_neg_integer()
  defp parse_loc(loc) when is_integer(loc), do: loc
  defp parse_loc("-"), do: 0

  defp parse_loc(loc) when is_binary(loc) do
    case Integer.parse(loc) do
      {num, _} -> num
      :error -> 0
    end
  end

  defp parse_loc(_), do: 0
end
