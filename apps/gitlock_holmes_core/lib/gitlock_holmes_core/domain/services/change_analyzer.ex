defmodule GitlockHolmesCore.Domain.Services.ChangeAnalyzer do
  @moduledoc """
  Service for analyzing the impact of code changes. 

  This service is responsibile for: 
  - Analyzing the potential impact of changing specific files 
  - Calculating risk scores based on multiple factors
  - Identifying files affected by a change 
  - Suggesting appriopriate reviewers 
  - Determining cross-component impact

  It provides the core business logic for impact assessment 
  """
  alias GitlockHolmesCore.Domain.Services.ComponentImpactAnalysis
  alias GitlockHolmesCore.Domain.Values.ChangeImpact
  alias GitlockHolmesCore.Domain.Values.FileGraph
  alias GitlockHolmesCore.Domain.Services.ComputeCouplings

  @max_size_factor 2.0
  @size_divisor 5

  @max_complexity_factor 2.5
  @complexity_divisor 10

  @max_revision_factor 2.5
  @revision_divisor 10

  @max_cross_component_factor 3.0
  @cross_component_multiplier 0.8

  @max_total_score 10.0

  @doc """
  Analyzes the impact of chainging multiple target files. 

  ## Parameters 
    * `target_files` - List of file paths to analyze
    * `graph` - The file graph to analyze   
    * `options` - Analysis options

  ## Returns 
    List of ChangeImpact objects 

  ## Examples
      iex> graph = build_test_graph()
      iex> ChangeImpactAnalysis.analyze_changes(
      ...>   ["lib/auth/session.ex", "lib/user/profile.ex"],
      ...>   graph,
      ...>   blast_threshold: 0.3
      ...> )
      [
        %ChangeImpact{entity: "lib/auth/session.ex", ...},
        %ChangeImpact{entity: "lib/user/profile.ex", ...}
      ]  
  """
  @spec analyze_changes([String.t()], FileGraph.t(), map()) ::
          [ChangeImpact.t()] | {:error, String.t()}
  def analyze_changes(target_files, graph, options \\ %{}) do
    with :ok <- validate_target_files(target_files),
         :ok <- FileGraph.validate_graph(graph) do
      Enum.map(target_files, fn file ->
        analyze_file_impact(file, graph, options)
      end)
    end
  end

  @spec validate_target_files(term()) :: :ok | {:error, String.t()}
  defp validate_target_files(files) when is_list(files) and length(files) > 0, do: :ok
  defp validate_target_files([]), do: {:error, "Target files list cannot be empty"}

  defp validate_target_files(invalid),
    do: {:error, "Expected a list of target files, got: #{inspect(invalid)}"}

  @doc """
  Analyzes the impact of changing a single target file.

  ## Parameters
    * `target_file` - Path to the target file
    * `graph` - The file graph to analyze
    * `options` - Analysis options
    
  ## Returns
    A ChangeImpact object with the analysis results
    
  ## Examples
      iex> graph = build_test_graph()
      iex> impact = ChangeImpactAnalysis.analyze_file_impact(
      ...>   "lib/auth/session.ex",
      ...>   graph,
      ...>   blast_threshold: 0.3,
      ...>   max_radius: 2
      ...> )
      iex> impact.entity
      "lib/auth/session.ex"
      iex> impact.impact_severity
      :high
  """
  @spec analyze_file_impact(String.t(), FileGraph.t(), map()) ::
          ChangeImpact.t() | {:error, String.t()}
  def analyze_file_impact(target_file, graph, options \\ %{}) do
    with :ok <- FileGraph.validate_file_exists_in_graph(target_file, graph) do
      # Set default options if not provided 
      blast_threshold = Map.get(options, :blast_threshold, 0.3)
      max_radius = Map.get(options, :max_radius, 2)

      blast_radius =
        ComputeCouplings.blast_radius(graph, target_file, blast_threshold, max_radius)

      file_metrics = FileGraph.file_metrics(graph, target_file)
      affected_files = format_affected_files(graph, blast_radius)

      affected_components =
        ComponentImpactAnalysis.calculate_cross_component_impact(graph, blast_radius)

      risk_score =
        calculate_risk_score(
          blast_radius,
          file_metrics,
          affected_components,
          options
        )

      risk_factors =
        identify_risk_factors(
          target_file,
          file_metrics,
          blast_radius,
          affected_components
        )

      suggested_reviewers = suggest_reviewers(graph, target_file, blast_radius)

      ChangeImpact.new(
        target_file,
        risk_score,
        affected_files,
        affected_components,
        suggested_reviewers,
        risk_factors
      )
    end
  end

  @doc """
  Calculates a risk score based on multiple factors.

  ## Parameters
    * `blast_radius` - List of {file_path, impact, distance} tuples
    * `file_metrics` - Metrics of the target file
    * `affected_components` - Components affected by the change
    * `options` - Analysis options
    
  ## Returns
    Risk score as a float (0.0-10.0)
    
  ## Examples
      iex> blast_radius = [
      ...>   {"lib/auth/session.ex", 1.0, 0},
      ...>   {"lib/auth/token.ex", 0.8, 1},
      ...>   {"lib/user/profile.ex", 0.5, 1}
      ...> ]
      iex> file_metrics = %{complexity: 15, loc: 200, revisions: 12}
      iex> affected_components = %{"auth" => 0.8, "user" => 0.5}
      iex> ChangeImpactAnalysis.calculate_risk_score(
      ...>   blast_radius,
      ...>   file_metrics,
      ...>   affected_components
      ...> )
      7.15
  """
  @spec calculate_risk_score(
          [{String.t(), float(), non_neg_integer()}],
          %{complexity: non_neg_integer(), loc: non_neg_integer(), revisions: non_neg_integer()},
          %{String.t() => float()},
          keyword()
        ) :: float()
  def calculate_risk_score(blast_radius, file_metrics, affected_components, _options \\ []) do
    # Size factor (0-2 points): based on blast radius size
    size_factor = min(length(blast_radius) / @size_divisor, @max_size_factor)

    # Complexity factor (0-2.5 points): based on code complexity
    complexity_factor = min(file_metrics.complexity / @complexity_divisor, @max_complexity_factor)

    # Revision factor (0-2.5 points): based on change frequency
    revision_factor = min(file_metrics.revisions / @revision_divisor, @max_revision_factor)

    # Cross-component factor (0-3 points): based on architectural impact
    cross_component_factor =
      min(
        map_size(affected_components) * @cross_component_multiplier,
        @max_cross_component_factor
      )

    # Calculate total score (max 10.0)
    total_score = size_factor + complexity_factor + revision_factor + cross_component_factor

    # Cap at max score
    min(total_score, @max_total_score)
  end

  @doc """
  Identifies risk factors associated with a change.

  ## Parameters
    * `target_file` - Path to the target file
    * `file_metrics` - Metrics of the target file
    * `blast_radius` - List of {file_path, impact, distance} tuples
    * `affected_components` - Components affected by the change
    
  ## Returns
    List of risk factor descriptions
    
  ## Examples
      iex> file_metrics = %{complexity: 25, loc: 200, revisions: 8}
      iex> blast_radius = List.duplicate({"x", 0.5, 1}, 12)
      iex> components = %{"auth" => 0.8, "user" => 0.5, "core" => 0.3}
      iex> ChangeImpactAnalysis.identify_risk_factors(
      ...>   "lib/auth/session.ex",
      ...>   file_metrics,
      ...>   blast_radius,
      ...>   components
      ...> )
      [
        "High code complexity (score: 25)",
        "Large blast radius (12 affected files)",
        "Cross-component impact (affects 3 components)"
      ]
  """
  @spec identify_risk_factors(
          String.t(),
          %{complexity: non_neg_integer(), loc: non_neg_integer(), revisions: non_neg_integer()},
          [{String.t(), float(), non_neg_integer()}],
          %{String.t() => float()}
        ) :: [String.t()]
  def identify_risk_factors(_target_file, file_metrics, blast_radius, affected_components) do
    risk_factors = []

    # Check for high complexity
    risk_factors =
      if file_metrics.complexity > 20 do
        ["High code complexity (score: #{file_metrics.complexity})" | risk_factors]
      else
        risk_factors
      end

    # Check for frequent changes
    risk_factors =
      if file_metrics.revisions > 15 do
        ["Frequently changed file (#{file_metrics.revisions} revisions)" | risk_factors]
      else
        risk_factors
      end

    # Check for large blast radius
    risk_factors =
      if length(blast_radius) > 10 do
        ["Large blast radius (#{length(blast_radius)} affected files)" | risk_factors]
      else
        risk_factors
      end

    # Check for cross-component impact
    risk_factors =
      if map_size(affected_components) > 1 do
        [
          "Cross-component impact (affects #{map_size(affected_components)} components)"
          | risk_factors
        ]
      else
        risk_factors
      end

    # Return the list of risk factors
    risk_factors
  end

  @doc """
  Suggests reviewers based on file history and blast radius.

  ## Parameters
    * `graph` - The file graph
    * `target_file` - Path to the target file
    * `blast_radius` - List of {file_path, impact, distance} tuples
    
  ## Returns
    List of recommended reviewers
    
  ## Examples
      iex> graph = %FileGraph{nodes: %{
      ...>   "lib/auth/session.ex" => %{authors: ["Alice", "Bob"]},
      ...>   "lib/auth/token.ex" => %{authors: ["Bob", "Carol"]}
      ...> }}
      iex> blast_radius = [
      ...>   {"lib/auth/session.ex", 1.0, 0},
      ...>   {"lib/auth/token.ex", 0.8, 1}
      ...> ]
      iex> ChangeImpactAnalysis.suggest_reviewers(graph, "lib/auth/session.ex", blast_radius)
      ["Alice", "Bob", "Carol"]
  """
  @spec suggest_reviewers(FileGraph.t(), String.t(), [{String.t(), float(), non_neg_integer()}]) ::
          [String.t()]
  def suggest_reviewers(%FileGraph{nodes: nodes}, target_file, blast_radius) do
    # Collect all authors from affected files
    all_authors =
      Enum.reduce(blast_radius, [], fn {file, _impact, _distance}, acc ->
        case Map.get(nodes, file) do
          %{authors: authors} when is_list(authors) ->
            acc ++ authors

          _ ->
            acc
        end
      end)

    # Get authors of the target file with higher priority
    target_authors =
      case Map.get(nodes, target_file) do
        %{authors: authors} when is_list(authors) -> authors
        _ -> []
      end

    # Prioritize target authors, then other authors, remove duplicates
    (target_authors ++ all_authors)
    |> Enum.uniq()
    # Limit to top 3 reviewers
    |> Enum.take(3)
  end

  # Helper to format affected files for the ChangeImpact object
  @spec format_affected_files(FileGraph.t(), [{String.t(), float(), non_neg_integer()}]) :: [
          map()
        ]
  defp format_affected_files(%FileGraph{nodes: nodes}, blast_radius) do
    blast_radius
    |> Enum.map(fn {file, impact, distance} ->
      # Get component from node metadata
      component =
        case Map.get(nodes, file) do
          nil -> nil
          metadata -> Map.get(metadata, :component)
        end

      # Create the affected file entry
      %{
        file: file,
        impact: impact,
        distance: distance,
        component: component
      }
    end)
    |> Enum.sort_by(fn %{impact: impact} -> impact end, :desc)
  end
end
