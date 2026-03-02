defmodule GitlockWorkflows.Edge do
  @moduledoc """
  A directed connection between an output port of one node
  and an input port of another node.
  """

  @type t :: %__MODULE__{
          id: String.t(),
          source_node_id: String.t(),
          source_port_id: String.t(),
          target_node_id: String.t(),
          target_port_id: String.t()
        }

  @enforce_keys [:id, :source_node_id, :source_port_id, :target_node_id, :target_port_id]
  defstruct [:id, :source_node_id, :source_port_id, :target_node_id, :target_port_id]

  @doc """
  Creates a new edge connecting a source output port to a target input port.
  """
  @spec new(String.t(), String.t(), String.t(), String.t()) :: t()
  def new(source_node_id, source_port_id, target_node_id, target_port_id) do
    %__MODULE__{
      id: gen_id(),
      source_node_id: source_node_id,
      source_port_id: source_port_id,
      target_node_id: target_node_id,
      target_port_id: target_port_id
    }
  end

  defp gen_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
