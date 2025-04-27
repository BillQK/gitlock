defmodule GitlockHolmesCore.Domain.Services.CommitSplitter do
  @moduledoc "Splitting commits into temporal groups"

  alias GitlockHolmesCore.Domain.Entities.Commit

  # Splits a list of commits into full, early (first half), and recent (second half).
  @spec split_commits([Commit.t()]) :: {[Commit.t()], [Commit.t()], [Commit.t()]}
  def split_commits(commits) do
    sorted = Enum.sort_by(commits, & &1.date)
    mid = div(length(sorted), 2)
    {early, recent} = Enum.split(sorted, mid)
    {sorted, early, recent}
  end
end
