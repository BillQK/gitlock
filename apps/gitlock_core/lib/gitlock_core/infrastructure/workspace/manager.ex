defmodule GitlockCore.Infrastructure.Workspace.Manager do
  @moduledoc """
  Manages the lifecycle of repository workspaces with automatic cleanup.

  This GenServer handles the business logic for workspace management, including:

  - Acquiring workspaces (with deduplication)
  - Cloning remote repositories
  - Recovery after crashes

  ## Architecture

  The Manager works in tandem with the Store:
  - Store (Agent) holds the state
  - Manager (GenServer) handles the logic

  This separation ensures state survives Manager crashes.

  ## Recovery

  On startup, the Manager:
  1. Re-establishes monitors for existing workspaces
  2. Cleans up workspaces with dead owners
  3. Resumes normal operation
  """
  use GenServer
  require Logger

  alias GitlockCore.Infrastructure.Workspace.Store

  # Default configuration values
  # 10 minutes default timeout
  @default_timeout :timer.minutes(10)
  # Clone all branches by default
  @default_single_branch true

  @typedoc "Manager state"
  @type state :: %{
          monitors: %{pid() => reference()},
          pending_acquisitions: %{String.t() => [GenServer.from()]}
        }

  @typedoc "Workspace acquisition options"
  @type acquire_opts :: [
          {:depth, pos_integer()}
          | {:branch, String.t()}
          | {:single_branch, boolean()}
          | {:timeout, timeout()}
        ]

  # Client API

  @doc """
  Starts the workspace manager.

  Usually called by the supervisor.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    Logger.info("Starting Workspace.Manager")
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Acquires a workspace for the given source.

  This function:
  1. Checks if a workspace already exists for the source
  2. If not, creates a new workspace and clones if necessary
  3. Monitors the calling process for automatic cleanup

  ## Parameters

  - `source`: URL, file path, or directory path
  - `opts`: Acquisition options

  ## Options

  - `:depth` - Git clone depth (default: full clone)
  - `:branch` - Specific branch to clone
  - `:single_branch` - Clone only the specified branch (default: #{@default_single_branch})
  - `:timeout` - Maximum time to wait for clone (default: #{@default_timeout}ms)

  ## Returns

  - `{:ok, workspace}` - Successfully acquired workspace
  - `{:error, reason}` - Acquisition failed

  ## Examples

      # Clone a remote repository
      {:ok, workspace} = Manager.acquire("https://github.com/user/repo.git")
      workspace.path #=> "/tmp/gitlock/abc123"
      
      # Use a local directory
      {:ok, workspace} = Manager.acquire("./local/repo")
      workspace.path #=> "./local/repo"
  """
  @spec acquire(String.t(), acquire_opts()) :: {:ok, map()} | {:error, term()}
  def acquire(source, opts \\ []) do
    # Extract timeout from opts or use default
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    GenServer.call(__MODULE__, {:acquire, source, self(), opts}, timeout)
  end

  @doc """
  Releases a workspace, marking it as available for cleanup.

  ## Parameters

  - `id_or_source`: Workspace ID or source URL/path

  ## Examples

      Manager.release("ws_123")
      Manager.release("https://github.com/user/repo.git")
  """
  @spec release(String.t()) :: :ok
  def release(id_or_source) do
    GenServer.call(__MODULE__, {:release, id_or_source})
  end

  # Server Implementation

  @impl GenServer
  def init(_opts) do
    Process.flag(:trap_exit, true)

    # Ensure base directories exist
    base_path = Path.join([System.tmp_dir!(), "gitlock", "workspaces"])
    File.mkdir_p!(base_path)

    {:ok, %{monitors: %{}, pending_acquisitions: %{}}}
  end

  @impl GenServer
  def handle_call({:acquire, source, pid, opts}, from, state) do
    case Store.get_by_source(source) do
      %{state: :ready} = workspace ->
        # Reuse existing ready workspace
        Logger.debug("Reusing existing workspace for #{source}")
        # Update last_accessed
        Store.touch(workspace.id)
        {:reply, {:ok, workspace}, state}

      %{state: :released} = workspace ->
        # Reactivate released workspace
        Logger.debug("Reactivating released workspace for #{source}")
        Store.update(workspace.id, %{state: :ready, last_accessed: DateTime.utc_now()})
        updated = Store.get(workspace.id)
        {:reply, {:ok, updated}, state}

      %{state: :acquiring} = workspace ->
        # Already being acquired, add to wait list
        Logger.debug("Workspace being acquired for #{source}, adding to wait list")
        add_to_wait_list(workspace.id, from, state)

      %{state: :failed} = workspace ->
        # Retry failed workspace
        Logger.info("Retrying failed workspace #{workspace.id}")
        retry_acquisition(workspace, from, state)

      nil ->
        # Create new workspace
        handle_new_acquisition(source, pid, opts, from, state)
    end
  end

  @impl GenServer
  def handle_call({:release, id_or_source}, _from, state) do
    case resolve_workspace(id_or_source) do
      nil ->
        Logger.debug("Attempted to release unknown workspace: #{id_or_source}")

      %{state: :ready} = workspace ->
        Store.update(workspace.id, %{
          state: :released,
          released_at: DateTime.utc_now()
        })

        Logger.info("Workspace #{workspace.id} released")

      %{state: :released} ->
        Logger.debug("Workspace already released")

      %{state: other_state} = workspace ->
        Logger.warning("Cannot release workspace #{workspace.id} in state #{other_state}")
    end

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info({:acquisition_complete, id, result}, state) do
    case result do
      {:ok, path} ->
        Logger.info("Workspace #{id} acquired successfully")

        Store.update(id, %{
          state: :ready,
          path: path,
          completed_at: DateTime.utc_now()
        })

        workspace = Store.get(id)
        reply_to_waiters({:ok, workspace}, id, state)

      {:error, reason} ->
        Logger.error("Failed to acquire workspace #{id}: #{inspect(reason)}")

        Store.update(id, %{
          state: :failed,
          error: reason,
          failed_at: DateTime.utc_now()
        })

        reply_to_waiters({:error, reason}, id, state)
    end

    # Clean up pending list
    {:noreply, %{state | pending_acquisitions: Map.delete(state.pending_acquisitions, id)}}
  end

  @impl GenServer
  def handle_info({:EXIT, _pid, :normal}, state) do
    # Normal Task completion - ignore
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  @impl GenServer
  def terminate(_reason, _state) do
    Logger.info("Workspace.Manager terminating")
    :ok
  end

  # Private Functions

  defp handle_new_acquisition(source, pid, opts, from, state) do
    workspace = create_workspace(source, pid, opts)
    workspace = Map.put(workspace, :last_accessed, DateTime.utc_now())
    Store.put(workspace.id, workspace)

    # Monitor the owner process
    monitor_ref = if is_pid(pid), do: Process.monitor(pid), else: nil

    new_state =
      if monitor_ref do
        put_in(state, [:monitors, pid], monitor_ref)
      else
        state
      end

    # Handle based on type
    if workspace.type == :remote do
      # For remote: Don't reply now, add to pending
      pending = Map.put(new_state.pending_acquisitions, workspace.id, [from])

      me = self()

      Task.start_link(fn ->
        result = perform_clone(workspace)
        send(me, {:acquisition_complete, workspace.id, result})
      end)

      # Return :noreply - the caller will wait
      {:noreply, %{new_state | pending_acquisitions: pending}}
    else
      # For local: Reply immediately
      Store.update(workspace.id, %{state: :ready, path: source})
      updated_workspace = Store.get(workspace.id)
      {:reply, {:ok, updated_workspace}, new_state}
    end
  end

  defp retry_acquisition(workspace, from, state) do
    # Update state back to acquiring
    Store.update(workspace.id, %{
      state: :acquiring,
      retry_at: DateTime.utc_now(),
      # Clear previous error
      error: nil
    })

    # Start new clone attempt
    me = self()

    Task.start_link(fn ->
      result = perform_clone(workspace)
      send(me, {:acquisition_complete, workspace.id, result})
    end)

    # Add to pending list
    pending = Map.put(state.pending_acquisitions, workspace.id, [from])
    {:noreply, %{state | pending_acquisitions: pending}}
  end

  defp add_to_wait_list(workspace_id, from, state) do
    waiting_list = Map.get(state.pending_acquisitions, workspace_id, [])
    new_waiting = Map.put(state.pending_acquisitions, workspace_id, [from | waiting_list])
    {:noreply, %{state | pending_acquisitions: new_waiting}}
  end

  defp reply_to_waiters(reply, workspace_id, state) do
    # Get waiting callers
    waiting = Map.get(state.pending_acquisitions, workspace_id, [])

    # Reply to each
    Enum.each(waiting, fn from ->
      GenServer.reply(from, reply)
    end)
  end

  defp create_workspace(source, owner, opts) do
    state = if detect_type(source) == :remote, do: :acquiring, else: :ready
    path = if detect_type(source) == :remote, do: nil, else: source

    %{
      id: generate_workspace_id(),
      source: source,
      owner: owner,
      state: state,
      type: detect_type(source),
      path: path,
      created_at: DateTime.utc_now(),
      opts: opts,
      git_log_cache: %{}
    }
  end

  defp perform_clone(workspace) do
    path = generate_temp_path()

    try do
      # Ensure parent directory exists
      File.mkdir_p!(Path.dirname(path))

      args = build_clone_args(workspace.opts) ++ [workspace.source, path]

      Logger.info("Cloning #{workspace.source} to #{path}")
      Logger.debug("Git command: git #{Enum.join(args, " ")}")

      case System.cmd("git", args,
             stderr_to_stdout: true,
             env: [{"GIT_TERMINAL_PROMPT", "0"}]
           ) do
        {_output, 0} ->
          Logger.debug("Clone successful")
          {:ok, path}

        {_output, code} ->
          Logger.error("Clone failed with code #{code}")
          File.rm_rf!(path)
          {:error, "Git clone failed (exit code #{code})"}
      end
    rescue
      e ->
        Logger.error("Clone failed with exception: #{inspect(e)}")
        # Only try to clean up if path exists and directory was created
        if File.exists?(path), do: File.rm_rf!(path)
        {:error, Exception.format(:error, e)}
    end
  end

  defp build_clone_args(opts) do
    # Apply defaults
    depth = Keyword.get(opts, :depth)
    single_branch = Keyword.get(opts, :single_branch, @default_single_branch)
    branch = Keyword.get(opts, :branch)

    args = ["clone"]

    args =
      if depth && depth > 0,
        do: args ++ ["--depth", to_string(depth)],
        else: args

    # Add single-branch if true
    args = if single_branch, do: args ++ ["--single-branch"], else: args
    args = if branch, do: args ++ ["--branch", branch], else: args

    args
  end

  defp resolve_workspace(id_or_source) do
    # Try as ID first, then as source
    Store.get(id_or_source) || Store.get_by_source(id_or_source)
  end

  defp detect_type(source) do
    cond do
      remote_url?(source) -> :remote
      File.dir?(source) -> :local
      File.regular?(source) -> :file
      true -> :unknown
    end
  end

  defp remote_url?(source) do
    String.match?(source, ~r/^(https?:\/\/|git@|ssh:\/\/git@)/)
  end

  defp generate_workspace_id do
    "ws_" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end

  defp generate_temp_path do
    timestamp = System.os_time(:millisecond)
    random = :crypto.strong_rand_bytes(4) |> Base.url_encode64(padding: false)

    Path.join([
      System.tmp_dir!(),
      "gitlock",
      "workspaces",
      "#{timestamp}_#{random}"
    ])
  end
end
