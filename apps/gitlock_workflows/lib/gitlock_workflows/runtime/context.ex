defmodule GitlockWorkflows.Runtime.Context do
  @moduledoc ~S"""
  Maintains execution state and provides services to nodes during workflow execution.

  The Context provides:
  - Execution tracking and identification
  - Variable storage and retrieval
  - Temporary storage management
  - Logging facilities
  - Metrics collection
  - Credential management
  - Workspace access

  ## Usage in Nodes

      defmodule MyNode do
        def execute(input, params, context) do
          # Access execution info
          execution_id = Context.get_execution_id(context)
          
          # Store intermediate results
          Context.set_variable(context, "step_1_result", intermediate_data)
          
          # Log progress
          Context.log(context, :info, "Processing #{length(input.files)} files")
          
          # Get workspace path
          workspace_path = Context.get_workspace_path(context)
          
          # Your node logic here
          {:ok, result}
        end
      end

  ## Variable Scope

  Variables stored in the context are available to all nodes in the workflow:
  - Use for sharing data between nodes
  - Store intermediate results
  - Cache expensive computations
  - Track progress across steps

  ## Logging

  All logs are tagged with execution ID and node ID for traceability:
  - Logs appear in execution logs
  - Can be filtered by execution
  - Include structured metadata
  """

  require Logger

  @typedoc "Execution context"
  @type t :: %__MODULE__{
          execution_id: String.t(),
          workflow_id: String.t(),
          workflow_name: String.t() | nil,
          variables: map(),
          credentials: map(),
          temp_storage: String.t(),
          workspace_path: String.t() | nil,
          start_time: DateTime.t(),
          node_executions: map(),
          tags: map(),
          options: map()
        }

  @typedoc "Log level"
  @type log_level :: :debug | :info | :warning | :error

  @typedoc "Metric value"
  @type metric_value :: number() | String.t()

  @enforce_keys [:execution_id, :workflow_id, :start_time]
  defstruct [
    :execution_id,
    :workflow_id,
    :workflow_name,
    variables: %{},
    credentials: %{},
    temp_storage: nil,
    workspace_path: nil,
    start_time: nil,
    node_executions: %{},
    tags: %{},
    options: %{}
  ]

  @doc """
  Creates a new execution context.

  ## Parameters
    * `execution_id` - Unique identifier for the execution
    * `workflow_id` - Identifier of the workflow being executed
    * `opts` - Additional options

  ## Options
    * `:workflow_name` - Human-readable name of the workflow
    * `:workspace_path` - Path to the workspace directory
    * `:temp_storage` - Path for temporary storage
    * `:credentials` - Map of credentials for external services
    * `:tags` - Additional tags for categorization
    * `:options` - Execution-specific options

  ## Returns
    A new Context struct

  ## Examples

      context = Context.new("exec_123", "workflow_456", 
        workflow_name: "Daily Analysis",
        workspace_path: "/tmp/workspace",
        tags: %{environment: "production"}
      )
  """
  @spec new(String.t(), String.t(), keyword()) :: t()
  def new(execution_id, workflow_id, opts \\ []) do
    temp_storage = Keyword.get(opts, :temp_storage, create_temp_storage(execution_id))

    %__MODULE__{
      execution_id: execution_id,
      workflow_id: workflow_id,
      workflow_name: Keyword.get(opts, :workflow_name),
      variables: %{},
      credentials: Keyword.get(opts, :credentials, %{}),
      temp_storage: temp_storage,
      workspace_path: Keyword.get(opts, :workspace_path),
      start_time: DateTime.utc_now(),
      node_executions: %{},
      tags: Keyword.get(opts, :tags, %{}),
      options: Keyword.get(opts, :options, %{})
    }
  end

  @doc ~S"""
  Gets the execution ID from the context.

  ## Parameters
    * `context` - The execution context

  ## Returns
    The execution ID as a string

  ## Examples

      execution_id = Context.get_execution_id(context)
      Logger.info("Starting execution #{execution_id}")
  """
  @spec get_execution_id(t()) :: String.t()
  def get_execution_id(%__MODULE__{execution_id: execution_id}), do: execution_id

  @doc """
  Gets the workflow ID from the context.

  ## Parameters
    * `context` - The execution context

  ## Returns
    The workflow ID as a string
  """
  @spec get_workflow_id(t()) :: String.t()
  def get_workflow_id(%__MODULE__{workflow_id: workflow_id}), do: workflow_id

  @doc ~S"""
  Gets a variable from the context.

  ## Parameters
    * `context` - The execution context
    * `key` - The variable key

  ## Returns
    The variable value, or `nil` if not found

  ## Examples

      result = Context.get_variable(context, "intermediate_result")
      
      case result do
        nil -> IO.puts("Variable not found")
        value -> IO.puts("Found result: #{inspect(value)}")
      end
  """
  @spec get_variable(t(), String.t()) :: any()
  def get_variable(%__MODULE__{variables: variables}, key) do
    Map.get(variables, key)
  end

  @doc """
  Sets a variable in the context.

  ## Parameters
    * `context` - The execution context
    * `key` - The variable key
    * `value` - The variable value

  ## Returns
    Updated context

  ## Examples

      # Store intermediate result
      context = Context.set_variable(context, "step_1_output", result)
      
      # Store configuration
      context = Context.set_variable(context, "batch_size", 100)
      
      # Store complex data
      context = Context.set_variable(context, "analysis_cache", %{
        hotspots: hotspots,
        complexity: complexity_map
      })
  """
  @spec set_variable(t(), String.t(), any()) :: t()
  def set_variable(%__MODULE__{} = context, key, value) do
    %{context | variables: Map.put(context.variables, key, value)}
  end

  @doc """
  Gets multiple variables from the context.

  ## Parameters
    * `context` - The execution context
    * `keys` - List of variable keys

  ## Returns
    Map of key-value pairs for found variables

  ## Examples

      vars = Context.get_variables(context, ["result1", "result2", "config"])
      # Returns: %{"result1" => value1, "config" => config_value}
      # (missing keys are omitted)
  """
  @spec get_variables(t(), [String.t()]) :: map()
  def get_variables(%__MODULE__{variables: variables}, keys) do
    Map.take(variables, keys)
  end

  @doc """
  Gets all variables from the context.

  ## Parameters
    * `context` - The execution context

  ## Returns
    Map of all variables

  ## Examples

      all_vars = Context.list_variables(context)
      IO.inspect(all_vars, label: "All context variables")
  """
  @spec list_variables(t()) :: map()
  def list_variables(%__MODULE__{variables: variables}), do: variables

  @doc ~S"""
  Logs a message with the execution context.

  All logs are automatically tagged with execution ID and current node ID
  for traceability.

  ## Parameters
    * `context` - The execution context
    * `level` - Log level (`:debug`, `:info`, `:warning`, `:error`)
    * `message` - The message to log
    * `metadata` - Optional additional metadata

  ## Examples

      Context.log(context, :info, "Processing started")
      Context.log(context, :debug, "Found #{count} files to analyze")
      Context.log(context, :warning, "Skipping invalid file: #{filename}")
      Context.log(context, :error, "Analysis failed", %{error: reason})
  """
  @spec log(t(), log_level(), String.t(), map()) :: :ok
  def log(%__MODULE__{} = context, level, message, metadata \\ %{}) do
    enhanced_metadata =
      Map.merge(metadata, %{
        execution_id: context.execution_id,
        workflow_id: context.workflow_id,
        workflow_name: context.workflow_name,
        node_id: get_current_node_id(),
        tags: context.tags
      })

    Logger.log(level, message, enhanced_metadata)
  end

  @doc """
  Records a metric for the execution.

  Metrics are collected for monitoring and analysis of workflow performance.

  ## Parameters
    * `context` - The execution context
    * `metric_name` - Name of the metric
    * `value` - Metric value
    * `metadata` - Optional metadata

  ## Examples

      Context.record_metric(context, "files_processed", 150)
      Context.record_metric(context, "processing_time_ms", 1250)
      Context.record_metric(context, "memory_usage_mb", 45.2)
      Context.record_metric(context, "api_calls", 5, %{service: "github"})
  """
  @spec record_metric(t(), String.t(), metric_value(), map()) :: :ok
  def record_metric(%__MODULE__{} = context, metric_name, value, metadata \\ %{}) do
    metric_metadata =
      Map.merge(metadata, %{
        execution_id: context.execution_id,
        workflow_id: context.workflow_id,
        node_id: get_current_node_id(),
        timestamp: DateTime.utc_now()
      })

    :telemetry.execute(
      [:gitlock, :runtime, :metric],
      %{value: value},
      Map.put(metric_metadata, :metric_name, metric_name)
    )
  end

  @doc ~S"""
  Gets the workspace path for file operations.

  ## Parameters
    * `context` - The execution context

  ## Returns
    * `{:ok, path}` - Workspace path available
    * `{:error, :no_workspace}` - No workspace configured

  ## Examples

      case Context.get_workspace_path(context) do
        {:ok, path} -> 
          files = File.ls!(path)
          IO.puts("Found #{length(files)} files in workspace")
          
        {:error, :no_workspace} ->
          IO.puts("No workspace available")
      end
  """
  @spec get_workspace_path(t()) :: {:ok, String.t()} | {:error, :no_workspace}
  def get_workspace_path(%__MODULE__{workspace_path: nil}), do: {:error, :no_workspace}
  def get_workspace_path(%__MODULE__{workspace_path: path}), do: {:ok, path}

  @doc """
  Gets the temporary storage path.

  This is useful for storing intermediate files during execution.

  ## Parameters
    * `context` - The execution context

  ## Returns
    Path to temporary storage directory

  ## Examples

      temp_path = Context.get_temp_storage(context)
      temp_file = Path.join(temp_path, "intermediate_results.json")
      File.write!(temp_file, Jason.encode!(data))
  """
  @spec get_temp_storage(t()) :: String.t()
  def get_temp_storage(%__MODULE__{temp_storage: temp_storage}), do: temp_storage

  @doc """
  Gets a credential value.

  ## Parameters
    * `context` - The execution context
    * `key` - The credential key

  ## Returns
    The credential value, or `nil` if not found

  ## Examples

      case Context.get_credential(context, "github_token") do
        nil -> {:error, "GitHub token not configured"}
        token -> {:ok, token}
      end
  """
  @spec get_credential(t(), String.t()) :: String.t() | nil
  def get_credential(%__MODULE__{credentials: credentials}, key) do
    Map.get(credentials, key)
  end

  @doc """
  Checks if a credential exists.

  ## Parameters
    * `context` - The execution context
    * `key` - The credential key

  ## Returns
    `true` if credential exists, `false` otherwise
  """
  @spec has_credential?(t(), String.t()) :: boolean()
  def has_credential?(%__MODULE__{credentials: credentials}, key) do
    Map.has_key?(credentials, key)
  end

  @doc ~S"""
  Gets execution duration up to now.

  ## Parameters
    * `context` - The execution context

  ## Returns
    Duration in milliseconds

  ## Examples

      duration = Context.get_execution_duration(context)
      Context.log(context, :info, "Execution running for #{duration}ms")
  """
  @spec get_execution_duration(t()) :: non_neg_integer()
  def get_execution_duration(%__MODULE__{start_time: start_time}) do
    DateTime.diff(DateTime.utc_now(), start_time, :millisecond)
  end

  @doc """
  Gets a tag value.

  ## Parameters
    * `context` - The execution context
    * `key` - The tag key (string or atom)

  ## Returns
    The tag value, or `nil` if not found

  ## Examples

      environment = Context.get_tag(context, "environment")
      
      case environment do
        "production" -> use_production_settings()
        "development" -> use_dev_settings()
        _ -> use_default_settings()
      end
  """
  @spec get_tag(t(), String.t() | atom()) :: any()
  def get_tag(%__MODULE__{tags: tags}, key) when is_binary(key) do
    Map.get(tags, key) || Map.get(tags, String.to_existing_atom(key))
  rescue
    ArgumentError -> nil
  end

  def get_tag(%__MODULE__{tags: tags}, key) when is_atom(key) do
    Map.get(tags, key) || Map.get(tags, Atom.to_string(key))
  end

  @doc """
  Gets an execution option.

  ## Parameters
    * `context` - The execution context
    * `key` - The option key
    * `default` - Default value if not found

  ## Returns
    The option value, or the default

  ## Examples

      batch_size = Context.get_option(context, "batch_size", 100)
      timeout = Context.get_option(context, "timeout", 30_000)
  """
  @spec get_option(t(), String.t(), any()) :: any()
  def get_option(%__MODULE__{options: options}, key, default \\ nil) do
    Map.get(options, key, default)
  end

  @doc """
  Records that a node has started execution.

  ## Parameters
    * `context` - The execution context
    * `node_id` - The node identifier

  ## Returns
    Updated context

  ## Examples

      context = Context.record_node_start(context, "hotspot_analysis")
  """
  @spec record_node_start(t(), String.t()) :: t()
  def record_node_start(%__MODULE__{} = context, node_id) do
    node_execution = %{
      node_id: node_id,
      started_at: DateTime.utc_now(),
      completed_at: nil,
      status: :running,
      error: nil
    }

    %{context | node_executions: Map.put(context.node_executions, node_id, node_execution)}
  end

  @doc """
  Records that a node has completed execution.

  ## Parameters
    * `context` - The execution context
    * `node_id` - The node identifier
    * `result` - The execution result (`:ok` or `{:error, reason}`)

  ## Returns
    Updated context
  """
  @spec record_node_completion(t(), String.t(), :ok | {:error, term()}) :: t()
  def record_node_completion(%__MODULE__{} = context, node_id, result) do
    case get_in(context.node_executions, [node_id]) do
      nil ->
        # Node wasn't recorded as started, create a completed record
        node_execution = %{
          node_id: node_id,
          started_at: DateTime.utc_now(),
          completed_at: DateTime.utc_now(),
          status: if(result == :ok, do: :completed, else: :failed),
          error: if(result == :ok, do: nil, else: elem(result, 1))
        }

        %{context | node_executions: Map.put(context.node_executions, node_id, node_execution)}

      node_execution ->
        # Update existing record
        updated_execution = %{
          node_execution
          | completed_at: DateTime.utc_now(),
            status: if(result == :ok, do: :completed, else: :failed),
            error: if(result == :ok, do: nil, else: elem(result, 1))
        }

        %{context | node_executions: Map.put(context.node_executions, node_id, updated_execution)}
    end
  end

  @doc """
  Gets the execution status of a node.

  ## Parameters
    * `context` - The execution context
    * `node_id` - The node identifier

  ## Returns
    Node execution info, or `nil` if not found
  """
  @spec get_node_execution(t(), String.t()) :: map() | nil
  def get_node_execution(%__MODULE__{node_executions: node_executions}, node_id) do
    Map.get(node_executions, node_id)
  end

  @doc """
  Creates a child context for a specific node.

  This is useful when you need to isolate variables or state for a specific node.

  ## Parameters
    * `context` - The parent execution context
    * `node_id` - The node identifier

  ## Returns
    A new context with the node ID set

  ## Examples

      node_context = Context.create_node_context(context, "hotspot_analysis")
      # Node-specific operations...
  """
  @spec create_node_context(t(), String.t()) :: t()
  def create_node_context(%__MODULE__{} = context, node_id) do
    # For now, we just store the node ID in the process dictionary
    # In a more sophisticated implementation, you might create a separate context
    Process.put(:current_node_id, node_id)
    context
  end

  @doc """
  Converts context to a map for serialization.

  ## Parameters
    * `context` - The execution context

  ## Returns
    Map representation of the context

  ## Examples

      context_map = Context.to_map(context)
      json = Jason.encode!(context_map)
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = context) do
    %{
      execution_id: context.execution_id,
      workflow_id: context.workflow_id,
      workflow_name: context.workflow_name,
      variables: context.variables,
      temp_storage: context.temp_storage,
      workspace_path: context.workspace_path,
      start_time: context.start_time,
      node_executions: context.node_executions,
      tags: context.tags,
      options: context.options
    }
  end

  # Private Functions

  defp create_temp_storage(execution_id) do
    base_path = Path.join([System.tmp_dir!(), "gitlock", "runtime", "executions", execution_id])
    File.mkdir_p!(base_path)
    base_path
  end

  defp get_current_node_id do
    Process.get(:current_node_id)
  end
end
