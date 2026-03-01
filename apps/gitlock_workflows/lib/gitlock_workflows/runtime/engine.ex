defmodule GitlockWorkflows.Runtime.Engine do
  @moduledoc """
  Orchestrates workflow execution and manages execution lifecycle.

  The Engine is responsible for:
  - Loading and preparing workflows for execution
  - Converting workflows to Reactor instances
  - Managing execution state and progress
  - Handling async execution with monitoring
  - Emitting execution events for real-time updates

  ## Usage

      # Synchronous execution
      {:ok, result} = Engine.execute_sync(workflow, %{repo_path: "/path/to/repo"})

      # Asynchronous execution with monitoring
      {:ok, execution_id} = Engine.execute(workflow, %{repo_path: "/path/to/repo"})
      Engine.subscribe_to_execution(execution_id)

  ## Execution States

  - `:pending` - Execution queued but not started
  - `:running` - Currently executing
  - `:completed` - Execution finished successfully
  """
  use GenServer
  require Logger

  alias GitlockWorkflows.Runtime.{Workflow, Validator}

  @typedoc "Execution status information"
  @type execution_status :: %{
          id: String.t(),
          workflow_id: String.t(),
          state: execution_state(),
          progress: float(),
          started_at: DateTime.t() | nil,
          completed_at: DateTime.t() | nil,
          result: term() | nil,
          error: term() | nil,
          metrics: execution_metrics()
        }

  @typedoc "Execution state"
  @type execution_state :: :pending | :running | :completed

  @typedoc "Execution metrics"
  @type execution_metrics :: %{
          nodes_total: non_neg_integer(),
          nodes_completed: non_neg_integer(),
          nodes_failed: non_neg_integer(),
          duration_ms: non_neg_integer() | nil,
          memory_usage_mb: float() | nil
        }

  @typedoc "Execution options"
  @type execution_opts :: [
          {:async, boolean()},
          {:timeout, timeout()},
          {:max_retries, non_neg_integer()},
          {:telemetry_enabled, boolean()}
        ]

  # Client API

  @doc """
  Starts the execution engine.

  Usually called by the supervisor.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Executes a workflow asynchronously.

  Returns immediately with an execution ID. Use `get_execution_status/1` or
  subscribe to telemetry events to monitor progress.

  ## Parameters
    * `workflow` - The workflow to execute
    * `initial_data` - Initial data to pass to the workflow
    * `opts` - Execution options

  ## Options
    * `:timeout` - Maximum execution time (default: 30 minutes)
    * `:max_retries` - Maximum number of retries per node (default: 3)
    * `:telemetry_enabled` - Enable telemetry events (default: true)

  ## Returns
    * `{:ok, execution_id}` - Execution started successfully
    * `{:error, reason}` - Failed to start execution

  ## Examples

      workflow = %Workflow{...}
      {:ok, execution_id} = Engine.execute(workflow, %{repo_path: "/my/repo"})
      
      # Monitor progress
      Engine.subscribe_to_execution(execution_id)
      
      # Check status
      {:ok, status} = Engine.get_execution_status(execution_id)
  """
  @spec execute(Workflow.t(), map(), execution_opts()) :: {:ok, String.t()} | {:error, term()}
  def execute(%Workflow{} = workflow, initial_data \\ %{}, opts \\ []) do
    GenServer.call(__MODULE__, {:execute, workflow, initial_data, opts})
  end

  @doc ~S"""
  Executes a workflow synchronously.

  Blocks until the workflow completes or fails. For long-running workflows,
  consider using `execute/3` with telemetry monitoring instead.

  ## Parameters
    * `workflow` - The workflow to execute
    * `initial_data` - Initial data to pass to the workflow
    * `opts` - Execution options

  ## Returns
    * `{:ok, result}` - Execution completed successfully
    * `{:error, reason}` - Execution failed

  ## Examples

      workflow = %Workflow{...}
      case Engine.execute_sync(workflow, %{repo_path: "/my/repo"}) do
        {:ok, result} -> 
          IO.puts("Hotspots found: #{length(result.hotspots)}")
        {:error, reason} -> 
          IO.puts("Analysis failed: #{reason}")
      end
  """
  @spec execute_sync(Workflow.t(), map(), execution_opts()) :: {:ok, term()} | {:error, term()}
  def execute_sync(%Workflow{} = workflow, initial_data \\ %{}, opts \\ []) do
    opts = Keyword.put(opts, :async, false)

    case execute(workflow, initial_data, opts) do
      {:ok, execution_id} ->
        wait_for_completion(execution_id, Keyword.get(opts, :timeout, :timer.minutes(30)))

      error ->
        error
    end
  end

  @doc ~S"""
  Gets the current status of an execution.

  ## Parameters
    * `execution_id` - ID of the execution

  ## Returns
    * `{:ok, execution_status}` - Status retrieved successfully
    * `{:error, :not_found}` - Execution not found
    * `{:error, reason}` - Failed to get status

  ## Examples

      {:ok, status} = Engine.get_execution_status(execution_id)
      
      case status.state do
        :running -> IO.puts("Progress: #{status.progress}%")
        :completed -> IO.puts("Completed at #{status.completed_at}")
        :failed -> IO.puts("Failed: #{status.error}")
      end
  """
  @spec get_execution_status(String.t()) :: {:ok, execution_status()} | {:error, term()}
  def get_execution_status(execution_id) do
    GenServer.call(__MODULE__, {:get_execution_status, execution_id})
  end

  @doc """
  Lists all executions, optionally filtered.

  ## Parameters
    * `filters` - Optional filters to apply

  ## Filter Options
    * `:workflow_id` - Filter by workflow ID
    * `:state` - Filter by execution state
    * `:limit` - Maximum number of results
    * `:offset` - Number of results to skip

  ## Returns
    List of execution status summaries

  ## Examples

      # Get all executions
      executions = Engine.list_executions()
      
      # Get running executions for a workflow
      running = Engine.list_executions(%{workflow_id: "wf_123", state: :running})
      
      # Get recent executions
      recent = Engine.list_executions(%{limit: 10, offset: 0})
  """
  @spec list_executions(map()) :: [execution_status()]
  def list_executions(filters \\ %{}) do
    GenServer.call(__MODULE__, {:list_executions, filters})
  end

  @doc ~S"""
  Subscribes to execution events.

  The calling process will receive messages about execution progress:
  - `{:execution_started, execution_id}`
  - `{:execution_progress, execution_id, progress}`
  - `{:execution_completed, execution_id, result}`
  - `{:execution_failed, execution_id, error}`
  - `{:execution_cancelled, execution_id}`

  ## Parameters
    * `execution_id` - ID of the execution to monitor

  ## Returns
    * `:ok` - Subscription successful
    * `{:error, reason}` - Subscription failed

  ## Examples

      {:ok, execution_id} = Engine.execute(workflow, data)
      :ok = Engine.subscribe_to_execution(execution_id)
      
      receive do
        {:execution_completed, ^execution_id, result} ->
          IO.puts("Workflow completed successfully!")
        {:execution_failed, ^execution_id, error} ->
          IO.puts("Workflow failed: #{inspect(error)}")
      after
        60_000 -> IO.puts("Timeout waiting for completion")
      end
  """
  @spec subscribe_to_execution(String.t()) :: :ok | {:error, term()}
  def subscribe_to_execution(execution_id) do
    GenServer.call(__MODULE__, {:subscribe_to_execution, execution_id, self()})
  end

  @doc """
  Unsubscribes from execution events.

  ## Parameters
    * `execution_id` - ID of the execution to stop monitoring

  ## Returns
    * `:ok` - Unsubscription successful
    * `{:error, reason}` - Unsubscription failed
  """
  @spec unsubscribe_from_execution(String.t()) :: :ok | {:error, term()}
  def unsubscribe_from_execution(execution_id) do
    GenServer.call(__MODULE__, {:unsubscribe_from_execution, execution_id, self()})
  end

  @doc ~S"""
  Gets engine statistics and metrics.

  ## Returns
    * `map()` - Statistics including total executions, success rate, etc.

  ## Examples

      stats = Engine.get_stats()
      IO.puts("Total executions: #{stats.total_executions}")
      IO.puts("Success rate: #{stats.success_rate}%")
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  # Server Implementation

  @impl GenServer
  def init(_opts) do
    Logger.info("Starting Runtime.Engine")

    # Subscribe to CORRECT Reactor telemetry events
    attach_telemetry_handlers()

    state = %{
      executions: %{},
      subscribers: %{},
      metrics: %{
        total_executions: 0,
        successful_executions: 0,
        failed_executions: 0
      }
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:execute, workflow, initial_data, opts}, _from, state) do
    case prepare_execution(workflow, initial_data, opts) do
      {:ok, execution_id, execution_state} ->
        new_state = put_in(state, [:executions, execution_id], execution_state)

        # Update total executions metric
        new_state = update_in(new_state, [:metrics, :total_executions], &(&1 + 1))

        # Start execution asynchronously
        start_execution_task(execution_id, workflow, initial_data, opts)

        {:reply, {:ok, execution_id}, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_execution_status, execution_id}, _from, state) do
    case get_in(state, [:executions, execution_id]) do
      nil ->
        {:reply, {:error, :not_found}, state}

      execution ->
        status = build_execution_status(execution)
        {:reply, {:ok, status}, state}
    end
  end

  @impl GenServer
  def handle_call({:list_executions, filters}, _from, state) do
    executions =
      state.executions
      |> Map.values()
      |> apply_filters(filters)
      |> Enum.map(&build_execution_status/1)

    {:reply, executions, state}
  end

  @impl GenServer
  def handle_call({:subscribe_to_execution, execution_id, pid}, _from, state) do
    case get_in(state, [:executions, execution_id]) do
      nil ->
        {:reply, {:error, :not_found}, state}

      _execution ->
        # Add subscriber
        subscribers = Map.get(state.subscribers, execution_id, MapSet.new())
        updated_subscribers = MapSet.put(subscribers, pid)
        new_state = put_in(state, [:subscribers, execution_id], updated_subscribers)

        # Monitor the subscriber process
        Process.monitor(pid)

        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call({:unsubscribe_from_execution, execution_id, pid}, _from, state) do
    case get_in(state, [:subscribers, execution_id]) do
      nil ->
        {:reply, :ok, state}

      subscribers ->
        updated_subscribers = MapSet.delete(subscribers, pid)
        new_state = put_in(state, [:subscribers, execution_id], updated_subscribers)
        {:reply, :ok, new_state}
    end
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    total = state.metrics.total_executions
    successful = state.metrics.successful_executions
    failed = state.metrics.failed_executions

    success_rate = if total > 0, do: Float.round(successful / total * 100, 2), else: 0.0

    stats = %{
      total_executions: total,
      successful_executions: successful,
      failed_executions: failed,
      success_rate: success_rate,
      active_executions: count_active_executions(state.executions)
    }

    {:reply, stats, state}
  end

  @impl GenServer
  def handle_info({:execution_started, execution_id}, state) do
    case get_in(state, [:executions, execution_id]) do
      nil ->
        {:noreply, state}

      execution ->
        updated_execution = %{
          execution
          | state: :running,
            started_at: DateTime.utc_now()
        }

        new_state = put_in(state, [:executions, execution_id], updated_execution)

        # Notify subscribers
        notify_subscribers(execution_id, {:execution_started, execution_id}, new_state)

        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info({:execution_completed, execution_id, result}, state) do
    case get_in(state, [:executions, execution_id]) do
      nil ->
        {:noreply, state}

      execution ->
        updated_execution = %{
          execution
          | state: :completed,
            result: result,
            completed_at: DateTime.utc_now(),
            metrics: calculate_final_metrics(execution)
        }

        new_state = put_in(state, [:executions, execution_id], updated_execution)

        # Update global metrics
        new_state = update_in(new_state, [:metrics, :successful_executions], &(&1 + 1))

        # Notify subscribers
        notify_subscribers(execution_id, {:execution_completed, execution_id, result}, new_state)

        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info({:execution_failed, execution_id, error}, state) do
    case get_in(state, [:executions, execution_id]) do
      nil ->
        {:noreply, state}

      execution ->
        updated_execution = %{
          execution
          | state: :failed,
            error: error,
            completed_at: DateTime.utc_now(),
            metrics: calculate_final_metrics(execution)
        }

        new_state = put_in(state, [:executions, execution_id], updated_execution)

        # Update global metrics
        new_state = update_in(new_state, [:metrics, :failed_executions], &(&1 + 1))

        # Notify subscribers
        notify_subscribers(execution_id, {:execution_failed, execution_id, error}, new_state)

        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info({:execution_progress, execution_id, progress}, state) do
    case get_in(state, [:executions, execution_id]) do
      nil ->
        {:noreply, state}

      execution ->
        updated_execution = %{execution | progress: progress}
        new_state = put_in(state, [:executions, execution_id], updated_execution)

        # Notify subscribers
        notify_subscribers(execution_id, {:execution_progress, execution_id, progress}, new_state)

        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info({:node_completed, execution_id, node_id}, state) do
    case get_in(state, [:executions, execution_id]) do
      nil ->
        {:noreply, state}

      execution ->
        # Update metrics - increment completed nodes
        updated_metrics = %{
          execution.metrics
          | nodes_completed: execution.metrics.nodes_completed + 1
        }

        updated_execution = %{execution | metrics: updated_metrics}
        new_state = put_in(state, [:executions, execution_id], updated_execution)

        # Notify subscribers
        notify_subscribers(execution_id, {:node_completed, execution_id, node_id}, new_state)

        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info({:node_failed, execution_id, node_id, error}, state) do
    case get_in(state, [:executions, execution_id]) do
      nil ->
        {:noreply, state}

      execution ->
        # Update metrics - increment failed nodes
        updated_metrics = %{
          execution.metrics
          | nodes_failed: execution.metrics.nodes_failed + 1
        }

        updated_execution = %{execution | metrics: updated_metrics}
        new_state = put_in(state, [:executions, execution_id], updated_execution)

        # Notify subscribers
        notify_subscribers(execution_id, {:node_failed, execution_id, node_id, error}, new_state)

        {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    # Remove dead subscriber from all subscriptions
    new_subscribers =
      state.subscribers
      |> Enum.map(fn {execution_id, subscribers} ->
        {execution_id, MapSet.delete(subscribers, pid)}
      end)
      |> Map.new()

    {:noreply, %{state | subscribers: new_subscribers}}
  end

  # Private Functions

  defp prepare_execution(workflow, initial_data, opts) do
    # Validate workflow
    case Validator.validate_workflow(workflow) do
      {:ok, validated_workflow} ->
        # Convert to Reactor
        case Workflow.to_reactor(validated_workflow) do
          {:ok, reactor_workflow} ->
            execution_id = generate_execution_id()

            execution_state = %{
              id: execution_id,
              workflow_id: workflow.id,
              workflow: reactor_workflow,
              state: :pending,
              progress: 0.0,
              started_at: nil,
              completed_at: nil,
              result: nil,
              error: nil,
              initial_data: initial_data,
              opts: opts,
              metrics: %{
                nodes_total: length(workflow.nodes),
                nodes_completed: 0,
                nodes_failed: 0,
                duration_ms: nil,
                memory_usage_mb: nil
              }
            }

            {:ok, execution_id, execution_state}

          {:error, reason} ->
            {:error, {:reactor_conversion_failed, reason}}
        end

      {:error, reason} ->
        {:error, {:validation_failed, reason}}
    end
  end

  defp start_execution_task(execution_id, workflow, initial_data, opts) do
    engine_pid = self()

    Task.start(fn ->
      Logger.info("Starting execution task for #{execution_id}")

      try do
        # Send started event
        send(engine_pid, {:execution_started, execution_id})

        # Execute the workflow
        case Workflow.to_reactor(workflow) do
          {:ok, reactor_workflow} ->
            Logger.info("Successfully converted workflow to reactor")

            # Setup execution context with proper telemetry metadata
            context = %{
              execution_id: execution_id,
              workflow_id: workflow.id,
              # Add telemetry metadata for Reactor middleware
              telemetry_metadata: %{
                execution_id: execution_id,
                workflow_id: workflow.id
              }
            }

            # Enable telemetry middleware - THIS IS CRUCIAL
            reactor_opts = [
              context: context,
              async?: Keyword.get(opts, :async, true),
              max_retries: Keyword.get(opts, :max_retries, 3),
              # Enable telemetry middleware
              middleware: [
                {Reactor.Middleware.Telemetry, []}
              ]
            ]

            Logger.info("About to call Reactor.run with context: #{inspect(context)}")

            case Reactor.run(reactor_workflow.reactor, initial_data, reactor_opts) do
              {:ok, result} ->
                Logger.info("Reactor.run succeeded")
                send(engine_pid, {:execution_completed, execution_id, result})

              {:error, reason} ->
                Logger.error("Reactor.run failed: #{inspect(reason)}")
                send(engine_pid, {:execution_failed, execution_id, reason})
            end

          {:error, reason} ->
            Logger.error("Failed to convert workflow to reactor: #{inspect(reason)}")
            send(engine_pid, {:execution_failed, execution_id, reason})
        end
      rescue
        error ->
          Logger.error("Exception in execution task: #{inspect(error)}")
          send(engine_pid, {:execution_failed, execution_id, error})
      end
    end)
  end

  defp wait_for_completion(execution_id, timeout) do
    receive do
      {:execution_completed, ^execution_id, result} ->
        {:ok, result}

      {:execution_failed, ^execution_id, error} ->
        {:error, error}

      {:execution_cancelled, ^execution_id} ->
        {:error, :cancelled}
    after
      timeout ->
        {:error, :timeout}
    end
  end

  defp build_execution_status(execution) do
    %{
      id: execution.id,
      workflow_id: execution.workflow_id,
      state: execution.state,
      progress: execution.progress,
      started_at: execution.started_at,
      completed_at: execution.completed_at,
      result: execution.result,
      error: execution.error,
      metrics: execution.metrics
    }
  end

  defp apply_filters(executions, filters) do
    Enum.filter(executions, fn execution ->
      Enum.all?(filters, fn
        {:workflow_id, workflow_id} -> execution.workflow_id == workflow_id
        {:state, state} -> execution.state == state
        # Handle limit separately
        {:limit, _} -> true
        # Handle offset separately
        {:offset, _} -> true
        _ -> true
      end)
    end)
    |> maybe_limit_offset(filters)
  end

  defp maybe_limit_offset(executions, filters) do
    executions
    |> maybe_offset(Map.get(filters, :offset))
    |> maybe_limit(Map.get(filters, :limit))
  end

  defp maybe_offset(executions, nil), do: executions
  defp maybe_offset(executions, offset), do: Enum.drop(executions, offset)

  defp maybe_limit(executions, nil), do: executions
  defp maybe_limit(executions, limit), do: Enum.take(executions, limit)

  defp notify_subscribers(execution_id, message, state) do
    case get_in(state, [:subscribers, execution_id]) do
      nil ->
        :ok

      subscribers ->
        Enum.each(subscribers, fn pid ->
          send(pid, message)
        end)
    end
  end

  defp calculate_final_metrics(execution) do
    duration =
      if execution.started_at && execution.completed_at do
        DateTime.diff(execution.completed_at, execution.started_at, :millisecond)
      else
        nil
      end

    %{
      execution.metrics
      | duration_ms: duration,
        memory_usage_mb: get_memory_usage()
    }
  end

  defp get_memory_usage do
    case :erlang.memory(:total) do
      memory when is_integer(memory) -> memory / 1024 / 1024
      _ -> nil
    end
  end

  defp generate_execution_id do
    "exec_" <> (:crypto.strong_rand_bytes(8) |> Base.url_encode64(padding: false))
  end

  defp count_active_executions(executions) do
    executions
    |> Map.values()
    |> Enum.count(fn execution ->
      execution.state in [:pending, :running, :paused]
    end)
  end

  defp attach_telemetry_handlers do
    # Attach to the CORRECT Reactor telemetry events
    events = [
      # Reactor run events
      [:reactor, :run, :start],
      [:reactor, :run, :stop],
      # Reactor step events - THESE ARE THE CORRECT NAMES
      [:reactor, :step, :run, :start],
      [:reactor, :step, :run, :stop],
      # Process events for concurrent execution
      [:reactor, :step, :process, :start],
      [:reactor, :step, :process, :stop],
      # Compensation events for saga rollback
      [:reactor, :step, :compensate, :start],
      [:reactor, :step, :compensate, :stop],
      # Undo events for transaction rollback
      [:reactor, :step, :undo, :start],
      [:reactor, :step, :undo, :stop]
    ]

    Logger.info("Attaching telemetry handlers for events: #{inspect(events)}")

    # Use a module function instead of anonymous function to avoid performance warning
    :telemetry.attach_many(
      "runtime-engine-reactor",
      events,
      &__MODULE__.handle_telemetry_event/4,
      %{}
    )
  end

  # Make the telemetry handler a public module function
  def handle_telemetry_event([:reactor, :run, :start], _measurements, metadata, _config) do
    # Extract execution_id from telemetry metadata
    if execution_id = get_execution_id_from_metadata(metadata) do
      Logger.debug("Reactor run started for execution: #{execution_id}")
      # Engine already handles execution start, so we don't need to do anything here
    end
  end

  def handle_telemetry_event([:reactor, :run, :stop], _measurements, metadata, _config) do
    # Extract execution_id from telemetry metadata
    if execution_id = get_execution_id_from_metadata(metadata) do
      Logger.debug("Reactor run stopped for execution: #{execution_id}")
      # Engine will handle completion based on success/failure
    end
  end

  def handle_telemetry_event([:reactor, :step, :run, :start], _measurements, metadata, _config) do
    if execution_id = get_execution_id_from_metadata(metadata) do
      # Get the engine PID and send progress update
      if engine_pid = GenServer.whereis(__MODULE__) do
        Logger.debug("Step started for execution: #{execution_id}")
        send(engine_pid, {:execution_progress, execution_id, calculate_progress(metadata)})
      end
    end
  end

  def handle_telemetry_event([:reactor, :step, :run, :stop], _measurements, metadata, _config) do
    if execution_id = get_execution_id_from_metadata(metadata) do
      # Get the engine PID and send progress update
      if engine_pid = GenServer.whereis(__MODULE__) do
        step_name = get_step_name_from_metadata(metadata)
        Logger.debug("Step completed for execution: #{execution_id}, step: #{step_name}")
        send(engine_pid, {:node_completed, execution_id, step_name})
        send(engine_pid, {:execution_progress, execution_id, calculate_progress(metadata)})
      end
    end
  end

  def handle_telemetry_event([:reactor, :step, :process, :start], _, metadata, _) do
    if execution_id = get_execution_id_from_metadata(metadata) do
      step_name = get_step_name_from_metadata(metadata)
      Logger.debug("Step process started for execution: #{execution_id}, step: #{step_name}")
    end
  end

  def handle_telemetry_event([:reactor, :step, :process, :stop], _measurements, metadata, _config) do
    if execution_id = get_execution_id_from_metadata(metadata) do
      step_name = get_step_name_from_metadata(metadata)
      Logger.debug("Step process stopped for execution: #{execution_id}, step: #{step_name}")
    end
  end

  def handle_telemetry_event([:reactor, :step, :compensate, :start], _, metadata, _) do
    if execution_id = get_execution_id_from_metadata(metadata) do
      step_name = get_step_name_from_metadata(metadata)
      Logger.debug("Step compensation started for execution: #{execution_id}, step: #{step_name}")
    end
  end

  def handle_telemetry_event([:reactor, :step, :compensate, :stop], _, metadata, _) do
    if execution_id = get_execution_id_from_metadata(metadata) do
      step_name = get_step_name_from_metadata(metadata)
      Logger.debug("Step compensation stopped for execution: #{execution_id}, step: #{step_name}")
    end
  end

  def handle_telemetry_event([:reactor, :step, :undo, :start], _measurements, metadata, _config) do
    if execution_id = get_execution_id_from_metadata(metadata) do
      step_name = get_step_name_from_metadata(metadata)
      Logger.debug("Step undo started for execution: #{execution_id}, step: #{step_name}")
    end
  end

  def handle_telemetry_event([:reactor, :step, :undo, :stop], _measurements, metadata, _config) do
    if execution_id = get_execution_id_from_metadata(metadata) do
      step_name = get_step_name_from_metadata(metadata)
      Logger.debug("Step undo stopped for execution: #{execution_id}, step: #{step_name}")
    end
  end

  # Helper functions to extract data from Reactor telemetry metadata
  defp get_execution_id_from_metadata(metadata) do
    # Try different possible locations for execution_id
    metadata[:execution_id] ||
      get_in(metadata, [:telemetry_metadata, :execution_id]) ||
      get_in(metadata, [:context, :execution_id])
  end

  defp get_step_name_from_metadata(metadata) do
    # Try different possible locations for step name
    case metadata[:step] do
      %{name: name} -> to_string(name)
      step when is_binary(step) -> step
      step when is_atom(step) -> to_string(step)
      _ -> "unknown"
    end
  end

  defp calculate_progress(metadata) do
    # This is a simplified progress calculation
    # In a real implementation, you'd track completed vs total steps
    # For now, we'll just return a fixed value
    50.0
  end
end
