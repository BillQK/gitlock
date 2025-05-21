defmodule GitlockHolmesCore.Domain.Services.FileGraphBuilder do
  @moduledoc """
  Constructs file relationship graphs from commit history. 

  This service is responsible for: 
  - Creating graphs from commit history
  - Building nodes with file metadata
  - Constructing coupling edges
  - Delegating blast radius calculations

  It acts as a factory for File Graph objects, mapping version control history
  into a structured graph representation for analysis
  """

  alias GitlockHolmesCore.Domain.Values.{FileGraph, ComplexityMetrics, FileChange}
  alias GitlockHolmesCore.Domain.Entities.{Commit, Author}

  alias GitlockHolmesCore.Domain.Services.{
    CochangeAnalyzer
  }

  @doc """
  Creates a file graph from commit hisotry and optional complexity metrics. 

  ## Parameters
    * `commits` - List of commits to analyze
    * `complexity_map` - Optional map of file paths to complexity metrics 
    * `options` - Analysis options (e.g, component_mapping)

  ## Returns 
    A new FileGraph instance
  ## Examples
    iex> # Setup test data
    iex> author = Author.new("Alice", "alice@example.com")
    iex> file_changes1 = [
    ...>   FileChange.new("lib/auth/session.ex", 10, 5),
    ...>   FileChange.new("lib/auth/token.ex", 7, 3)
    ...> ]
    iex> file_changes2 = [
    ...>   FileChange.new("lib/auth/session.ex", 5, 2),
    ...>   FileChange.new("lib/user/profile.ex", 15, 0)
    ...> ]
    iex> commits = [
    ...>   Commit.new("abc123", author, "2023-01-01", "Fix auth", file_changes1),
    ...>   Commit.new("def456", author, "2023-01-05", "Add profile", file_changes2)
    ...> ]
    iex> 
    iex> # Complexity metrics
    iex> complexity_map = %{
    ...>   "lib/auth/session.ex" => ComplexityMetrics.new("lib/auth/session.ex", 100, 12, :elixir),
    ...>   "lib/auth/token.ex" => ComplexityMetrics.new("lib/auth/token.ex", 80, 8, :elixir),
    ...>   "lib/user/profile.ex" => ComplexityMetrics.new("lib/user/profile.ex", 120, 5, :elixir)
    ...> }
    iex> 
    iex> # Build the graph with component detection
    iex> graph = FileGraphBuilder.create_from_commits(commits, complexity_map)
    iex> 
    iex> # Inspect the result
    iex> map_size(graph.nodes)
    3
    iex> Enum.count(graph.edges)
    2
    iex> graph.nodes["lib/auth/session.ex"].revisions
    2
    iex> graph.nodes["lib/auth/session.ex"].complexity
    12
    iex> List.first(graph.edges)
    {"lib/auth/session.ex", "lib/auth/token.ex", 0.5}
    
    # With custom component mapping
    iex> custom_options = %{
    ...>   component_mapping: fn path ->
    ...>     cond do
    ...>       String.contains?(path, "auth") -> "authentication"
    ...>       String.contains?(path, "user") -> "user_management"
    ...>       true -> "other"
    ...>     end
    ...>   end
    ...> }
    iex> custom_graph = FileGraphBuilder.create_from_commits(commits, complexity_map, custom_options)
    iex> custom_graph.nodes["lib/auth/session.ex"].component
    "authentication"
    iex> custom_graph.nodes["lib/user/profile.ex"].component
    "user_management"
    
    # Without complexity metrics
    iex> basic_graph = FileGraphBuilder.create_from_commits(commits)
    iex> basic_graph.nodes["lib/auth/session.ex"].complexity
    0
    iex> length(FileGraph.components(basic_graph))
    2
    iex> length(basic_graph.edges) > 0
    true
  """
  @spec create_from_commits([Commit.t()], %{String.t() => ComplexityMetrics.t()}, map()) ::
          FileGraph.t()
  def create_from_commits(commits, complexity_map \\ %{}, options \\ %{}) do
    # Get coupling data from commit history
    {coupling_data, file_revisions} = CochangeAnalyzer.analyze_commits(commits)

    # Extract file paths from commits
    file_paths = extract_file_paths(commits)
    authors_by_file = extract_authors_by_file(commits)

    # Build graph nodes with metadata 
    nodes = build_nodes(file_paths, authors_by_file, file_revisions, complexity_map, options)

    # Build graph edges from coupling data 
    edges = build_edges(coupling_data, file_revisions)

    # Create metadata 
    metadata = %{
      total_files: length(file_paths),
      total_commits: length(commits),
      generated_at: DateTime.utc_now()
    }

    FileGraph.new(nodes, edges, metadata)
  end

  @doc """
    Builds node data for the file graph with metadata.

    ## Parameters
      * `file_paths` - List of file paths 
      * `authors_by_file` - Map of file paths to lists of authors
      * `file_revisions` - Map of file paths to revision counts
      * `complexity_map` - Map of file paths to complexity metrics
      * `options` - Analysis options:
          - `:component_mapping` - Function to classify files into components
            `(file_path -> component_name)`. Defaults to directory-based classification.
      
    ## Returns
      A map of file paths to node metadata containing:
        - `revisions`: Number of times the file was changed
        - `complexity`: Cyclomatic complexity of the file
        - `loc`: Lines of code in the file
        - `component`: Architectural component the file belongs to
        - `authors`: List of developers who've modified the file
      
    ## Examples
        # Basic node building with default component detection
        iex> file_paths = ["lib/auth/session.ex", "lib/user/profile.ex"]
        iex> authors_by_file = %{
        ...>   "lib/auth/session.ex" => ["Alice", "Bob"],
        ...>   "lib/user/profile.ex" => ["Carol"]
        ...> }
        iex> revisions = %{"lib/auth/session.ex" => 5, "lib/user/profile.ex" => 3}
        iex> complexity = %{
        ...>   "lib/auth/session.ex" => %ComplexityMetrics{
        ...>     cyclomatic_complexity: 10,
        ...>     loc: 100
        ...>   }
        ...> }
        iex> nodes = FileGraphBuilder.build_nodes(file_paths, authors_by_file, revisions, complexity, %{})
        iex> nodes["lib/auth/session.ex"].component
        "auth"
        iex> nodes["lib/auth/session.ex"].authors
        ["Alice", "Bob"]
        iex> nodes["lib/user/profile.ex"].revisions
        3
  """
  @spec build_nodes(
          [String.t()],
          %{String.t() => [String.t()]},
          %{String.t() => non_neg_integer()},
          %{String.t() => ComplexityMetrics.t()},
          map()
        ) :: %{String.t() => map()}
  def build_nodes(file_paths, authors_by_file, file_revisions, complexity_map, options) do
    component_mapping = Map.get(options, :component_mapping, &detect_component/1)

    file_paths
    |> Enum.map(fn file_path ->
      # Get complexity metrics if available 
      complexity_metrics = Map.get(complexity_map, file_path)

      # Extract values from complexity metrics 
      {complexity, loc} = extract_complexity_metrics(complexity_metrics)

      # Get revision count 
      revisions = Map.get(file_revisions, file_path, 0)

      # Determine component 
      component = component_mapping.(file_path)

      # Get authors for this file
      authors = Map.get(authors_by_file, file_path, [])

      # Create node metadata 
      metadata = %{
        revisions: revisions,
        complexity: complexity,
        loc: loc,
        component: component,
        authors: authors
      }

      {file_path, metadata}
    end)
    |> Map.new()
  end

  @doc """
  Builds edge data for the file graph from coupling analysis.

  ## Parameters
    * `coupling_data` - Map of file pairs to co-change counts
    * `file_revisions` - Map of file paths to revision counts
    
  ## Returns
    A list of edges (tuples of {file1, file2, coupling_strength})
    
  ## Examples
      iex> coupling_data = %{{"file1.ex", "file2.ex"} => 5}
      iex> file_revisions = %{"file1.ex" => 10, "file2.ex" => 10}
      iex> FileGraphBuilder.build_edges(coupling_data, file_revisions)
      [{"file1.ex", "file2.ex", 0.5}]
      
      # Example with higher coupling than revision count (capped at 1.0)
      iex> coupling_data = %{{"x.ex", "y.ex"} => 12}
      iex> revisions = %{"x.ex" => 8, "y.ex" => 8}
      iex> FileGraphBuilder.build_edges(coupling_data, revisions)
      [{"x.ex", "y.ex", 1.0}]
  """
  @spec build_edges(
          %{{String.t(), String.t()} => non_neg_integer()},
          %{String.t() => non_neg_integer()}
        ) :: [{String.t(), String.t(), float()}]
  def build_edges(coupling_data, file_revisions) do
    coupling_data
    |> Enum.map(fn {{file1, file2}, co_changes} ->
      # Get individual revision counts
      revs1 = Map.get(file_revisions, file1, 1)
      revs2 = Map.get(file_revisions, file2, 1)
      avg_revs = (revs1 + revs2) / 2

      # Calculate coupling strength
      coupling_strength = co_changes / avg_revs

      # Return edge tuple with capped strength (0.0-1.0)
      {file1, file2, min(coupling_strength, 1.0)}
    end)
  end

  @doc """
  Extracts unique file paths from commit history.

  ## Parameters
    * `commits` - List of commits to analyze
    
  ## Returns
    A list of unique file paths
    
  ## Examples
      iex> commits = [
      ...>   %Commit{file_changes: [%FileChange{entity: "file1.ex"}, %FileChange{entity: "file2.ex"}]},
      ...>   %Commit{file_changes: [%FileChange{entity: "file1.ex"}, %FileChange{entity: "file3.ex"}]}
      ...> ]
      iex> FileGraphBuilder.extract_file_paths(commits)
      ["file1.ex", "file2.ex", "file3.ex"]
  """
  @spec extract_file_paths([Commit.t()]) :: [String.t()]
  def extract_file_paths(commits) do
    commits
    |> Enum.flat_map(fn %Commit{file_changes: changes} ->
      Enum.map(changes, & &1.entity)
    end)
    |> Enum.uniq()
  end

  # Helper function to extract complexity metrics
  @spec extract_complexity_metrics(ComplexityMetrics.t() | nil) ::
          {non_neg_integer(), non_neg_integer()}
  defp extract_complexity_metrics(nil), do: {0, 0}
  defp extract_complexity_metrics(metrics), do: {metrics.cyclomatic_complexity, metrics.loc}

  # Helper to extract authors by file from commits
  @spec extract_authors_by_file([Commit.t()]) :: %{String.t() => [String.t()]}
  defp extract_authors_by_file(commits) do
    commits
    |> Enum.flat_map(fn %Commit{author: author, file_changes: changes} ->
      author_name = Author.display_name(author)
      Enum.map(changes, fn %FileChange{entity: file} -> {file, author_name} end)
    end)
    |> Enum.group_by(
      fn {file, _author} -> file end,
      fn {_file, author} -> author end
    )
    |> Map.new(fn {file, authors} -> {file, Enum.uniq(authors)} end)
  end

  # Helper function to detect component from file path
  @spec detect_component(String.t()) :: String.t() | nil
  defp detect_component(file_path) do
    case Path.split(file_path) do
      # Standard Elixir/Phoenix structure
      ["lib", component | _rest] ->
        component

      # Umbrella app structure
      ["apps", _app, "lib", component | _rest] ->
        component

      # Test files
      ["test", component | _rest] ->
        component

      # Default case: use parent directory
      _ ->
        dirname = Path.dirname(file_path)
        parts = Path.split(dirname)
        List.last(parts)
    end
  end
end
