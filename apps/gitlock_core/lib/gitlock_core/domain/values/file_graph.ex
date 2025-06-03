defmodule GitlockCore.Domain.Values.FileGraph do
  @moduledoc """
  A graph representation of repository files and their relationships.

  `FileGraph` is an immutable value object that models a codebase as a graph structure:
  * Files as nodes
  * Coupling relationships as edges
  * Metadata about the repository and analysis

  This structure enables analyzing how changes to one file might affect other files
  in the codebase based on historical patterns of changes extracted from version
  control history.

  ## Structure

  * `nodes` - Map of file paths to metadata (revisions, complexity, component, authors, LOC)
  * `edges` - List of tuples representing coupling relationships between files
  * `metadata` - Map storing raw coupling data, file counts, and analysis timestamps

  ## Node Metadata

  Each node contains:
  * `revisions` - How many times the file has been changed
  * `complexity` - Cyclomatic complexity measure of the file
  * `component` - Which architectural component the file belongs to
  * `authors` - List of developers who have modified the file
  * `loc` - Lines of code in the file

  ## Edge Data

  Edges contain:
  * Source file (node 1)
  * Target file (node 2)
  * Coupling strength (from 0.0 to 1.0)

  ## Metadata

  The graph metadata contains:
  * `total_files` - Total number of files in the analysis
  * `total_commits` - Total number of commits analyzed
  * `generated_at` - When the graph was created
  * `raw_coupling_data` - Original co-change counts between file pairs
  * `file_commit_counts` - How many commits touched each file
  """

  @type node_id :: String.t()

  @type node_metadata :: %{
          revisions: non_neg_integer(),
          complexity: non_neg_integer(),
          component: String.t(),
          authors: [String.t()],
          loc: non_neg_integer()
        }

  @type edge :: {node_id(), node_id(), float()}

  @type t :: %__MODULE__{
          nodes: %{node_id() => node_metadata()},
          edges: [edge()],
          metadata: map()
        }

  defstruct nodes: %{}, edges: [], metadata: %{}

  @doc """
  Creates a new FileGraph with the specified nodes, edges, and metadata.

  ## Parameters
    * `nodes` - Map of file paths to node metadata
    * `edges` - List of edges representing coupling relationships
    * `metadata` - Map of graph metadata
    
  ## Returns
    A new FileGraph value object
    
  ## Example
      iex> nodes = %{
      ...>   "lib/auth/session.ex" => %{
      ...>     revisions: 15,
      ...>     complexity: 12,
      ...>     component: "auth",
      ...>     authors: ["Alice", "Bob"],
      ...>     loc: 150
      ...>   }
      ...> }
      iex> edges = [{"lib/auth/session.ex", "lib/auth/token.ex", 0.75}]
      iex> metadata = %{total_files: 1, total_commits: 15, generated_at: ~U[2025-05-18 12:00:00Z]}
      iex> FileGraph.new(nodes, edges, metadata)
      %FileGraph{
        nodes: %{"lib/auth/session.ex" => %{...}},
        edges: [{"lib/auth/session.ex", "lib/auth/token.ex", 0.75}],
        metadata: %{total_files: 1, total_commits: 15, generated_at: ~U[2025-05-18 12:00:00Z]}
      }
  """
  @spec new(
          %{node_id() => node_metadata()},
          [edge()],
          map()
        ) :: t()
  def new(nodes, edges, metadata) do
    %__MODULE__{
      nodes: nodes,
      edges: edges,
      metadata: metadata
    }
  end

  @doc """
  Gets a list of all components in the graph.

  ## Returns
    A list of unique component names
  """
  @spec components(t()) :: [String.t()]
  def components(%__MODULE__{nodes: nodes}) do
    nodes
    |> Enum.map(fn {_file, metadata} ->
      Map.get(metadata, :component)
    end)
    |> Enum.filter(&(&1 != nil))
    |> Enum.uniq()
  end

  @doc """
  Gets the complexity metrics for a specific file.

  ## Parameters
    * `graph` - The file graph
    * `file_path` - Path to the file
    
  ## Returns
    A map with complexity, LOC, and revisions
  """
  @spec file_metrics(t(), String.t()) :: %{
          complexity: non_neg_integer(),
          loc: non_neg_integer(),
          revisions: non_neg_integer()
        }
  def file_metrics(%__MODULE__{nodes: nodes}, file_path) do
    case Map.get(nodes, file_path) do
      nil ->
        %{complexity: 0, loc: 0, revisions: 0}

      metadata ->
        %{
          complexity: Map.get(metadata, :complexity, 0),
          loc: Map.get(metadata, :loc, 0),
          revisions: Map.get(metadata, :revisions, 0)
        }
    end
  end

  @doc """
  Gets all files in a specific component.

  ## Parameters
    * `graph` - The file graph
    * `component` - Name of the component
    
  ## Returns
    A list of file paths in the component
  """
  @spec files_in_component(t(), String.t()) :: [String.t()]
  def files_in_component(%__MODULE__{nodes: nodes}, component) do
    nodes
    |> Enum.filter(fn {_file, metadata} -> metadata.component == component end)
    |> Enum.map(fn {file, _metadata} -> file end)
  end

  @doc """
  Gets the coupling strength between two files.

  ## Parameters
    * `graph` - The file graph
    * `file1` - First file path
    * `file2` - Second file path
    
  ## Returns
    Coupling strength as a float (0.0-1.0), or 0.0 if no coupling exists
  """
  @spec coupling_strength(t(), String.t(), String.t()) :: float()
  def coupling_strength(%__MODULE__{edges: edges}, file1, file2) do
    key = if file1 <= file2, do: {file1, file2}, else: {file2, file1}

    case Map.get(edges, key) do
      nil -> 0.0
      edge_data -> edge_data.coupling_strength
    end
  end

  @doc """
  Gets the most coupled files for a target file.

  ## Parameters
    * `graph` - The file graph
    * `file_path` - Target file path
    * `threshold` - Minimum coupling strength to consider (0.0-1.0)
    * `limit` - Maximum number of files to return
    
  ## Returns
    List of {file_path, coupling_strength} tuples sorted by descending strength
  """
  @spec coupled_files(t(), String.t(), float(), non_neg_integer()) :: [{String.t(), float()}]
  def coupled_files(%__MODULE__{edges: edges}, file_path, threshold, limit) do
    edges
    |> Enum.filter(fn {{f1, f2}, edge_data} ->
      (f1 == file_path || f2 == file_path) &&
        edge_data.coupling_strength >= threshold
    end)
    |> Enum.map(fn {{f1, f2}, edge_data} ->
      coupled_file = if f1 == file_path, do: f2, else: f1
      {coupled_file, edge_data.coupling_strength}
    end)
    |> Enum.sort_by(fn {_file, strength} -> strength end, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Validates files exists in graph 

  ## Parameters 
    * `file_path` - Target file path
    * `graph - The file graph

  ## Returns 
    :ok or {:error, description}
  """
  @spec validate_file_exists_in_graph(String.t(), t()) :: :ok | {:error, String.t()}
  def validate_file_exists_in_graph(file, %__MODULE__{nodes: nodes}) do
    if Map.has_key?(nodes, file) do
      :ok
    else
      {:error, "File '#{file}' not found in the file graph"}
    end
  end

  @doc """
  Validate graph 

  ## Parameters 
    * `graph` - The file graph

  ## Returns
    :ok or {:error, description}
  """
  @spec validate_graph(t()) :: :ok | {:error, String.t()}
  def validate_graph(%__MODULE__{}), do: :ok

  def validate_graph(invalid),
    do: {:error, "Expected a FileGraph struct, got: #{inspect(invalid)}"}
end
