defmodule GitlockHolmes.Domain.Services.Summary do
  @moduledoc """
  Service for summarizing commit history in the codebase.

  Provides basic metadata about the commit activity including counts of
  commits, unique authors, and entities (files touched).
  """

  alias GitlockHolmes.Domain.Entities.Commit

  @type summary :: %{
          statistic: String.t(),
          value: non_neg_integer()
        }

  @doc """
  Summarizes commit history with basic metadata.

  ## Parameters

    - `commits`: A list of `%Commit{}` structs representing the commit history.

  ## Returns

    A list of maps, each containing a statistic label and its corresponding value.
  """
  @spec summarize([Commit.t()]) :: [summary()]
  def summarize(commits) do
    authors =
      commits
      |> Enum.map(& &1.author)
      |> Enum.uniq()

    entities =
      commits
      |> Enum.flat_map(& &1.file_changes)
      |> Enum.map(& &1.entity)
      |> Enum.uniq()

    [
      %{statistic: "number-of-commits", value: length(commits)},
      %{statistic: "number-of-authors", value: length(authors)},
      %{statistic: "number-of-entities", value: length(entities)}
    ]
  end
end
