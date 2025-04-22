defmodule GitlockHolmes.Ports.VersionControlPort do
  @moduledoc """
  Port for accessing version control history.
  """

  alias GitlockHolmes.Domain.Entities.Commit

  @typedoc "Path or identifier for the repository (e.g. a log file path or repo URL)"
  @type repo_path :: String.t()

  @typedoc "Options for retrieving history (e.g. filters, time windows)"
  @type options :: %{optional(atom()) => term()}

  @typedoc "Successful return of parsed commits"
  @type success :: {:ok, [Commit.t()]}

  @typedoc "Error return with a human‑readable message"
  @type error :: {:error, String.t()}

  @doc """
  Retrieve the commit history from the given repository.

  ## Parameters

    * `repo_path` — path to a VCS log file or repository  
    * `options`   — a map of retrieval options (e.g. `:since`, `:until`)

  ## Returns

    * `{:ok, commits}` on success, where `commits` is a list of `%Commit{}`  
    * `{:error, reason}` on failure  
  """
  @callback get_commit_history(repo_path(), options()) :: success() | error()
end
