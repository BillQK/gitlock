defmodule GitlockHolmesCore.Domain.Entities.Commit do
  @moduledoc """
  Represents a commit in version control.

  This entity contains metadata about a commit including its identifier, author,
  date, commit message, and the associated file changes.
  """

  alias GitlockHolmesCore.Domain.Entities.Author
  alias GitlockHolmesCore.Domain.Values.FileChange

  @type t :: %__MODULE__{
          id: String.t(),
          author: Author.t(),
          date: Date.t(),
          message: String.t(),
          file_changes: [FileChange.t()]
        }

  defstruct [:id, :author, :date, :message, :file_changes]

  @doc """
  Creates a new commit entity.

  ## Parameters

    * `id` - Unique identifier for the commit (e.g., SHA hash)
    * `author` - Author entity who created the commit
    * `date` - Date when the commit was created
    * `message` - Commit message
    * `file_changes` - List of file changes associated with this commit

  ## Returns

    A new Commit struct

  ## Examples

      iex> author = %Author{name: "Jane Smith", email: "jane@example.com"}
      iex> file_change = %FileChange{path: "lib/example.ex", insertions: 10, deletions: 5}
      iex> Commit.new("abc123", author, "2023-04-21", "Fix bug", [file_change])
      %Commit{
        id: "abc123",
        author: %Author{name: "Jane Smith", email: "jane@example.com"},
        date: "2023-04-21",
        message: "Fix bug",
        file_changes: [%FileChange{path: "lib/example.ex", insertions: 10, deletions: 5}]
      }
  """
  @spec new(
          id :: String.t(),
          author :: Author.t(),
          date :: String.t(),
          message :: String.t(),
          file_changes :: [FileChange.t()]
        ) :: t()
  def new(id, author, date, message, file_changes \\ []) do
    %__MODULE__{
      id: id,
      author: author,
      date: Date.from_iso8601!(date),
      message: message,
      file_changes: file_changes
    }
  end

  @doc """
  Calculates the total number of files changed in this commit.

  ## Returns

    The number of files changed as a non-negative integer

  ## Examples

      iex> commit = %Commit{file_changes: [%FileChange{}, %FileChange{}]}
      iex> Commit.file_count(commit)
      2
  """
  @spec file_count(commit :: t()) :: non_neg_integer()
  def file_count(%__MODULE__{file_changes: file_changes}) do
    length(file_changes)
  end

  @doc """
  Calculates the total churn (insertions + deletions) of this commit.

  ## Returns

    The total number of lines changed as a non-negative integer

  ## Examples

      iex> file_change1 = %FileChange{loc_added: 10, loc_deleted: : 5}
      iex> file_change2 = %FileChange{loc_added: : 3, loc_deleted: 2}
      iex> commit = %Commit{file_changes: [file_change1, file_change2]}
      iex> Commit.total_churn(commit)
      20

      iex> commit_with_binary = %Commit{file_changes: [
      iex>   %FileChange{loc_added: 10, loc_deleted: 5},
      iex>   %FileChange{loc_added: "-", loc_deleted: "-"}
      iex> ]}
      iex> Commit.total_churn(commit_with_binary)
      15
  """
  @spec total_churn(commit :: t()) :: non_neg_integer()
  def total_churn(%__MODULE__{file_changes: file_changes}) do
    Enum.reduce(file_changes, 0, fn change, total ->
      total + FileChange.total_churn(change)
    end)
  end
end
