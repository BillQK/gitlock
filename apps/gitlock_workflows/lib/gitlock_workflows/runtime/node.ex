defmodule GitlockWorkflows.Runtime.Node do
  @moduledoc """
  Defines the contract all nodes must implement.

  This module serves as a behaviour definition for nodes. All workflow nodes 
  must implement this behaviour to be usable in the runtime.

  Node registration and discovery is now handled by GitlockWorkflows.Runtime.Registry.

  ## Node Types

  Nodes are categorized into:
  - **Triggers**: Start workflow execution (no input ports)
  - **Analysis**: Wrap existing Gitlock use cases
  - **Transform**: Manipulate data between analysis steps
  - **Output**: Send results to external systems (no output ports)

  ## Port Types

  The runtime supports these port types:
  - `:string` - Text data
  - `:number` - Numeric values (integer or float)
  - `:boolean` - True/false values
  - `{:list, type}` - List of values of the specified type
  - `{:map, type}` - Map with values of the specified type
  - `:any` - Any data type

  ## Example

      defmodule MyNode do
        use GitlockWorkflows.Runtime.Node
        
        @impl true
        def metadata do
          %{
            id: "custom.mynode",
            displayName: "My Custom Node",
            group: "custom",
            version: 1,
            description: "Does something special",
            inputs: [
              %{name: "main", type: :any, required: true}
            ],
            outputs: [
              %{name: "main", type: :any}
            ],
            parameters: [
              %{
                name: "option",
                displayName: "Option",
                type: "string",
                default: "value"
              }
            ]
          }
        end
        
        @impl true
        def execute(input_data, parameters, context) do
          # Implementation
          {:ok, %{"main" => result}}
        end
        
        @impl true
        def validate_parameters(parameters) do
          # Validation logic
          :ok
        end
      end

  ## Registration

  To register your node, use the Registry module:

      GitlockWorkflows.Runtime.Registry.register_node(MyNode)
  """

  @type port_type ::
          :string
          | :number
          | :boolean
          | {:list, port_type()}
          | {:map, port_type()}
          | :any

  @type port_definition :: %{
          name: String.t(),
          type: port_type(),
          required: boolean(),
          description: String.t() | nil
        }

  @type parameter_type ::
          String.t()

  @type parameter_definition :: %{
          name: String.t(),
          displayName: String.t(),
          type: parameter_type(),
          default: any(),
          required: boolean(),
          description: String.t() | nil,
          options: [any()] | nil
        }

  @type node_metadata :: %{
          id: String.t(),
          displayName: String.t(),
          group: String.t(),
          version: integer(),
          description: String.t(),
          inputs: [port_definition()],
          outputs: [port_definition()],
          parameters: [parameter_definition()]
        }

  @type validation_error :: {atom(), String.t()}

  # Behaviour callbacks
  @callback metadata() :: node_metadata()
  @callback execute(
              input_data :: map(),
              parameters :: map(),
              context :: GitlockWorkflows.Runtime.Context.t()
            ) ::
              {:ok, output_data :: map()} | {:error, term()}
  @callback validate_parameters(parameters :: map()) :: :ok | {:error, [validation_error()]}

  # Optional callbacks
  @callback reactor_options() :: keyword()

  @optional_callbacks [reactor_options: 0]

  @doc """
  When used, provides common functionality for nodes and bridges to Reactor.Step.
  """
  defmacro __using__(_opts) do
    quote do
      @behaviour GitlockWorkflows.Runtime.Node
      @behaviour Reactor.Step

      @impl Reactor.Step
      def run(arguments, context, options) do
        # The parameters are stored in the current_step's context
        step_params =
          case Map.get(context, :current_step) do
            %{context: %{parameters: params}} when is_map(params) ->
              params

            _ ->
              %{}
          end

        # Convert arguments map to input data
        input_data = Map.new(arguments)

        # Call the node's execute function with proper parameters
        case execute(input_data, step_params, context) do
          {:ok, output} ->
            {:ok, output}

          {:error, reason} ->
            {:error, reason}
        end
      end

      @impl Reactor.Step
      def compensate(_reason, _arguments, _context, _options) do
        # Default compensation - nodes can override this
        :ok
      end

      @impl Reactor.Step
      def async?(_options), do: true

      @impl Reactor.Step
      def can?(_step, _capability), do: false

      # Provide default reactor_options if not implemented
      def reactor_options, do: []

      # Make compensate and reactor_options overridable
      defoverridable compensate: 4, reactor_options: 0, async?: 1, can?: 2
    end
  end

  # Convenience functions that delegate to Registry
  # These are kept for backward compatibility

  @doc """
  Gets a node module by its type ID.

  Delegates to GitlockWorkflows.Runtime.Registry.get_node/1
  """
  @spec get_module(String.t()) :: {:ok, module()} | {:error, :not_found}
  def get_module(node_type) do
    GitlockWorkflows.Runtime.Registry.get_node(node_type)
  end

  @doc """
  Gets metadata for a node by its ID.

  Delegates to GitlockWorkflows.Runtime.Registry.get_metadata/1
  """
  @spec get_metadata(String.t()) :: {:ok, node_metadata()} | {:error, :not_found}
  def get_metadata(node_id) do
    GitlockWorkflows.Runtime.Registry.get_metadata(node_id)
  end
end
