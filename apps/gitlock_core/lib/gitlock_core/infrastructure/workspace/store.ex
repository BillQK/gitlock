defmodule GitlockCore.Infrastructure.Workspace.Store do
  @moduledoc """
  Persistent state storage for workspace management using Agent.

  This module provides a simple, crash-resistant storage mechanism for tracking
  active workspaces. The Agent pattern ensures state survives GenServer crashes
  while keeping operations synchronous and atomic.

  ## State Structure

  The store maintains three indexes for efficient lookups:
  - `workspaces`: Primary storage by workspace ID
  - `by_source`: Index for finding workspaces by their source URL/path
  - `monitors`: Tracks process monitors (though not actively used here)

  ## Thread Safety

  All operations are serialized through the Agent, making them thread-safe
  by default. This is sufficient for single-node deployments.
  """
  use Agent
  require Logger

  defstruct workspaces: %{},
            by_source: %{},
            monitors: %{}

  @typedoc "The internal state structure"
  @type t :: %__MODULE__{
          workspaces: %{String.t() => map()},
          by_source: %{String.t() => String.t()},
          monitors: %{pid() => reference()}
        }

  @typedoc "Workspace ID"
  @type workspace_id :: String.t()

  @typedoc "Source URL or path"
  @type source :: String.t()

  @typedoc "Workspace data structure"
  @type workspace :: %{
          id: workspace_id(),
          source: source(),
          path: String.t() | nil,
          type: :remote | :local | :file | :unknown,
          state: :acquiring | :ready | :failed | :released,
          owner: pid() | nil,
          created_at: DateTime.t(),
          opts: keyword()
        }

  @doc """
  Starts the workspace store.
  """
  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(_opts) do
    Logger.info("Starting Workspace.Store")
    Agent.start_link(fn -> %__MODULE__{} end, name: __MODULE__)
  end

  @doc """
  Stores a workspace in the store.
  """
  @spec put(workspace_id(), workspace()) :: :ok
  def put(id, workspace) do
    Agent.update(__MODULE__, fn state ->
      Logger.info("Storing workspace #{id} for source #{workspace.source}")

      %{
        state
        | workspaces: Map.put(state.workspaces, id, workspace),
          by_source: Map.put(state.by_source, workspace.source, id)
      }
    end)
  end

  @doc """
  Retrieves a workspace by its ID.
  """
  @spec get(workspace_id()) :: workspace() | nil
  def get(id) do
    Agent.get(__MODULE__, fn state ->
      Map.get(state.workspaces, id)
    end)
  end

  @doc """
  Retrieves a workspace by its source URL/path.
  """
  @spec get_by_source(source()) :: workspace() | nil
  def get_by_source(source) do
    Agent.get(__MODULE__, fn state ->
      case Map.get(state.by_source, source) do
        nil -> nil
        id -> Map.get(state.workspaces, id)
      end
    end)
  end

  @doc """
  Updates an existing workspace with new data.
  """
  @spec update(workspace_id(), map()) :: :ok
  def update(id, updates) do
    Agent.update(__MODULE__, fn state ->
      Logger.info("Updating workspace #{id}: #{inspect(updates)}")

      case Map.get(state.workspaces, id) do
        nil ->
          state

        workspace ->
          updated_workspace = Map.merge(workspace, updates)
          %{state | workspaces: Map.put(state.workspaces, id, updated_workspace)}
      end
    end)
  end

  @doc """
  Deletes a workspace from the store.
  """
  @spec delete(workspace_id()) :: :ok
  def delete(id) do
    Agent.update(__MODULE__, fn state ->
      case Map.get(state.workspaces, id) do
        nil ->
          state

        workspace ->
          Logger.warning("Deleting workspace #{id}")

          %{
            state
            | workspaces: Map.delete(state.workspaces, id),
              by_source: Map.delete(state.by_source, workspace.source)
          }
      end
    end)
  end

  @doc """
  Lists all workspaces in the store.
  """
  @spec list() :: [workspace()]
  def list do
    Agent.get(__MODULE__, fn state ->
      Map.values(state.workspaces)
    end)
  end

  @doc """
  Lists workspaces by state.
  """
  @spec list_by_state(atom() | [atom()]) :: [workspace()]
  def list_by_state(states) when is_list(states) do
    Agent.get(__MODULE__, fn state ->
      state.workspaces
      |> Map.values()
      |> Enum.filter(&(&1.state in states))
    end)
  end

  def list_by_state(single_state) do
    list_by_state([single_state])
  end

  @doc """
  Lists all workspaces owned by a specific process.
  """
  @spec list_by_owner(pid()) :: [workspace()]
  def list_by_owner(owner_pid) do
    Agent.get(__MODULE__, fn state ->
      state.workspaces
      |> Map.values()
      |> Enum.filter(&(&1.owner == owner_pid))
    end)
  end

  @doc """
  Gets the current state of the store.

  This is mainly useful for debugging and testing.
  """
  @spec get_state() :: t()
  def get_state do
    Agent.get(__MODULE__, & &1)
  end

  @doc """
  Resets the store to empty state.

  ⚠️ **Warning**: This deletes all workspace data. Use only in tests.
  """
  @spec reset() :: :ok
  def reset do
    Logger.warning("Resetting Workspace.Store - all data will be lost")
    Agent.update(__MODULE__, fn _ -> %__MODULE__{} end)
  end

  @doc """
  Updates the last accessed time for a workspace.
  """
  @spec touch(workspace_id()) :: :ok
  def touch(id) do
    Agent.update(__MODULE__, fn state ->
      case Map.get(state.workspaces, id) do
        nil ->
          state

        workspace ->
          updated = Map.put(workspace, :last_accessed, DateTime.utc_now())
          %{state | workspaces: Map.put(state.workspaces, id, updated)}
      end
    end)
  end

  @doc """
  Lists workspaces that haven't been accessed since the given cutoff time.

  Uses `last_accessed` if available, otherwise falls back to `created_at`.
  """
  @spec list_inactive_since(DateTime.t()) :: [workspace()]
  def list_inactive_since(cutoff_time) do
    Agent.get(__MODULE__, fn state ->
      state.workspaces
      |> Map.values()
      |> Enum.filter(fn workspace ->
        # Use last_accessed if available, otherwise created_at
        access_time = Map.get(workspace, :last_accessed, workspace.created_at)
        DateTime.compare(access_time, cutoff_time) == :lt
      end)
    end)
  end
end
