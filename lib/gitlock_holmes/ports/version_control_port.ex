defmodule GitlockHolmes.Ports.VersionControlPort do
  @moduledoc """
  Port for accessing version control history.
  """
  alias GitlockHolmes.Domain.Entities.Commit

  @callback get_commit_history(String.t(), map()) :: {:ok, [Commit.t()]} | {:error, String.t()}
end
