defmodule GitlockWorkflows.Runtime.ContextTest do
  use ExUnit.Case, async: true

  alias GitlockWorkflows.Runtime.Context

  describe "new/3" do
    test "creates a new context with required fields" do
      execution_id = "exec_123"
      workflow_id = "workflow_456"

      context = Context.new(execution_id, workflow_id)

      assert context.execution_id == execution_id
      assert context.workflow_id == workflow_id
      assert is_nil(context.workflow_name)
      assert context.variables == %{}
      assert context.credentials == %{}
      assert is_binary(context.temp_storage)
      assert is_nil(context.workspace_path)
      assert %DateTime{} = context.start_time
      assert context.node_executions == %{}
      assert context.tags == %{}
      assert context.options == %{}
    end

    test "creates context with optional parameters" do
      context =
        Context.new("exec_123", "workflow_456",
          workflow_name: "Test Workflow",
          workspace_path: "/tmp/workspace",
          credentials: %{"github_token" => "secret"},
          tags: %{environment: "test"},
          options: %{timeout: 5000}
        )

      assert context.workflow_name == "Test Workflow"
      assert context.workspace_path == "/tmp/workspace"
      assert context.credentials == %{"github_token" => "secret"}
      assert context.tags == %{environment: "test"}
      assert context.options == %{timeout: 5000}
    end

    test "creates temporary storage directory" do
      context = Context.new("exec_123", "workflow_456")

      assert File.dir?(context.temp_storage)
      assert String.contains?(context.temp_storage, "exec_123")

      # Cleanup
      File.rm_rf!(context.temp_storage)
    end
  end

  describe "get_execution_id/1 and get_workflow_id/1" do
    setup do
      context = Context.new("exec_123", "workflow_456")
      {:ok, context: context}
    end

    test "returns execution id", %{context: context} do
      assert Context.get_execution_id(context) == "exec_123"
    end

    test "returns workflow id", %{context: context} do
      assert Context.get_workflow_id(context) == "workflow_456"
    end
  end

  describe "variable management" do
    setup do
      context = Context.new("exec_123", "workflow_456")
      {:ok, context: context}
    end

    test "get_variable returns nil for non-existent variable", %{context: context} do
      assert Context.get_variable(context, "missing") == nil
    end

    test "set and get variable", %{context: context} do
      context = Context.set_variable(context, "test_key", "test_value")
      assert Context.get_variable(context, "test_key") == "test_value"
    end

    test "set variable with complex data", %{context: context} do
      data = %{
        files: ["file1.ex", "file2.ex"],
        metrics: %{count: 10, complexity: 5.5}
      }

      context = Context.set_variable(context, "analysis_result", data)
      assert Context.get_variable(context, "analysis_result") == data
    end

    test "get_variables returns requested variables", %{context: context} do
      context =
        context
        |> Context.set_variable("var1", "value1")
        |> Context.set_variable("var2", "value2")
        |> Context.set_variable("var3", "value3")

      result = Context.get_variables(context, ["var1", "var3"])
      assert result == %{"var1" => "value1", "var3" => "value3"}
    end

    test "get_variables ignores missing keys", %{context: context} do
      context = Context.set_variable(context, "exists", "value")

      result = Context.get_variables(context, ["exists", "missing"])
      assert result == %{"exists" => "value"}
    end

    test "list_variables returns all variables", %{context: context} do
      context =
        context
        |> Context.set_variable("a", 1)
        |> Context.set_variable("b", 2)
        |> Context.set_variable("c", 3)

      vars = Context.list_variables(context)
      assert vars == %{"a" => 1, "b" => 2, "c" => 3}
    end
  end

  describe "logging" do
    setup do
      context = Context.new("exec_123", "workflow_456")
      {:ok, context: context}
    end

    test "logs with proper metadata", %{context: context} do
      # This test just ensures the function doesn't crash
      # In a real test, you might capture logs or use a mock logger
      assert :ok = Context.log(context, :info, "Test message")
      assert :ok = Context.log(context, :debug, "Debug message")
      assert :ok = Context.log(context, :warning, "Warning message")
      assert :ok = Context.log(context, :error, "Error message")
    end

    test "logs with additional metadata", %{context: context} do
      metadata = %{user_id: "user_123", action: "analyze"}
      assert :ok = Context.log(context, :info, "Custom metadata", metadata)
    end
  end

  describe "workspace and storage" do
    setup do
      {:ok, workspace_path} = Briefly.create(directory: true)

      context_with_workspace =
        Context.new("exec_123", "workflow_456", workspace_path: workspace_path)

      context_without_workspace = Context.new("exec_456", "workflow_789")

      {:ok,
       with_workspace: context_with_workspace,
       without_workspace: context_without_workspace,
       workspace_path: workspace_path}
    end

    test "get_workspace_path returns path when available", %{
      with_workspace: context,
      workspace_path: path
    } do
      assert {:ok, ^path} = Context.get_workspace_path(context)
    end

    test "get_workspace_path returns error when not available", %{without_workspace: context} do
      assert {:error, :no_workspace} = Context.get_workspace_path(context)
    end

    test "get_temp_storage returns path", %{with_workspace: context} do
      temp_path = Context.get_temp_storage(context)
      assert is_binary(temp_path)
      assert File.dir?(temp_path)
    end
  end

  describe "credentials" do
    setup do
      context =
        Context.new("exec_123", "workflow_456",
          credentials: %{
            "github_token" => "ghp_secret123",
            "api_key" => "key_456"
          }
        )

      {:ok, context: context}
    end

    test "get_credential returns value when exists", %{context: context} do
      assert Context.get_credential(context, "github_token") == "ghp_secret123"
      assert Context.get_credential(context, "api_key") == "key_456"
    end

    test "get_credential returns nil when not exists", %{context: context} do
      assert Context.get_credential(context, "missing_key") == nil
    end

    test "has_credential? checks existence", %{context: context} do
      assert Context.has_credential?(context, "github_token") == true
      assert Context.has_credential?(context, "missing_key") == false
    end
  end

  describe "execution tracking" do
    setup do
      context = Context.new("exec_123", "workflow_456")
      {:ok, context: context}
    end

    test "get_execution_duration returns milliseconds", %{context: context} do
      # Sleep a bit to ensure some time passes
      :timer.sleep(10)

      duration = Context.get_execution_duration(context)
      assert is_integer(duration)
      assert duration >= 10
    end

    test "record_node_start tracks node execution", %{context: context} do
      context = Context.record_node_start(context, "node_1")

      node_exec = Context.get_node_execution(context, "node_1")
      assert node_exec.node_id == "node_1"
      assert node_exec.status == :running
      assert is_nil(node_exec.completed_at)
      assert %DateTime{} = node_exec.started_at
    end

    test "record_node_completion updates existing node", %{context: context} do
      context =
        context
        |> Context.record_node_start("node_1")
        |> Context.record_node_completion("node_1", :ok)

      node_exec = Context.get_node_execution(context, "node_1")
      assert node_exec.status == :completed
      assert is_nil(node_exec.error)
      assert %DateTime{} = node_exec.completed_at
    end

    test "record_node_completion with error", %{context: context} do
      error = {:error, "Something went wrong"}

      context =
        context
        |> Context.record_node_start("node_1")
        |> Context.record_node_completion("node_1", error)

      node_exec = Context.get_node_execution(context, "node_1")
      assert node_exec.status == :failed
      assert node_exec.error == "Something went wrong"
    end

    test "record_node_completion without prior start", %{context: context} do
      # Should create a completed record even without start
      context = Context.record_node_completion(context, "node_1", :ok)

      node_exec = Context.get_node_execution(context, "node_1")
      assert node_exec.status == :completed
      assert %DateTime{} = node_exec.started_at
      assert %DateTime{} = node_exec.completed_at
    end
  end

  describe "tags and options" do
    setup do
      context =
        Context.new("exec_123", "workflow_456",
          tags: %{"env" => "prod", stage: "analysis"},
          options: %{"timeout" => 5000, "retries" => 3}
        )

      {:ok, context: context}
    end

    test "get_tag with string key", %{context: context} do
      assert Context.get_tag(context, "env") == "prod"
    end

    test "get_tag with atom key", %{context: context} do
      assert Context.get_tag(context, :stage) == "analysis"
    end

    test "get_tag returns nil for missing key", %{context: context} do
      assert Context.get_tag(context, "missing") == nil
      assert Context.get_tag(context, :missing) == nil
    end

    test "get_option returns value", %{context: context} do
      assert Context.get_option(context, "timeout") == 5000
      assert Context.get_option(context, "retries") == 3
    end

    test "get_option returns default when missing", %{context: context} do
      assert Context.get_option(context, "missing", "default") == "default"
      assert Context.get_option(context, "missing") == nil
    end
  end

  describe "metrics" do
    setup do
      context = Context.new("exec_123", "workflow_456")
      {:ok, context: context}
    end

    test "record_metric sends telemetry event", %{context: context} do
      # This test ensures the function doesn't crash
      # In a real test, you might attach a telemetry handler to verify
      assert :ok = Context.record_metric(context, "files_processed", 100)
      assert :ok = Context.record_metric(context, "duration_ms", 1250)
      assert :ok = Context.record_metric(context, "memory_mb", 45.5, %{node: "analyzer"})
    end
  end

  describe "create_node_context" do
    test "stores node id in process dictionary" do
      context = Context.new("exec_123", "workflow_456")

      # Ensure clean state
      Process.delete(:current_node_id)

      Context.create_node_context(context, "test_node")
      assert Process.get(:current_node_id) == "test_node"

      # Cleanup
      Process.delete(:current_node_id)
    end
  end

  describe "to_map" do
    test "converts context to map for serialization" do
      context =
        Context.new("exec_123", "workflow_456",
          workflow_name: "Test",
          tags: %{env: "test"}
        )

      map = Context.to_map(context)

      assert map.execution_id == "exec_123"
      assert map.workflow_id == "workflow_456"
      assert map.workflow_name == "Test"
      assert map.tags == %{env: "test"}
      assert Map.has_key?(map, :variables)
      assert Map.has_key?(map, :start_time)
    end
  end
end
