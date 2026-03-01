defmodule GitlockWorkflows.Node do
  @moduledoc """
  A processing step in a workflow pipeline.

  Nodes are created from catalog type definitions and carry their own
  typed input/output ports. Position is stored for visual layout on
  the SvelteFlow canvas.
  """

  alias GitlockWorkflows.{Port, NodeCatalog}

  @type t :: %__MODULE__{
          id: String.t(),
          type: atom(),
          label: String.t(),
          config: map(),
          position: {number(), number()},
          input_ports: [Port.t()],
          output_ports: [Port.t()]
        }

  @enforce_keys [:id, :type, :label, :input_ports, :output_ports]
  defstruct [:id, :type, :label, config: %{}, position: {0, 0}, input_ports: [], output_ports: []]

  @doc """
  Creates a new node from a catalog type definition.

  ## Options
    * `:config` - Node-specific configuration (default: `%{}`)
    * `:position` - Canvas position as `{x, y}` tuple (default: `{0, 0}`)

  ## Returns
    A `%Node{}` struct on success, or `{:error, :unknown_node_type}`.

  ## Examples

      iex> Node.new(:git_log, config: %{depth: 500}, position: {100, 200})
      %Node{type: :git_log, label: "Git Log", ...}

      iex> Node.new(:nonexistent)
      {:error, :unknown_node_type}
  """
  @spec new(atom(), keyword()) :: t() | {:error, :unknown_node_type}
  def new(type_id, opts \\ []) do
    case NodeCatalog.get_type(type_id) do
      {:ok, type_def} -> build_from_type_def(type_def, opts)
      {:error, _} = err -> err
    end
  end

  defp build_from_type_def(type_def, opts) do
    %__MODULE__{
      id: gen_id(),
      type: type_def.type_id,
      label: type_def.label,
      config: Keyword.get(opts, :config, %{}),
      position: Keyword.get(opts, :position, {0, 0}),
      input_ports: Enum.map(type_def.input_ports, &Port.new(&1.name, &1.data_type)),
      output_ports: Enum.map(type_def.output_ports, &Port.new(&1.name, &1.data_type))
    }
  end

  @doc "Finds a port by id across all input and output ports."
  @spec find_port(t(), String.t()) :: {:ok, Port.t()} | :error
  def find_port(%__MODULE__{} = node, port_id) do
    (node.input_ports ++ node.output_ports)
    |> Enum.find(&(&1.id == port_id))
    |> case do
      nil -> :error
      port -> {:ok, port}
    end
  end

  @doc "Finds an output port by id."
  @spec find_output_port(t(), String.t()) :: {:ok, Port.t()} | :error
  def find_output_port(%__MODULE__{output_ports: ports}, port_id) do
    case Enum.find(ports, &(&1.id == port_id)) do
      nil -> :error
      port -> {:ok, port}
    end
  end

  @doc "Finds an input port by id."
  @spec find_input_port(t(), String.t()) :: {:ok, Port.t()} | :error
  def find_input_port(%__MODULE__{input_ports: ports}, port_id) do
    case Enum.find(ports, &(&1.id == port_id)) do
      nil -> :error
      port -> {:ok, port}
    end
  end

  defp gen_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
