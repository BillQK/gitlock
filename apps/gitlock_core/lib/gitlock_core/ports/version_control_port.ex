defmodule GitlockCore.Ports.VersionControlPort do
  @moduledoc """
  Port for accessing version control history.
  """

  alias GitlockCore.Domain.Entities.Commit

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

  @doc """
  Retrieve the contents of a file at a specific commit.

  ## Parameters

    * `repo_path` — path to the repository
    * `commit_id` — the commit SHA
    * `file_path` — path to the file relative to repo root

  ## Returns

    * `{:ok, content}` on success
    * `{:error, reason}` if the file doesn't exist at that commit
  """
  @callback get_file_at_commit(repo_path(), String.t(), String.t()) ::
              {:ok, String.t()} | {:error, term()}

  @doc """
  List files that exist at a specific commit.

  ## Parameters

    * `repo_path` — path to the repository
    * `commit_id` — the commit SHA

  ## Returns

    * `{:ok, [file_path]}` on success
    * `{:error, reason}` on failure
  """
  @callback list_files_at_commit(repo_path(), String.t()) ::
              {:ok, [String.t()]} | {:error, term()}
end
