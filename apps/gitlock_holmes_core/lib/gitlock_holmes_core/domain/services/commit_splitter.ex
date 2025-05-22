defmodule GitlockHolmesCore.Domain.Services.CommitSplitter do
  @moduledoc "Splitting commits into temporal groups"

  alias GitlockHolmesCore.Domain.Entities.Commit

  @typedoc "Result of splitting commits"
  @type split_result :: {[Commit.t()], [Commit.t()], [Commit.t()]}

  @doc """
  Splits a list of commits into full, early (first half), and recent (second half).

  ## Parameters
    * `commits` - A non-empty list of commits
    
  ## Returns
    * `{:ok, {sorted, early, recent}}` on success
    * `{:error, reason}` if input is invalid
  """
  @spec split_commits([Commit.t()]) :: {:ok, split_result()} | {:error, String.t()}
  def split_commits(commits) when is_list(commits) and length(commits) > 0 do
    sorted = Enum.sort_by(commits, & &1.date)
    mid = div(length(sorted), 2)
    {early, recent} = Enum.split(sorted, mid)
    {:ok, {sorted, early, recent}}
  end

  def split_commits([]) do
    {:error, "Cannot split an empty commit list"}
  end

  def split_commits(invalid) do
    {:error, "Expected a list of commits, got: #{inspect(invalid)}"}
  end
end
