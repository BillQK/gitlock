defmodule GitlockHolmesCore.Domain.Services.ComponentImpactAnalysis do
  @moduledoc """
  Service for analyzing cross-component impact   \"""

  alias GitlockHolmesCore.Domain.Values.FileGraph

  @doc \"""
  Calculates the cross-compoent impact from a set of affected files. 
  This function determines how changes are distributed across different architectural components based on the blast radius of a change.
  ## Parameters
    * `graph` - The FileGraph
    * `affected_files` - List of {file, impact_level, distance} tuples from blast radius
    
  ## Returns
    A map of components to total impact scores
    
  ## Example
      iex> affected_files = [
      ...>   {"lib/auth/session.ex", 0.8, 1},
      ...>   {"lib/user/profile.ex", 0.5, 1}
      ...> ]
      iex> FileGraph.cross_component_impact(graph, affected_files)
      %{
        "auth" => 0.8,
        "user" => 0.5
      }
  """
  @spec calculate_cross_component_impact(FileGraph.t(), [{String.t(), float(), non_neg_integer()}]) ::
          %{String.t() => float()}
  def calculate_cross_component_impact(graph, affected_files) do
    affected_files
    |> Enum.map(fn {file, impact, _} ->
      component = get_component(graph, file)
      {component, impact}
    end)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Map.new(fn {component, impacts} -> {component, Enum.sum(impacts)} end)
  end

  @doc """
  Identifies connector files that bridge architectural components

  Connector files are those have strong coupling relationships with files from different components,
  suggesting they may be architectural boundary points or responsibility that span multiple concerns. 

  ## Parameters
    * `graph` - The FileGraph
    * `threshold` - Minimum coupling strength to consider (default: 0.3)
    
  ## Returns
    A list of {file, [components], avg_strength} tuples
    
  ## Example
      iex> FileGraph.connector_files(graph, 0.3)
      [
        {"lib/auth/session_manager.ex", ["auth", "user"], 0.65}
      ]
  """
  @spec find_connector_files(FileGraph.t(), float()) :: [{String.t(), [String.t()], float()}]
  def find_connector_files(graph, threshold \\ 0.3) do
    graph.edges
    |> Stream.filter(fn {src, dst, strength} ->
      strength >= threshold && get_component(graph, src) != get_component(graph, dst)
    end)
    |> Stream.flat_map(fn {src, dst, strength} ->
      src_component = get_component(graph, src)
      dst_component = get_component(graph, dst)

      [
        {src, [src_component, dst_component], strength},
        {dst, [src_component, dst_component], strength}
      ]
    end)
    |> Enum.group_by(&elem(&1, 0))
    |> Enum.map(fn {file, connections} ->
      components =
        connections
        |> Enum.flat_map(&elem(&1, 1))
        |> Enum.uniq()

      strengths = Enum.map(connections, &elem(&1, 2))
      avg_strength = Enum.sum(strengths) / length(strengths)
      {file, components, avg_strength}
    end)
  end

  defp get_component(graph, file) do
    get_in(graph.nodes, [file, :component])
  end
end
