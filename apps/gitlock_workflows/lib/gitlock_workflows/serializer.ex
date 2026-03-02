defmodule GitlockWorkflows.Serializer do
  @moduledoc """
  Serializes workflow domain structs for the SvelteFlow UI layer.
  """

  alias GitlockWorkflows.{Pipeline, Node, Edge, Port, NodeCatalog}

  @doc "Serializes a Pipeline to a map ready for JSON encoding."
  @spec to_map(Pipeline.t()) :: map()
  def to_map(%Pipeline{} = pipeline) do
    %{
      id: pipeline.id,
      name: pipeline.name,
      nodes: Map.new(pipeline.nodes, fn {id, node} -> {id, node_to_map(node)} end),
      edges: Map.new(pipeline.edges, fn {id, edge} -> {id, edge_to_map(edge)} end)
    }
  end

  @doc "Serializes the node catalog grouped by category for the palette UI."
  @spec catalog_to_list() :: [map()]
  def catalog_to_list do
    NodeCatalog.list_types()
    |> Enum.group_by(& &1.category)
    |> Enum.sort_by(fn {cat, _} -> category_order(cat) end)
    |> Enum.map(fn {category, types} ->
      %{
        name: category_label(category),
        types:
          Enum.map(types, fn type_def ->
            %{
              type_id: type_def.type_id,
              label: type_def.label,
              description: type_def.description,
              category: type_def.category,
              config_schema: Map.get(type_def, :config_schema, [])
            }
          end)
          |> Enum.sort_by(& &1.label)
      }
    end)
  end

  defp node_to_map(%Node{} = node) do
    {:ok, type_def} = NodeCatalog.get_type(node.type)
    {x, y} = node.position

    %{
      id: node.id,
      type: node.type,
      label: node.label,
      category: type_def.category,
      position: [x, y],
      config: node.config,
      config_schema: Map.get(type_def, :config_schema, []),
      input_ports: Enum.map(node.input_ports, &port_to_map/1),
      output_ports: Enum.map(node.output_ports, &port_to_map/1)
    }
  end

  defp edge_to_map(%Edge{} = edge) do
    %{
      id: edge.id,
      source_node_id: edge.source_node_id,
      source_port_id: edge.source_port_id,
      target_node_id: edge.target_node_id,
      target_port_id: edge.target_port_id
    }
  end

  defp port_to_map(%Port{} = port) do
    map = %{id: port.id, name: port.name, data_type: port.data_type}
    if port.optional, do: Map.put(map, :optional, true), else: map
  end

  defp category_label(:source), do: "Sources"
  defp category_label(:filter), do: "Filters"
  defp category_label(:analyze), do: "Analyzers"
  defp category_label(:logic), do: "Logic"
  defp category_label(:output), do: "Outputs"
  defp category_label(other), do: to_string(other) |> String.capitalize()

  defp category_order(:source), do: 0
  defp category_order(:analyze), do: 1
  defp category_order(:logic), do: 2
  defp category_order(:filter), do: 3
  defp category_order(:output), do: 4
  defp category_order(_), do: 5
end
