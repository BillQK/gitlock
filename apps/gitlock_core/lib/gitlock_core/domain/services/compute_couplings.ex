defmodule GitlockCore.Domain.Services.ComputeCouplings do
  @moduledoc """
  Contains core algorithms for coupling and blast radius calculations.

  This service provides:
  - Coupling strength calculation between files
  - Blast radius determination through graph traversal
  - Impact level computation based on coupling and distance
  - Trend analysis for changing relationships

  The core algorithms for change impact analysis reside here.
  """
  alias GitlockCore.Domain.Values.FileGraph
  alias GitlockCore.Domain.Values.CouplingsMetrics

  @doc """
  Calculates the coupling strength, trend, and filters results based on thresholds.

  ## Parameters
    - all: Full co-change data map.
    - early: Early commit co-change data.
    - recent: Recent commit co-change data.
    - file_counts: Map of file to total commit counts.
    - min_coupling: Minimum coupling degree to include a result.
    - min_windows: Minimum number of co-change windows.

  ## Returns
    - List of `coupling_result` sorted by descending degree.
  """
  @spec calculate_coupling_strength(
          %{{String.t(), String.t()} => integer()},
          %{{String.t(), String.t()} => integer()},
          %{{String.t(), String.t()} => integer()},
          %{String.t() => integer()},
          float(),
          integer()
        ) :: [CouplingsMetrics.t()]
  def calculate_coupling_strength(all, early, recent, file_counts, min_coupling, min_windows) do
    # Handle empty coupling data
    if map_size(all) == 0 do
      []
    else
      Enum.map(all, fn {{file1, file2}, shared} ->
        total1 = Map.get(file_counts, file1, 1)
        total2 = Map.get(file_counts, file2, 1)
        avg = (total1 + total2) / 2.0

        degree = shared / avg * 100.0

        # Calculate trend only if we have data in both periods
        trend =
          calculate_trend(
            {file1, file2},
            shared,
            early,
            recent,
            avg,
            map_size(early) > 0 && map_size(recent) > 0
          )

        %CouplingsMetrics{
          entity: file1,
          coupled: file2,
          degree: Float.round(degree, 1),
          windows: shared,
          trend: trend
        }
      end)
      |> Enum.filter(fn %{degree: degree, windows: windows} ->
        degree >= min_coupling and windows >= min_windows
      end)
      |> Enum.sort_by(& &1.degree, :desc)
    end
  end

  # Calculate trend with better handling of edge cases
  defp calculate_trend({file1, file2}, _total_shared, early, recent, avg, true) do
    early_shared = Map.get(early, {file1, file2}, 0)
    recent_shared = Map.get(recent, {file1, file2}, 0)

    # Use half the average for each period
    period_avg = avg / 2

    early_degree = if period_avg > 0, do: early_shared / period_avg * 100.0, else: 0.0
    recent_degree = if period_avg > 0, do: recent_shared / period_avg * 100.0, else: 0.0

    Float.round(recent_degree - early_degree, 1)
  end

  defp calculate_trend(_, _, _, _, _, false) do
    # Not enough data to calculate trend
    0.0
  end

  @doc """
  Calculates basic coupling strength between two files.

  ## Parameters
    * `co_changes` - Number of times the files changed together
    * `revs1` - Number of revisions of the first file
    * `revs2` - Number of revisions of the second file
    
  ## Returns
    Coupling strength as a float (0.0-1.0)
    
  ## Examples
      iex> ComputeCouplings.coupling_strength(5, 10, 10)
      0.5
      
      # With different revision counts
      iex> ComputeCouplings.coupling_strength(3, 5, 10)
      0.4
      
      # When co-changes exceed average revisions (capped at 1.0)
      iex> ComputeCouplings.coupling_strength(12, 8, 8)
      1.0
  """
  @spec coupling_strength(non_neg_integer(), non_neg_integer(), non_neg_integer()) :: float()
  def coupling_strength(co_changes, revs1, revs2) do
    avg_revs = (max(revs1, 1) + max(revs2, 1)) / 2
    coupling = co_changes / avg_revs

    # Ensure result is between 0.0 and 1.0
    min(max(coupling, 0.0), 1.0)
  end

  @doc """
  Calculates the blast radius for a file in the graph.

  Performs a breadth-first traversal to identify all files potentially affected
  by a change to the target file, based on coupling relationships.

  ## Parameters
    * `graph` - The file graph to analyze
    * `target_file` - Path to the target file
    * `threshold` - Minimum coupling strength to consider (0.0-1.0)
    * `max_depth` - Maximum depth of the blast radius search
    
  ## Returns
    A list of {file_path, impact_value, distance} tuples
    
  ## Examples
      # Setup a simple graph with 3 files
      iex> nodes = %{
      ...>   "lib/a.ex" => %{complexity: 10, loc: 100, revisions: 5, component: "core"},
      ...>   "lib/b.ex" => %{complexity: 5, loc: 50, revisions: 3, component: "core"},
      ...>   "lib/c.ex" => %{complexity: 8, loc: 80, revisions: 4, component: "utils"}
      ...> }
      iex> edges = [
      ...>   {"lib/a.ex", "lib/b.ex", 0.7},  # Strong coupling between A and B
      ...>   {"lib/b.ex", "lib/c.ex", 0.4}   # Medium coupling between B and C
      ...> ]
      iex> graph = FileGraph.new(nodes, edges, %{})
      iex> 
      iex> # Calculate blast radius for file A with default threshold
      iex> ComputeCouplings.blast_radius(graph, "lib/a.ex", 0.3, 2)
      [
        {"lib/a.ex", 1.0, 0},       # Target file has full impact
        {"lib/b.ex", 0.7, 1},       # Directly coupled at 0.7 strength
        {"lib/c.ex", 0.14, 2}       # Indirectly coupled (0.7 * 0.4) / 2 (distance factor)
      ]
  """
  @spec blast_radius(FileGraph.t(), String.t(), float(), non_neg_integer()) :: [
          {String.t(), float(), non_neg_integer()}
        ]
  def blast_radius(%FileGraph{} = graph, target_file, threshold, max_depth) do
    # Initialize wit the target file at full impact_pact 
    initial_blast = [{target_file, 1.0, 0}]
    initial_queue = [{target_file, 0}]

    blast_radius_bfs(
      graph,
      initial_blast,
      initial_queue,
      threshold,
      max_depth,
      MapSet.new([target_file])
    )
  end

  # BFS implementation for blast radius calculation 
  @spec blast_radius_bfs(
          FileGraph.t(),
          [{String.t(), float(), non_neg_integer()}],
          [{String.t(), non_neg_integer()}],
          float(),
          non_neg_integer(),
          MapSet.t()
        ) :: [{String.t(), float(), non_neg_integer()}]
  defp blast_radius_bfs(_graph, blast_radius, [], _threshold, _max_depth, _visited),
    do: blast_radius

  defp blast_radius_bfs(_graph, blast_radius, _queue, _threshold, 0, _visited),
    do: blast_radius

  defp blast_radius_bfs(
         graph,
         blast_radius,
         [{current_file, depth} | rest],
         threshold,
         max_depth,
         visited
       ) do
    # Get the current file's impact 
    {_, current_impact, _} =
      Enum.find(blast_radius, {nil, 0.0, 0}, fn {file, _, _} -> file == current_file end)

    # Find the coupled files above threshold
    coupled_files = find_coupled_files(graph, current_file, threshold, visited)

    # Calculate impacts for the coupled files 
    {new_blast, new_queue, new_visited} =
      calculate_impact(coupled_files, blast_radius, rest, visited, current_impact, depth + 1)

    # Continue BFS traversal
    blast_radius_bfs(graph, new_blast, new_queue, threshold, max_depth - 1, new_visited)
  end

  @doc """
  Finds files coupled with a source file above a threshold.

  ## Parameters
    * `graph` - The file graph
    * `source_file` - Path to the source file
    * `threshold` - Minimum coupling strength
    * `visited` - Set of already visited files
    
  ## Returns
    List of {file_path, coupling_strength} tuples
    
  ## Examples
      iex> # Setup a simple graph
      iex> edges = [
      ...>   {"lib/auth/session.ex", "lib/auth/token.ex", 0.8},
      ...>   {"lib/auth/session.ex", "lib/user/profile.ex", 0.3},
      ...>   {"lib/auth/session.ex", "lib/config/settings.ex", 0.2}
      ...> ]
      iex> graph = FileGraph.new(%{}, edges, %{})
      iex> visited = MapSet.new(["lib/auth/session.ex"])
      ...>
      iex> # Find coupled files with threshold 0.3
      iex> ComputeCouplings.find_coupled_files(graph, "lib/auth/session.ex", 0.3, visited)
      [
        {"lib/auth/token.ex", 0.8},
        {"lib/user/profile.ex", 0.3}
      ]
  """
  @spec find_coupled_files(FileGraph.t(), String.t(), float(), MapSet.t()) :: [
          {String.t(), float()}
        ]
  def find_coupled_files(%FileGraph{edges: edges}, source_file, threshold, visited) do
    edges
    |> Enum.filter(fn {src, dst, strength} ->
      (src == source_file || dst == source_file) && strength >= threshold
    end)
    |> Enum.map(fn {src, dst, strength} ->
      coupled_file = if src == source_file, do: dst, else: src
      {coupled_file, strength}
    end)
    |> Enum.filter(fn {coupled_file, _strength} ->
      !MapSet.member?(visited, coupled_file)
    end)
  end

  @doc """
  Calculates impact for files based on coupling and distance.

  ## Parameters
    * `coupled_files` - List of {file_path, coupling_strength} tuples
    * `blast_radius` - Current blast radius list
    * `queue` - Current BFS queue
    * `visited` - Set of already visited files
    * `current_impact` - Impact of the current file
    * `new_depth` - Depth of the coupled files
    
  ## Returns
    Tuple of {updated_blast_radius, updated_queue, updated_visited}
    
  ## Examples
      iex> # Setup initial data
      iex> coupled_files = [
      ...>   {"lib/auth/token.ex", 0.8},
      ...>   {"lib/user/profile.ex", 0.4}
      ...> ]
      iex> blast_radius = [{"lib/auth/session.ex", 1.0, 0}]
      iex> queue = []
      iex> visited = MapSet.new(["lib/auth/session.ex"])
      iex> current_impact = 1.0
      iex> new_depth = 1
      ...>
      iex> # Calculate impact
      iex> {new_blast, new_queue, new_visited} = 
      ...>   ComputeCouplings.calculate_impact(
      ...>     coupled_files, blast_radius, queue, visited, current_impact, new_depth
      ...>   )
      iex> new_blast
      [
        {"lib/auth/session.ex", 1.0, 0},
        {"lib/auth/token.ex", 0.8, 1},
        {"lib/user/profile.ex", 0.4, 1}
      ]
  """

  @spec calculate_impact(
          [{String.t(), float()}],
          %{String.t() => float()},
          [{String.t(), non_neg_integer()}],
          MapSet.t(),
          float(),
          non_neg_integer()
        ) :: {
          [{String.t(), float(), non_neg_integer()}],
          [{String.t(), non_neg_integer()}],
          MapSet.t(String.t())
        }
  def calculate_impact(coupled_files, blast_radius, queue, visited, current_impact, new_depth) do
    coupled_files
    |> Enum.reduce({blast_radius, queue, visited}, fn {file, coupling},
                                                      {blast_acc, queue_acc, visited_acc} ->
      # Calculate impact
      impact = current_impact * coupling * (1.0 / new_depth)

      # Update blast radius (append to list)
      new_blast = blast_acc ++ [{file, impact, new_depth}]

      # Add to queue for further traversal
      new_queue = queue_acc ++ [{file, new_depth}]

      # Mark as visited
      new_visited = MapSet.put(visited_acc, file)

      {new_blast, new_queue, new_visited}
    end)
  end
end
