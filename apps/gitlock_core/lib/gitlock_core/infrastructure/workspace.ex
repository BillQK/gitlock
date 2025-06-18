defmodule GitlockCore.Infrastructure.Workspace do
  @moduledoc """
  High-level API for managing repository workspaces.

  This module provides a simple interface for acquiring and using workspaces
  for Git repositories and other sources. It handles:

  - Automatic resource management
  - Caching to avoid duplicate clones
  - Process-based cleanup

  ## Usage Patterns

  ### Automatic Management (Recommended)

      Workspace.with("https://github.com/user/repo.git", fn workspace ->
        # Use workspace.path to access the repository
        # Cleanup happens automatically
      end)

  ### Manual Management

      {:ok, workspace} = Workspace.acquire("./local/repo")
      # Use workspace...
      Workspace.release(workspace)

  ## Workspace Types

  - `:remote` - Cloned from a URL (cleaned up on release)
  - `:local` - Local directory (never cleaned up)
  - `:file` - Regular file (never cleaned up)
  """

  alias GitlockCore.Infrastructure.Workspace.{Manager, Store}

  @typedoc "Workspace information"
  @type workspace :: %{
          id: String.t(),
          source: String.t(),
          path: String.t(),
          type: :remote | :local | :file,
          state: :acquiring | :ready | :error,
          created_at: DateTime.t()
        }

  @typedoc "Options for workspace acquisition"
  @type acquire_opts :: [
          {:depth, pos_integer()}
          | {:branch, String.t()}
          | {:single_branch, boolean()}
          | {:timeout, timeout()}
        ]

  @doc """
  Executes a function with an automatically managed workspace.

  This is the recommended way to use workspaces. The workspace is automatically
  acquired before the function runs and released after (even if an error occurs).

  ## Parameters

  - `source`: Repository URL, file path, or directory path
  - `opts`: Options for workspace acquisition
  - `fun`: Function that receives the workspace

  ## Options

  - `:depth` - Clone depth for remote repositories
  - `:branch` - Specific branch to clone
  - `:single_branch` - Clone only the specified branch
  - `:timeout` - Maximum time to wait for acquisition

  ## Returns

  - `{:ok, result}` - The function result wrapped in ok tuple
  - `{:error, reason}` - If acquisition fails or function raises

  ## Examples

      # Clone and use a remote repository
      Workspace.with("https://github.com/elixir-lang/elixir.git", fn workspace ->
        File.ls!(workspace.path)
      end)
      #=> {:ok, ["README.md", "lib", "test", ...]}
      
      # Use with options
      Workspace.with(url, [depth: 1, branch: "main"], fn workspace ->
        # Only the latest commit from main branch is available
      end)
      
      # Error handling
      case Workspace.with(url, fn w -> analyze(w.path) end) do
        {:ok, result} -> handle_success(result)
        {:error, reason} -> handle_error(reason)
      end
  """
  @spec with(String.t(), acquire_opts(), (workspace() -> result)) ::
          {:ok, result} | {:error, term()}
        when result: term()
  def with(source, opts \\ [], fun) when is_function(fun, 1) do
    case Manager.acquire(source, opts) do
      {:ok, workspace} ->
        try do
          result = fun.(workspace)
          result
        rescue
          e ->
            {:error, Exception.format(:error, e, __STACKTRACE__)}
        after
          Manager.release(workspace.id)
        end

      error ->
        error
    end
  end

  @doc """
  Manually acquires a workspace.

  The caller is responsible for releasing the workspace when done.
  Consider using `with/3` instead for automatic cleanup.

  ## Parameters

  - `source`: Repository URL, file path, or directory path  
  - `opts`: Options for workspace acquisition

  ## Returns

  - `{:ok, workspace}` - Successfully acquired workspace
  - `{:error, reason}` - Acquisition failed

  ## Examples

      {:ok, workspace} = Workspace.acquire("https://github.com/user/repo.git")
      try do
        # Use workspace.path
      after
        Workspace.release(workspace)
      end
  """
  @spec acquire(String.t(), acquire_opts()) :: {:ok, workspace()} | {:error, term()}
  def acquire(source, opts \\ []) do
    Manager.acquire(source, opts)
  end

  @doc """
  Releases a manually acquired workspace.

  This triggers cleanup for remote workspaces. Local directories and files
  are never deleted.

  ## Parameters

  - `workspace_or_id`: Workspace map or ID string

  ## Examples

      # Release by workspace
      Workspace.release(workspace)
      
      # Release by ID
      Workspace.release("ws_abc123")
      
      # Release by source (finds matching workspace)
      Workspace.release("https://github.com/user/repo.git")
  """
  @spec release(workspace() | String.t()) :: :ok
  def release(%{id: id}), do: Manager.release(id)
  def release(id_or_source) when is_binary(id_or_source), do: Manager.release(id_or_source)

  @doc """
  Checks if a workspace exists for the given source.

  ## Parameters

  - `source`: Repository URL or path to check

  ## Returns

  `true` if a workspace exists, `false` otherwise.

  ## Examples

      iex> Workspace.exists?("https://github.com/user/repo.git")
      true
  """
  @spec exists?(String.t()) :: boolean()
  def exists?(source) do
    case Store.get_by_source(source) do
      nil -> false
      _ -> true
    end
  end

  @doc """
  Lists all active workspaces.

  Useful for debugging and monitoring.

  ## Returns

  List of all workspace maps currently active.

  ## Examples

      iex> Workspace.list()
      [
        %{id: "ws_abc", source: "https://github.com/user/repo.git", type: :remote, ...},
        %{id: "ws_def", source: "./local/path", type: :local, ...}
      ]
  """
  @spec list() :: [workspace()]
  def list do
    Store.list()
  end
end
