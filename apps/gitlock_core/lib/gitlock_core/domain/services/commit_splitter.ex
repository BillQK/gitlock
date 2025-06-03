defmodule GitlockCore.Domain.Services.CommitSplitter do
  @moduledoc "Splitting commits into temporal groups"

  alias GitlockCore.Domain.Entities.Commit

  @typedoc "Result of splitting commits"
  @type split_result :: {[Commit.t()], [Commit.t()], [Commit.t()]}

  @doc """
  Splits a list of commits into full, early (first half), and recent (second half).

  ## Parameters
    * `commits` - A list of commits
    
  ## Returns
    * `{sorted, early, recent}` on success
    * For empty lists, returns `{[], [], []}`
    * For single commit, returns `{[commit], [commit], []}`
  """
  @spec split_commits([Commit.t()]) :: split_result()
  def split_commits([]), do: {[], [], []}

  def split_commits([single_commit]) do
    {[single_commit], [single_commit], []}
  end

  def split_commits(commits) when is_list(commits) and length(commits) > 0 do
    sorted = Enum.sort_by(commits, & &1.date)
    mid = div(length(sorted), 2)
    {early, recent} = Enum.split(sorted, mid)
    {sorted, early, recent}
  end

  def split_commits(invalid) do
    raise ArgumentError, "Expected a list of commits, got: #{inspect(invalid)}"
  end
end
