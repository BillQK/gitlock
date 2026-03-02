defmodule GitlockWorkflows.Runtime.Registry do
  @moduledoc """
  Central registry for available nodes and their metadata.

  The Registry provides:
  - Node discovery and registration
  - Metadata caching and retrieval
  - Node validation
  - Category-based organization
  - Search functionality
  - Plugin support

  ## Node Registration

  Nodes are automatically registered at application startup:

      # In your application.ex
      def start(_type, _args) do
        # Register all built-in nodes
        GitlockWorkflows.Runtime.Registry.register_builtin_nodes()
        
        # Register plugin nodes
        GitlockWorkflows.Runtime.Registry.register_plugin_nodes()
        
        # ... rest of supervision tree
      end

  ## Custom Node Registration

      defmodule MyCustomNode do
        use GitlockWorkflows.Runtime.Node
        
        def metadata do
          %{
            id: "my_company.analysis.custom",
            displayName: "Custom Analysis",
            group: "analysis",
            version: 1,
            description: "My custom analysis node",
            inputs: [
              %{name: "data", type: :list, required: true}
            ],
            outputs: [
              %{name: "result", type: :map}
            ],
            parameters: [
              %{name: "threshold", type: "number", default: 10}
            ]
          }
        end
        
        def execute(input, params, context) do
          # Your implementation
          {:ok, %{result: "processed"}}
        end
      end
      
      # Register it
      GitlockWorkflows.Runtime.Registry.register_node(MyCustomNode)

  ## Node Discovery

      # List all nodes
      nodes = GitlockWorkflows.Runtime.Registry.list_nodes()
      
      # Get specific node
      {:ok, module} = GitlockWorkflows.Runtime.Registry.get_node("gitlock.analysis.hotspot")
      
      # Search nodes
      analysis_nodes = GitlockWorkflows.Runtime.Registry.search_nodes("analysis")
      
      # List by category
      triggers = GitlockWorkflows.Runtime.Registry.list_nodes_by_category("trigger")
  """
  use GenServer
  require Logger

  @typedoc "Node metadata structure"
  @type node_metadata :: %{
          id: String.t(),
          displayName: String.t(),
          group: String.t(),
          version: integer(),
          description: String.t(),
          inputs: [port_definition()],
          outputs: [port_definition()],
          parameters: [parameter_definition()],
          tags: [String.t()],
          deprecated: boolean(),
          experimental: boolean()
        }

  @typedoc "Port definition"
  @type port_definition :: %{
          name: String.t(),
          type: atom(),
          required: boolean(),
          description: String.t()
        }

  @typedoc "Parameter definition"
  @type parameter_definition :: %{
          name: String.t(),
          type: String.t(),
          default: any(),
          required: boolean(),
          description: String.t(),
          options: [any()] | nil
        }

  @typedoc "Registry state"
  @type state :: %{
          nodes: %{String.t() => {module(), node_metadata()}},
          by_category: %{String.t() => [String.t()]},
          search_index: %{String.t() => [String.t()]},
          stats: %{
            total_nodes: non_neg_integer(),
            nodes_by_group: %{String.t() => non_neg_integer()},
            last_updated: DateTime.t()
          }
        }

  # Client API

  @doc """
  Starts the node registry.

  Usually called by the supervisor.
  """
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Registers a node in the registry.

  ## Parameters
    * `module` - The node module implementing the Node behaviour

  ## Returns
    * `:ok` - Node registered successfully
    * `{:error, reason}` - Registration failed

  ## Examples

      defmodule MyNode do
        use GitlockWorkflows.Runtime.Node
        # ... implementation
      end
      
      :ok = Registry.register_node(MyNode)
  """
  @spec register_node(module()) :: :ok | {:error, term()}
  def register_node(module) when is_atom(module) do
    GenServer.call(__MODULE__, {:register_node, module})
  end

  @doc """
  Registers multiple nodes at once.

  ## Parameters
    * `modules` - List of node modules

  ## Returns
    * `:ok` - All nodes registered successfully
    * `{:error, failures}` - Some nodes failed to register

  ## Examples

      modules = [NodeA, NodeB, NodeC]
      :ok = Registry.register_nodes(modules)
  """
  @spec register_nodes([module()]) :: :ok | {:error, map()}
  def register_nodes(modules) when is_list(modules) do
    GenServer.call(__MODULE__, {:register_nodes, modules})
  end

  @doc """
  Gets a node module by its ID.

  ## Parameters
    * `node_id` - The node identifier

  ## Returns
    * `{:ok, module}` - Node found
    * `{:error, :not_found}` - Node not found

  ## Examples

      case Registry.get_node("gitlock.analysis.hotspot") do
        {:ok, module} -> 
          # Use the module
          metadata = module.metadata()
          
        {:error, :not_found} ->
          IO.puts("Node not found")
      end
  """
  @spec get_node(String.t()) :: {:ok, module()} | {:error, :not_found}
  def get_node(node_id) when is_binary(node_id) do
    GenServer.call(__MODULE__, {:get_node, node_id})
  end

  @doc ~S"""
  Gets node metadata by ID.

  ## Parameters
    * `node_id` - The node identifier

  ## Returns
    * `{:ok, metadata}` - Metadata found
    * `{:error, :not_found}` - Node not found

  ## Examples

      {:ok, metadata} = Registry.get_metadata("gitlock.analysis.hotspot")
      IO.puts("Node: #{metadata.displayName}")
      IO.puts("Description: #{metadata.description}")
  """
  @spec get_metadata(String.t()) :: {:ok, node_metadata()} | {:error, :not_found}
  def get_metadata(node_id) when is_binary(node_id) do
    GenServer.call(__MODULE__, {:get_metadata, node_id})
  end

  @doc ~S"""
  Lists all registered nodes.

  ## Returns
    List of node metadata

  ## Examples

      nodes = Registry.list_nodes()
      
      Enum.each(nodes, fn metadata ->
        IO.puts("#{metadata.id}: #{metadata.displayName}")
      end)
  """
  @spec list_nodes() :: [node_metadata()]
  def list_nodes do
    GenServer.call(__MODULE__, :list_nodes)
  end

  @doc """
  Lists nodes by category/group.

  ## Parameters
    * `category` - The category to filter by

  ## Returns
    List of node metadata in the specified category

  ## Examples

      # Get all analysis nodes
      analysis_nodes = Registry.list_nodes_by_category("analysis")
      
      # Get all triggers
      triggers = Registry.list_nodes_by_category("trigger")
  """
  @spec list_nodes_by_category(String.t()) :: [node_metadata()]
  def list_nodes_by_category(category) when is_binary(category) do
    GenServer.call(__MODULE__, {:list_nodes_by_category, category})
  end

  @doc """
  Lists all available categories.

  ## Returns
    List of category names

  ## Examples

      categories = Registry.list_categories()
      # Returns: ["trigger", "analysis", "transform", "output"]
  """
  @spec list_categories() :: [String.t()]
  def list_categories do
    GenServer.call(__MODULE__, :list_categories)
  end

  @doc """
  Searches for nodes by query.

  Searches in node ID, display name, description, and tags.

  ## Parameters
    * `query` - The search query

  ## Returns
    List of matching node metadata

  ## Examples

      # Search for hotspot-related nodes
      hotspot_nodes = Registry.search_nodes("hotspot")
      
      # Search for Git-related nodes
      git_nodes = Registry.search_nodes("git")
      
      # Search for analysis nodes
      analysis_nodes = Registry.search_nodes("analysis")
  """
  @spec search_nodes(String.t()) :: [node_metadata()]
  def search_nodes(query) when is_binary(query) do
    GenServer.call(__MODULE__, {:search_nodes, query})
  end

  @doc ~S"""
  Validates that a node is properly implemented.

  ## Parameters
    * `module` - The node module to validate

  ## Returns
    * `:ok` - Node is valid
    * `{:error, reasons}` - Node is invalid

  ## Examples

      case Registry.validate_node(MyNode) do
        :ok -> IO.puts("Node is valid")
        {:error, reasons} -> IO.puts("Validation errors: #{inspect(reasons)}")
      end
  """
  @spec validate_node(module()) :: :ok | {:error, [term()]}
  def validate_node(module) when is_atom(module) do
    GenServer.call(__MODULE__, {:validate_node, module})
  end

  @doc ~S"""
  Gets registry statistics.

  ## Returns
    Map containing registry statistics

  ## Examples

      stats = Registry.get_stats()
      IO.puts("Total nodes: #{stats.total_nodes}")
      IO.puts("Analysis nodes: #{stats.nodes_by_group["analysis"]}")
  """
  @spec get_stats() :: map()
  def get_stats do
    GenServer.call(__MODULE__, :get_stats)
  end

  @doc """
  Registers all built-in nodes.

  This is called automatically at application startup.

  ## Returns
    * `:ok` - All nodes registered successfully
    * `{:error, failures}` - Some nodes failed to register
  """
  @spec register_builtin_nodes() :: :ok | {:error, map()}
  def register_builtin_nodes do
    # Derive builtin nodes from the NodeCatalog (single source of truth)
    catalog_modules = GitlockWorkflows.NodeCatalog.runtime_modules()

    # Also include runtime-only nodes not in the visual catalog
    # (transform nodes, output nodes used only in the runtime)
    extra_modules = [
      GitlockWorkflows.Runtime.Nodes.Analysis.Complexity,
      GitlockWorkflows.Runtime.Nodes.Transform.ExtractField,
      GitlockWorkflows.Runtime.Nodes.Output.CsvExport
    ]

    all_modules = Enum.uniq(catalog_modules ++ extra_modules)
    available = Enum.filter(all_modules, &Code.ensure_loaded?/1)
    register_nodes(available)
  end

  @doc """
  Registers plugin nodes from configured applications.

  This scans configured applications for node modules and registers them.

  ## Returns
    * `:ok` - All plugin nodes registered successfully
    * `{:error, failures}` - Some nodes failed to register
  """
  @spec register_plugin_nodes() :: :ok | {:error, map()}
  def register_plugin_nodes do
    plugin_apps = Application.get_env(:gitlock_core, :plugin_apps, [])

    plugin_nodes =
      plugin_apps
      |> Enum.flat_map(&discover_nodes_in_app/1)

    case plugin_nodes do
      [] -> :ok
      nodes -> register_nodes(nodes)
    end
  end

  @doc """
  Unregisters a node from the registry.

  ## Parameters
    * `node_id` - The node identifier

  ## Returns
    * `:ok` - Node unregistered successfully
    * `{:error, :not_found}` - Node not found

  ## Examples

      :ok = Registry.unregister_node("my_custom_node")
  """
  @spec unregister_node(String.t()) :: :ok | {:error, :not_found}
  def unregister_node(node_id) when is_binary(node_id) do
    GenServer.call(__MODULE__, {:unregister_node, node_id})
  end

  # Server Implementation

  @impl GenServer
  def init(_opts) do
    Logger.info("Starting Runtime.Registry")

    state = %{
      nodes: %{},
      by_category: %{},
      search_index: %{},
      stats: %{
        total_nodes: 0,
        nodes_by_group: %{},
        last_updated: DateTime.utc_now()
      }
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call({:register_node, module}, _from, state) do
    case do_register_node(module, state) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_call({:register_nodes, modules}, _from, state) do
    {failures, final_state} =
      Enum.reduce(modules, {%{}, state}, fn module, {failures, acc_state} ->
        case do_register_node(module, acc_state) do
          {:ok, new_state} ->
            {failures, new_state}

          {:error, reason} ->
            {Map.put(failures, module, reason), acc_state}
        end
      end)

    if map_size(failures) == 0 do
      {:reply, :ok, final_state}
    else
      {:reply, {:error, failures}, final_state}
    end
  end

  @impl GenServer
  def handle_call({:get_node, node_id}, _from, state) do
    case Map.get(state.nodes, node_id) do
      {module, _metadata} -> {:reply, {:ok, module}, state}
      nil -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl GenServer
  def handle_call({:get_metadata, node_id}, _from, state) do
    case Map.get(state.nodes, node_id) do
      {_module, metadata} -> {:reply, {:ok, metadata}, state}
      nil -> {:reply, {:error, :not_found}, state}
    end
  end

  @impl GenServer
  def handle_call(:list_nodes, _from, state) do
    nodes =
      state.nodes
      |> Map.values()
      |> Enum.map(fn {_module, metadata} -> metadata end)
      |> Enum.sort_by(& &1.displayName)

    {:reply, nodes, state}
  end

  @impl GenServer
  def handle_call({:list_nodes_by_category, category}, _from, state) do
    node_ids = Map.get(state.by_category, category, [])

    nodes =
      node_ids
      |> Enum.map(&Map.get(state.nodes, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.map(fn {_module, metadata} -> metadata end)
      |> Enum.sort_by(& &1.displayName)

    {:reply, nodes, state}
  end

  @impl GenServer
  def handle_call(:list_categories, _from, state) do
    categories =
      state.by_category
      |> Map.keys()
      |> Enum.sort()

    {:reply, categories, state}
  end

  @impl GenServer
  def handle_call({:search_nodes, query}, _from, state) do
    query_lower = String.downcase(query)

    matching_nodes =
      state.nodes
      |> Map.values()
      |> Enum.filter(fn {_module, metadata} ->
        search_matches?(metadata, query_lower)
      end)
      |> Enum.map(fn {_module, metadata} -> metadata end)
      |> Enum.sort_by(& &1.displayName)

    {:reply, matching_nodes, state}
  end

  @impl GenServer
  def handle_call({:validate_node, module}, _from, state) do
    case do_validate_node(module) do
      :ok -> {:reply, :ok, state}
      {:error, reasons} -> {:reply, {:error, reasons}, state}
    end
  end

  @impl GenServer
  def handle_call(:get_stats, _from, state) do
    {:reply, state.stats, state}
  end

  @impl GenServer
  def handle_call({:unregister_node, node_id}, _from, state) do
    case Map.get(state.nodes, node_id) do
      nil ->
        {:reply, {:error, :not_found}, state}

      {_module, metadata} ->
        new_state = remove_node_from_state(node_id, metadata, state)
        {:reply, :ok, new_state}
    end
  end

  # Private Functions

  defp do_register_node(module, state) do
    with :ok <- do_validate_node(module),
         {:ok, metadata} <- get_module_metadata(module) do
      Logger.info("Registering node: #{metadata.id} (#{metadata.displayName})")

      new_state = add_node_to_state(module, metadata, state)
      {:ok, new_state}
    else
      error -> error
    end
  end

  defp do_validate_node(module) do
    errors = []

    # Check if module exists
    errors =
      if Code.ensure_loaded?(module) do
        errors
      else
        [{:module_not_loaded, module} | errors]
      end

    # Check if module implements required functions
    required_functions = [:metadata, :execute]

    errors =
      Enum.reduce(required_functions, errors, fn function, acc ->
        if function_exported?(module, function, 0) or function_exported?(module, function, 3) do
          acc
        else
          [{:missing_function, function} | acc]
        end
      end)

    # Check metadata structure
    errors =
      case get_module_metadata(module) do
        {:ok, metadata} -> validate_metadata(metadata, errors)
        {:error, reason} -> [{:invalid_metadata, reason} | errors]
      end

    if Enum.empty?(errors) do
      :ok
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp get_module_metadata(module) do
    try do
      metadata = module.metadata()
      {:ok, normalize_metadata(metadata)}
    rescue
      error -> {:error, error}
    end
  end

  defp normalize_metadata(metadata) do
    %{
      id: Map.get(metadata, :id),
      displayName: Map.get(metadata, :displayName) || Map.get(metadata, :id),
      group: Map.get(metadata, :group, "other"),
      version: Map.get(metadata, :version, 1),
      description: Map.get(metadata, :description, ""),
      inputs: Map.get(metadata, :inputs, []),
      outputs: Map.get(metadata, :outputs, []),
      parameters: Map.get(metadata, :parameters, []),
      tags: Map.get(metadata, :tags, []),
      deprecated: Map.get(metadata, :deprecated, false),
      experimental: Map.get(metadata, :experimental, false)
    }
  end

  defp validate_metadata(metadata, errors) do
    errors =
      if is_binary(Map.get(metadata, :id)) and String.length(Map.get(metadata, :id)) > 0 do
        errors
      else
        [{:invalid_id, Map.get(metadata, :id)} | errors]
      end

    errors =
      if is_binary(Map.get(metadata, :displayName)) and
           String.length(Map.get(metadata, :displayName)) > 0 do
        errors
      else
        [{:invalid_display_name, Map.get(metadata, :displayName)} | errors]
      end

    errors =
      if is_list(Map.get(metadata, :inputs)) do
        errors
      else
        [{:invalid_inputs, Map.get(metadata, :inputs)} | errors]
      end

    errors =
      if is_list(Map.get(metadata, :outputs)) do
        errors
      else
        [{:invalid_outputs, Map.get(metadata, :outputs)} | errors]
      end

    errors
  end

  defp add_node_to_state(module, metadata, state) do
    # Add to main nodes map
    nodes = Map.put(state.nodes, metadata.id, {module, metadata})

    # Add to category index
    category_nodes = Map.get(state.by_category, metadata.group, [])
    by_category = Map.put(state.by_category, metadata.group, [metadata.id | category_nodes])

    # Update search index
    search_index = add_to_search_index(metadata, state.search_index)

    # Update stats
    stats = update_stats_for_addition(metadata, state.stats)

    %{
      state
      | nodes: nodes,
        by_category: by_category,
        search_index: search_index,
        stats: stats
    }
  end

  defp remove_node_from_state(node_id, metadata, state) do
    # Remove from main nodes map
    nodes = Map.delete(state.nodes, node_id)

    # Remove from category index
    category_nodes = Map.get(state.by_category, metadata.group, [])
    updated_category_nodes = List.delete(category_nodes, node_id)

    by_category =
      if Enum.empty?(updated_category_nodes) do
        Map.delete(state.by_category, metadata.group)
      else
        Map.put(state.by_category, metadata.group, updated_category_nodes)
      end

    # Update search index
    search_index = remove_from_search_index(metadata, state.search_index)

    # Update stats
    stats = update_stats_for_removal(metadata, state.stats)

    %{
      state
      | nodes: nodes,
        by_category: by_category,
        search_index: search_index,
        stats: stats
    }
  end

  defp add_to_search_index(metadata, search_index) do
    search_terms = extract_search_terms(metadata)

    Enum.reduce(search_terms, search_index, fn term, acc ->
      existing = Map.get(acc, term, [])
      Map.put(acc, term, [metadata.id | existing])
    end)
  end

  defp remove_from_search_index(metadata, search_index) do
    search_terms = extract_search_terms(metadata)

    Enum.reduce(search_terms, search_index, fn term, acc ->
      case Map.get(acc, term) do
        nil -> acc
        # Remove term if this was the only node
        [_] -> Map.delete(acc, term)
        list -> Map.put(acc, term, List.delete(list, metadata.id))
      end
    end)
  end

  defp extract_search_terms(metadata) do
    [
      metadata.id,
      metadata.displayName,
      metadata.group,
      metadata.description
    ]
    |> Enum.concat(metadata.tags)
    |> Enum.flat_map(fn term ->
      term
      |> String.downcase()
      |> String.split([" ", ".", "_", "-"], trim: true)
    end)
    |> Enum.uniq()
  end

  defp search_matches?(metadata, query) do
    search_text =
      [
        metadata.id,
        metadata.displayName,
        metadata.group,
        metadata.description
      ]
      |> Enum.concat(metadata.tags)
      |> Enum.join(" ")
      |> String.downcase()

    String.contains?(search_text, query)
  end

  defp update_stats_for_addition(metadata, stats) do
    group_count = Map.get(stats.nodes_by_group, metadata.group, 0)

    %{
      stats
      | total_nodes: stats.total_nodes + 1,
        nodes_by_group: Map.put(stats.nodes_by_group, metadata.group, group_count + 1),
        last_updated: DateTime.utc_now()
    }
  end

  defp update_stats_for_removal(metadata, stats) do
    group_count = Map.get(stats.nodes_by_group, metadata.group, 1)

    nodes_by_group =
      if group_count <= 1 do
        Map.delete(stats.nodes_by_group, metadata.group)
      else
        Map.put(stats.nodes_by_group, metadata.group, group_count - 1)
      end

    %{
      stats
      | total_nodes: stats.total_nodes - 1,
        nodes_by_group: nodes_by_group,
        last_updated: DateTime.utc_now()
    }
  end

  defp discover_nodes_in_app(app_name) do
    case Application.spec(app_name, :modules) do
      nil ->
        []

      modules ->
        modules
        |> Enum.filter(&implements_node_behaviour?/1)
    end
  end

  defp implements_node_behaviour?(module) do
    try do
      Code.ensure_loaded?(module) and
        function_exported?(module, :metadata, 0) and
        function_exported?(module, :execute, 3)
    rescue
      _ -> false
    end
  end
end
