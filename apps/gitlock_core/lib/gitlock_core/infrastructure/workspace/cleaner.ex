defmodule GitlockCore.Infrastructure.Workspace.Cleaner do
  @moduledoc """
  Handles periodic cleanup of inactive workspaces.

  This GenServer runs independently from the Manager, checking for and
  removing workspaces that haven't been accessed within the configured interval.

  ## State-Aware Cleanup

  The cleaner respects workspace states:
  - `:ready` - Normal cleanup based on last_accessed time
  - `:released` - Priority cleanup (user explicitly finished)
  - `:failed` - Cleanup old failed attempts
  - `:acquiring` - Protected from cleanup (except if stuck > 30 minutes)
  """
  use GenServer
  require Logger

  alias GitlockCore.Infrastructure.Workspace.Store

  @default_cleanup_interval :timer.minutes(10)
  @stuck_acquisition_timeout :timer.minutes(30)

  # Client API

  @doc """
  Starts the workspace cleaner.
  """
  def start_link(_opts) do
    if enabled?() do
      Logger.info("Starting Workspace.Cleaner with interval: #{cleanup_interval() / 1000}s")
      GenServer.start_link(__MODULE__, [], name: __MODULE__)
    else
      :ignore
    end
  end

  @doc """
  Manually triggers a cleanup cycle.
  Useful for testing or administrative purposes.
  """
  @spec cleanup_now() :: :ok | {:error, term()}
  def cleanup_now do
    if Process.whereis(__MODULE__) do
      GenServer.cast(__MODULE__, :cleanup_now)
    else
      {:error, :cleaner_not_running}
    end
  end

  @doc """
  Gets the current cleanup statistics.
  """
  @spec stats() :: map() | {:error, term()}
  def stats do
    if Process.whereis(__MODULE__) do
      GenServer.call(__MODULE__, :get_stats)
    else
      {:error, :cleaner_not_running}
    end
  end

  # Server Implementation

  @impl GenServer
  def init(_opts) do
    # Schedule first cleanup
    schedule_cleanup()

    {:ok,
     %{
       last_cleanup: DateTime.utc_now(),
       cleanup_count: 0,
       total_deleted: 0
     }}
  end

  @impl GenServer
  def handle_info(:cleanup_workspaces, state) do
    new_state = perform_cleanup(state)

    # Schedule next cleanup
    schedule_cleanup()

    {:noreply, new_state}
  end

  @impl GenServer
  def handle_cast(:cleanup_now, state) do
    new_state = perform_cleanup(state)
    {:noreply, new_state}
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    stats = %{
      last_cleanup: state.last_cleanup,
      cleanup_runs: state.cleanup_count,
      total_deleted: state.total_deleted,
      cleanup_interval: cleanup_interval(),
      next_cleanup_in: time_until_next_cleanup()
    }

    {:reply, stats, state}
  end

  # Private Functions

  defp perform_cleanup(state) do
    current_time = DateTime.utc_now()
    cutoff_time = DateTime.add(current_time, -cleanup_interval(), :millisecond)

    # Get all inactive workspaces
    inactive_workspaces = Store.list_inactive_since(cutoff_time)

    # Separate by state for different handling
    {deletable, protected} = Enum.split_with(inactive_workspaces, &deletable_workspace?/1)

    # Handle stuck acquisitions separately
    stuck_acquisitions = find_stuck_acquisitions(current_time)
    all_deletable = deletable ++ stuck_acquisitions

    # Log protection
    if length(protected) > 0 do
      Logger.debug("Protected #{length(protected)} acquiring workspaces from cleanup")
    end

    # Clean up eligible workspaces
    deleted_count = length(all_deletable)

    Enum.each(all_deletable, fn workspace ->
      Logger.info(
        "Cleaning up #{workspace.state} workspace #{workspace.id} (#{workspace.source})"
      )

      cleanup_workspace_files(workspace)
      Store.delete(workspace.id)
    end)

    if deleted_count > 0 do
      Logger.info("Cleaned up #{deleted_count} workspaces")
    end

    %{
      state
      | last_cleanup: current_time,
        cleanup_count: state.cleanup_count + 1,
        total_deleted: state.total_deleted + deleted_count
    }
  end

  defp deletable_workspace?(workspace) do
    # States eligible for normal cleanup
    workspace.state in [:ready, :released, :failed]
  end

  defp find_stuck_acquisitions(current_time) do
    # Find acquisitions that have been running too long
    stuck_threshold = DateTime.add(current_time, -@stuck_acquisition_timeout, :millisecond)

    Store.list_by_state(:acquiring)
    |> Enum.filter(fn workspace ->
      DateTime.compare(workspace.created_at, stuck_threshold) == :lt
    end)
    |> tap(fn stuck_workspaces ->
      if length(stuck_workspaces) > 0 do
        Logger.warning("Found #{length(stuck_workspaces)} stuck acquisitions")
      end
    end)
  end

  defp cleanup_workspace_files(workspace) do
    case workspace.type do
      :remote when is_binary(workspace.path) ->
        if workspace.path && File.exists?(workspace.path) do
          # Safety check - ensure path contains our marker
          if String.contains?(workspace.path, "gitlock") do
            Logger.debug("Removing files for workspace #{workspace.id}: #{workspace.path}")
            File.rm_rf!(workspace.path)
          else
            Logger.warning("Skipping cleanup of suspicious path: #{workspace.path}")
          end
        end

      _ ->
        # Local files and others - don't delete actual files
        :ok
    end
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_workspaces, cleanup_interval())
  end

  defp cleanup_interval do
    Application.get_env(:gitlock_core, :workspace_cleanup_interval, @default_cleanup_interval)
  end

  defp enabled? do
    Application.get_env(:gitlock_core, :workspace_cleanup_enabled, true)
  end

  defp time_until_next_cleanup do
    cleanup_interval()
  end
end
