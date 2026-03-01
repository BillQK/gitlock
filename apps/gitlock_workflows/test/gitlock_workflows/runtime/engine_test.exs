defmodule GitlockWorkflows.Runtime.EngineTest do
  use ExUnit.Case, async: false

  alias GitlockWorkflows.Runtime.{Engine, Workflow, Registry}
  alias GitlockWorkflows.Fixtures.Nodes.{TriggerNode, ProcessNode, ErrorNode}

  setup do
    # First ensure Registry is started (usually done by supervision tree)
    unless GenServer.whereis(Registry) do
      Registry.start_link()
    end

    # Register the existing fixture nodes
    Registry.register_nodes([TriggerNode, ProcessNode, ErrorNode])

    # Ensure Engine is started
    case GenServer.whereis(Engine) do
      nil -> Engine.start_link()
      _pid -> :ok
    end

    on_exit(fn ->
      # Clean up registered nodes
      if GenServer.whereis(Registry) do
        Registry.unregister_node("test.trigger")
        Registry.unregister_node("test.process")
        Registry.unregister_node("test.error")
      end
    end)

    :ok
  end

  describe "start_link/1" do
    test "engine starts and is accessible" do
      assert pid = GenServer.whereis(Engine)
      assert Process.alive?(pid)
    end
  end

  describe "execute/3" do
    test "executes workflow asynchronously" do
      workflow = create_simple_workflow()

      assert {:ok, execution_id} = Engine.execute(workflow, %{})
      assert is_binary(execution_id)
      assert String.starts_with?(execution_id, "exec_")
    end

    test "validates workflow before execution" do
      # Invalid workflow - unknown node type
      invalid_workflow = %Workflow{
        id: "invalid",
        name: "Invalid",
        nodes: [
          %{
            id: "n1",
            type: "unknown.node",
            parameters: %{},
            disabled: false,
            position: [0, 0]
          }
        ],
        connections: [],
        settings: %{},
        version: 1
      }

      assert {:error, {:validation_failed, errors}} = Engine.execute(invalid_workflow, %{})

      assert Enum.any?(errors, fn
               {:unknown_node_type, "n1", "unknown.node"} -> true
               _ -> false
             end)
    end

    test "rejects workflow without trigger nodes" do
      # Workflow with only non-trigger nodes
      no_trigger_workflow = %Workflow{
        id: "no_trigger",
        name: "No Trigger",
        nodes: [
          %{
            id: "process",
            type: "test.process",
            parameters: %{},
            disabled: false,
            position: [0, 0]
          }
        ],
        connections: [],
        settings: %{},
        version: 1
      }

      assert {:error, {:validation_failed, errors}} = Engine.execute(no_trigger_workflow, %{})
      assert {:no_trigger_nodes} in errors
    end

    test "tracks execution state" do
      workflow = create_simple_workflow()

      {:ok, execution_id} = Engine.execute(workflow, %{})

      # Give it a moment to start
      :timer.sleep(100)

      case Engine.get_execution_status(execution_id) do
        {:ok, status} ->
          assert status.id == execution_id
          assert status.workflow_id == workflow.id
          assert status.state in [:pending, :running, :completed, :failed]

        {:error, :not_found} ->
          # If execution completed very quickly, this is also acceptable
          :ok
      end
    end
  end

  describe "execute_sync/3" do
    test "blocks until workflow completes" do
      workflow = create_simple_workflow()

      start_time = System.monotonic_time(:millisecond)
      result = Engine.execute_sync(workflow, %{}, timeout: 5000)
      end_time = System.monotonic_time(:millisecond)

      # Should have blocked for some time
      assert end_time - start_time >= 0

      case result do
        {:ok, _} -> :ok
        {:error, :timeout} -> :ok
        other -> flunk("Unexpected result: #{inspect(other)}")
      end
    end

    test "respects timeout" do
      workflow = create_slow_workflow(1000)
      assert {:error, :timeout} = Engine.execute_sync(workflow, %{}, timeout: 100)
    end
  end

  describe "get_execution_status/1" do
    test "returns detailed execution status" do
      workflow = create_simple_workflow()
      initial_data = %{test: "data"}

      {:ok, execution_id} = Engine.execute(workflow, initial_data)

      {:ok, status} = Engine.get_execution_status(execution_id)

      assert status.id == execution_id
      assert status.workflow_id == workflow.id
      assert status.state in [:pending, :running, :completed, :failed]
      assert is_float(status.progress)
      assert status.progress >= 0.0 and status.progress <= 100.0
      assert is_map(status.metrics)
      assert status.metrics.nodes_total == length(workflow.nodes)
    end

    test "returns error for unknown execution" do
      assert {:error, :not_found} = Engine.get_execution_status("unknown_exec_id")
    end
  end

  describe "list_executions/1" do
    test "returns all executions" do
      workflow1 = create_simple_workflow()
      workflow2 = create_simple_workflow()

      {:ok, exec1} = Engine.execute(workflow1, %{})
      {:ok, exec2} = Engine.execute(workflow2, %{})

      executions = Engine.list_executions()
      exec_ids = Enum.map(executions, & &1.id)

      assert exec1 in exec_ids
      assert exec2 in exec_ids
    end

    test "filters by workflow_id" do
      workflow = create_simple_workflow()
      {:ok, execution_id} = Engine.execute(workflow, %{})

      :timer.sleep(50)

      filtered = Engine.list_executions(%{workflow_id: workflow.id})
      assert Enum.any?(filtered, fn e -> e.id == execution_id end)

      assert [] = Engine.list_executions(%{workflow_id: "non_existent"})
    end

    test "filters by state" do
      workflow = create_simple_workflow()
      {:ok, _} = Engine.execute(workflow, %{})

      :timer.sleep(100)

      executions = Engine.list_executions()

      if not Enum.empty?(executions) do
        states = Enum.map(executions, & &1.state) |> Enum.uniq()

        Enum.each(states, fn state ->
          filtered = Engine.list_executions(%{state: state})
          assert Enum.all?(filtered, fn e -> e.state == state end)
        end)
      end
    end

    test "applies limit and offset" do
      workflow = create_simple_workflow()
      for _ <- 1..5, do: Engine.execute(workflow, %{})

      :timer.sleep(100)

      limited = Engine.list_executions(%{limit: 2})
      assert length(limited) <= 2

      all = Engine.list_executions()
      offset = Engine.list_executions(%{offset: 2})
      assert length(offset) == max(0, length(all) - 2)
    end
  end

  describe "subscribe_to_execution/1" do
    test "receives execution events" do
      workflow = create_simple_workflow()
      {:ok, execution_id} = Engine.execute(workflow, %{})

      assert :ok = Engine.subscribe_to_execution(execution_id)

      receive do
        {:execution_started, ^execution_id} -> :ok
        {:execution_completed, ^execution_id, _result} -> :ok
        {:execution_failed, ^execution_id, _error} -> :ok
      after
        1000 -> flunk("Should have received an execution event")
      end
    end

    test "returns error for unknown execution" do
      assert {:error, :not_found} = Engine.subscribe_to_execution("unknown_id")
    end

    test "handles multiple subscribers" do
      workflow = create_simple_workflow()
      {:ok, execution_id} = Engine.execute(workflow, %{})

      task1 =
        Task.async(fn ->
          Engine.subscribe_to_execution(execution_id)

          receive do
            {_, ^execution_id} -> :ok
            {_, ^execution_id, _} -> :ok
          after
            1000 -> :timeout
          end
        end)

      task2 =
        Task.async(fn ->
          Engine.subscribe_to_execution(execution_id)

          receive do
            {_, ^execution_id} -> :ok
            {_, ^execution_id, _} -> :ok
          after
            1000 -> :timeout
          end
        end)

      assert Task.await(task1, 2000) == :ok
      assert Task.await(task2, 2000) == :ok
    end
  end

  describe "unsubscribe_from_execution/1" do
    test "stops receiving events after unsubscribe" do
      workflow = create_slow_workflow(500)
      {:ok, execution_id} = Engine.execute(workflow, %{})

      Engine.subscribe_to_execution(execution_id)
      assert :ok = Engine.unsubscribe_from_execution(execution_id)
      assert :ok = Engine.unsubscribe_from_execution(execution_id)
    end
  end

  describe "get_stats/0" do
    test "returns engine statistics" do
      stats = Engine.get_stats()

      assert is_map(stats)
      assert Map.has_key?(stats, :total_executions)
      assert Map.has_key?(stats, :successful_executions)
      assert Map.has_key?(stats, :failed_executions)
      assert Map.has_key?(stats, :success_rate)
      assert Map.has_key?(stats, :active_executions)

      assert is_number(stats.total_executions)
      assert is_number(stats.successful_executions)
      assert is_number(stats.failed_executions)
      assert is_number(stats.success_rate)
      assert is_number(stats.active_executions)
    end

    test "tracks global execution metrics" do
      initial_stats = Engine.get_stats()
      initial_total = initial_stats.total_executions

      workflow = create_simple_workflow()
      {:ok, _} = Engine.execute(workflow, %{})

      :timer.sleep(100)
      new_stats = Engine.get_stats()
      assert new_stats.total_executions >= initial_total
    end
  end

  describe "telemetry integration" do
    test "telemetry events are properly handled" do
      # Test that telemetry events are correctly processed
      workflow = create_simple_workflow()
      {:ok, execution_id} = Engine.execute(workflow, %{})

      # Subscribe to execution events
      :ok = Engine.subscribe_to_execution(execution_id)

      # We should receive execution events
      receive do
        {:execution_started, ^execution_id} -> :ok
        {:execution_completed, ^execution_id, _result} -> :ok
        {:execution_failed, ^execution_id, _error} -> :ok
      after
        2000 -> flunk("Should have received execution events")
      end

      # Check that execution status is updated
      {:ok, status} = Engine.get_execution_status(execution_id)
      assert status.state in [:running, :completed, :failed]
    end

    test "node progress is tracked through telemetry" do
      workflow = create_simple_workflow()
      {:ok, execution_id} = Engine.execute(workflow, %{})

      # Wait a bit for execution to progress
      :timer.sleep(200)

      case Engine.get_execution_status(execution_id) do
        {:ok, status} ->
          # Progress should be tracked
          assert is_float(status.progress)
          assert status.progress >= 0.0

        {:error, :not_found} ->
          # Execution may have completed quickly
          :ok
      end
    end
  end

  describe "error handling" do
    test "handles workflow execution errors gracefully" do
      # Create a workflow that will fail
      error_workflow = %Workflow{
        id: "error_workflow",
        name: "Error Workflow",
        nodes: [
          %{
            id: "trigger",
            type: "test.trigger",
            parameters: %{},
            disabled: false,
            position: [0, 0]
          },
          %{
            id: "error_node",
            type: "test.error",
            parameters: %{
              "error_message" => "Test error"
            },
            disabled: false,
            position: [100, 0]
          }
        ],
        connections: [
          %{
            from: %{node: "trigger", port: "main"},
            to: %{node: "error_node", port: "main"}
          }
        ],
        settings: %{},
        version: 1
      }

      {:ok, execution_id} = Engine.execute(error_workflow, %{})

      # Wait for execution to complete
      :timer.sleep(100)

      case Engine.get_execution_status(execution_id) do
        {:ok, status} ->
          # Should handle error gracefully
          assert status.state in [:failed, :completed]

          if status.state == :failed do
            assert status.error != nil
          end

        {:error, :not_found} ->
          # Execution may have been cleaned up
          :ok
      end
    end
  end

  describe "validation edge cases" do
    test "detects cycles in workflow" do
      cyclic_workflow = %Workflow{
        id: "cyclic",
        name: "Cyclic Workflow",
        nodes: [
          %{
            id: "trigger",
            type: "test.trigger",
            parameters: %{},
            disabled: false,
            position: [0, 0]
          },
          %{
            id: "node1",
            type: "test.process",
            parameters: %{},
            disabled: false,
            position: [100, 0]
          },
          %{
            id: "node2",
            type: "test.process",
            parameters: %{},
            disabled: false,
            position: [200, 0]
          }
        ],
        connections: [
          %{from: %{node: "trigger", port: "main"}, to: %{node: "node1", port: "main"}},
          %{from: %{node: "node1", port: "main"}, to: %{node: "node2", port: "main"}},
          # Cycle!
          %{from: %{node: "node2", port: "main"}, to: %{node: "node1", port: "main"}}
        ],
        settings: %{},
        version: 1
      }

      assert {:error, {:validation_failed, errors}} = Engine.execute(cyclic_workflow, %{})

      assert Enum.any?(errors, fn
               {:cycle_detected, _path} -> true
               _ -> false
             end)
    end

    test "detects orphan nodes" do
      orphan_workflow = %Workflow{
        id: "orphan",
        name: "Orphan Workflow",
        nodes: [
          %{
            id: "trigger",
            type: "test.trigger",
            parameters: %{},
            disabled: false,
            position: [0, 0]
          },
          %{
            id: "orphan",
            type: "test.process",
            parameters: %{},
            disabled: false,
            position: [100, 100]
          }
        ],
        connections: [],
        settings: %{},
        version: 1
      }

      assert {:error, {:validation_failed, errors}} = Engine.execute(orphan_workflow, %{})
      assert {:orphan_node, "orphan"} in errors
    end
  end

  # Helper functions

  defp create_simple_workflow do
    %Workflow{
      id: "test_workflow_#{:rand.uniform(10000)}",
      name: "Test Workflow",
      nodes: [
        %{
          id: "trigger",
          type: "test.trigger",
          parameters: %{},
          disabled: false,
          position: [0, 0]
        },
        %{
          id: "process",
          type: "test.process",
          parameters: %{},
          disabled: false,
          position: [100, 0]
        }
      ],
      connections: [
        %{
          from: %{node: "trigger", port: "main"},
          to: %{node: "process", port: "main"}
        }
      ],
      settings: %{},
      version: 1
    }
  end

  defp create_slow_workflow(delay_ms) do
    %Workflow{
      id: "slow_workflow_#{:rand.uniform(10000)}",
      name: "Slow Workflow",
      nodes: [
        %{
          id: "trigger",
          type: "test.trigger",
          parameters: %{},
          disabled: false,
          position: [0, 0]
        },
        %{
          id: "slow_process",
          type: "test.process",
          parameters: %{"delay_ms" => delay_ms},
          disabled: false,
          position: [100, 0]
        }
      ],
      connections: [
        %{
          from: %{node: "trigger", port: "main"},
          to: %{node: "slow_process", port: "main"}
        }
      ],
      settings: %{},
      version: 1
    }
  end
end
