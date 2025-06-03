defmodule GitlockCLI.Main do
  @moduledoc """
  Command-line interface for Gitlock code forensics tool.

  This module provides a user-friendly interface to the forensic code analysis 
  capabilities of Gitlock, allowing developers to analyze their codebase
  for hotspots, knowledge silos, and other code health indicators.
  """

  @version "0.1.0"

  @doc """
  Entry point for the CLI application.

  Parses command-line arguments and dispatches to the appropriate use case.
  """
  def main(args) do
    {parsed, remaining, invalid} = parse_args(args)

    cond do
      parsed[:help] || parsed[:h] ->
        display_help(remaining)

      parsed[:version] || parsed[:v] ->
        display_version()

      Enum.any?(invalid) ->
        display_invalid_options(invalid)

      true ->
        # Support both the legacy style (--investigation) and new style (positional arg)
        run_investigation(parsed, remaining)
    end
  end

  # Parses command-line arguments with support for all option formats.
  # Handles both legacy and new option styles.
  defp parse_args(args) do
    {parsed, remaining, invalid} =
      OptionParser.parse(args,
        strict: [
          # Common options
          help: :boolean,
          h: :boolean,
          version: :boolean,
          v: :boolean,

          # Repository source options
          repo: :string,
          r: :string,
          log: :string,
          l: :string,
          url: :string,
          u: :string,
          vcs: :string,

          # Investigation options
          investigation: :string,
          i: :string,

          # Output options
          format: :string,
          f: :string,
          output: :string,
          o: :string,
          limit: :integer,
          rows: :integer,

          # Analysis options
          dir: :string,
          d: :string,
          arch_group: :string,
          a: :string,
          time_period: :integer,
          t: :integer,
          team_map: :string,
          min_revs: :integer,
          min_coupling: :float,
          min_windows: :integer,

          # Blast radius options
          target_files: :keep,
          tf: :keep,
          blast_threshold: :float,
          bt: :float,
          max_radius: :integer,
          mr: :integer
        ],
        aliases: [
          h: :help,
          v: :version,
          r: :repo,
          l: :log,
          u: :url,
          i: :investigation,
          f: :format,
          o: :output,
          d: :dir,
          a: :arch_group,
          t: :time_period,
          tf: :target_files,
          bt: :blast_threshold,
          mr: :max_radius
        ]
      )

    {parsed, remaining, invalid}
  end

  # Runs a specific investigation based on the command-line arguments.
  # Supports both legacy style (--investigation) and new style (positional arg).
  defp run_investigation(options, remaining_args) do
    start_time = :os.timestamp()

    # Determine investigation type (from positional arg or --investigation flag)
    investigation_type =
      cond do
        # New style: First positional argument is the investigation type
        Enum.any?(remaining_args) ->
          normalize_investigation_type(List.first(remaining_args))

        # Legacy style: --investigation flag
        options[:investigation] || options[:i] ->
          normalize_investigation_type(options[:investigation] || options[:i])

        # No investigation specified
        true ->
          nil
      end

    # Prepare arguments and run investigation if type is specified
    if investigation_type do
      # Get remaining args (excluding investigation name if it was positional)
      args = if Enum.any?(remaining_args), do: Enum.drop(remaining_args, 1), else: []

      if investigation_type in GitlockCore.available_investigations() do
        options_map = prepare_options(options, args)

        # Determine repo path and source type
        {repo_source, source_type} = determine_repo_source(options_map)

        # Add source_type to options for the Git adapter
        options_map = Map.put(options_map, :source_type, source_type)

        # Log the investigation being run
        IO.puts("Running #{investigation_type} analysis on #{repo_source}...")

        # Run the investigation
        case GitlockCore.investigate(investigation_type, repo_source, options_map) do
          {:ok, result} ->
            handle_success(result, options_map, investigation_type)

          {:error, reason} ->
            handle_error(reason)
        end

        # Report execution time
        end_time = :os.timestamp()
        execution_time = :timer.now_diff(end_time, start_time) / 1_000_000
        IO.puts("Execution Time: #{Float.round(execution_time, 3)}s")
      else
        display_unknown_investigation(to_string(investigation_type))
      end
    else
      IO.puts("Error: No investigation specified.")
      IO.puts("Specify an investigation with --investigation TYPE or as the first argument.")
      display_help([])
      System.halt(1)
    end
  end

  # Converts investigation names to the canonical atom form.
  # Supports both underscore and dash formats.
  defp normalize_investigation_type(name) when is_binary(name) do
    case name do
      "hotspots" ->
        :hotspots

      "knowledge_silos" ->
        :knowledge_silos

      "knowledge-silos" ->
        :knowledge_silos

      "couplings" ->
        :couplings

      "coupled_hotspots" ->
        :coupled_hotspots

      "coupled-hotspots" ->
        :coupled_hotspots

      "blast_radius" ->
        :blast_radius

      "blast-radius" ->
        :blast_radius

      "summary" ->
        :summary

      "code_health" ->
        :code_health

      "code-health" ->
        :code_health

      "team_communication" ->
        :team_communication

      "team-communication" ->
        :team_communication

      _ ->
        # Convert dash-separated to underscore for atom
        name
        |> String.replace("-", "_")
        |> String.to_atom()
    end
  end

  defp normalize_investigation_type(name) when is_atom(name) do
    normalize_investigation_type(Atom.to_string(name))
  end

  # Determines the repository source and type with priority order:
  # 1. --repo (primary option)
  # 2. --url (for remote repositories)
  # 3. --log (legacy option)
  # 4. Current directory (default)
  #
  # Returns a tuple of {source_path, source_type}
  defp determine_repo_source(options) do
    # Priority order: repo > url > log > default
    cond do
      # Primary option
      options[:repo] ->
        {options[:repo], determine_source_type(options[:repo])}

      # Remote URL option
      options[:url] ->
        {options[:url], :url}

      # Legacy option (with deprecation warning)
      options[:log] ->
        IO.puts(:stderr, "Warning: The --log option is deprecated. Please use --repo instead.")
        {options[:log], :log_file}

      # Default to current directory
      true ->
        {".", :local_repo}
    end
  end

  # Determines the type of a repository source.
  defp determine_source_type(source) do
    cond do
      # Remote repository URL
      String.match?(source, ~r/^(https?:\/\/|git@)/) ->
        :url

      # Local Git repository
      File.dir?(source) &&
          (File.dir?(Path.join(source, ".git")) ||
             File.exists?(Path.join(source, ".git"))) ->
        :local_repo

      # Existing file - assume it's a log file
      File.regular?(source) ->
        :log_file

      # For non-existent paths, default to log_file for backward compatibility
      true ->
        :log_file
    end
  end

  # Prepares options for the investigation, handling special cases and normalizing.
  defp prepare_options(options, _args) do
    # Process target_files from both --target-files and --tf options
    # Legacy: Handle comma-separated target files from the existing design
    target_files =
      extract_target_files(options) ||
        if options[:target_files] || options[:tf] do
          value = options[:target_files] || options[:tf]

          value
          |> String.split(",")
          |> Enum.map(&String.trim/1)
          |> Enum.filter(&(String.length(&1) > 0))
        else
          nil
        end

    # Convert options keyword list to map, handling aliases
    base_options =
      options
      |> Enum.reduce(%{}, fn
        {:target_files, _}, acc -> acc
        {:tf, _}, acc -> acc
        {key, value}, acc -> Map.put(acc, key, value)
      end)
      |> normalize_option_keys()

    # Add target_files if present
    if target_files && length(target_files) > 0 do
      Map.put(base_options, :target_files, target_files)
    else
      base_options
    end
  end

  # Extracts target_files options, which can be specified multiple times.
  defp extract_target_files(options) do
    target_files_entries =
      options
      |> Enum.filter(fn {key, _} -> key == :target_files or key == :tf end)

    if Enum.empty?(target_files_entries) do
      nil
    else
      Enum.map(target_files_entries, fn {_, value} -> value end)
    end
  end

  # Normalizes option keys, converting both legacy and new option names to their canonical form.
  defp normalize_option_keys(options) do
    options
    |> Enum.map(fn
      # Legacy options to canonical form
      {key, value} when key in [:l, :log] -> {:log, value}
      {key, value} when key in [:rows] -> {:rows, value}
      {key, value} when key in [:f, :format] -> {:format, value}
      {key, value} when key in [:a, :arch_group] -> {:group, value}
      {key, value} when key in [:t, :time_period] -> {:temporal_period, value}
      # New options to canonical form
      {key, value} when key in [:r, :repo] -> {:repo, value}
      {key, value} when key in [:u, :url] -> {:url, value}
      {key, value} when key in [:o, :output] -> {:output, value}
      {key, value} when key in [:limit] -> {:rows, value}
      {key, value} when key in [:d, :dir] -> {:dir, value}
      {key, value} when key in [:bt, :blast_threshold] -> {:blast_threshold, value}
      {key, value} when key in [:mr, :max_radius] -> {:max_radius, value}
      # Preserve other options
      {key, value} -> {key, value}
    end)
    |> Map.new()
  end

  # Handles successful execution of an investigation, with support for both output styles.
  defp handle_success(result, options, investigation_type) do
    cond do
      # Write to specified output file
      options[:output] ->
        output_file = options[:output]
        File.write!(output_file, result)
        IO.puts("Results written to #{output_file}")

      # Format is explicitly set to stdout
      options[:format] == "stdout" ->
        IO.puts(result)

      # Legacy style: Write to timestamped file in output directory
      true ->
        format = options[:format] || "csv"
        format = if format == "stdout", do: "txt", else: format
        filename = "output/#{investigation_type}-#{timestamp()}.#{format}"

        File.mkdir_p!(Path.dirname(filename))
        File.write!(filename, result)
        IO.puts("Results written to #{filename}")
    end

    :ok
  end

  # Generates a timestamp for filenames.
  defp timestamp do
    DateTime.utc_now()
    |> Calendar.strftime("%Y%m%d-%H%M%S")
  end

  # Handles various error cases with user-friendly messages.
  defp handle_error({:io, path, :enoent}) do
    IO.puts(:stderr, "Error: File not found: #{path}")
    IO.puts(:stderr, "Please verify the path and try again.")
    System.halt(1)
  end

  defp handle_error({:io, path, reason}) do
    IO.puts(:stderr, "Error reading file #{path}: #{inspect(reason)}")
    IO.puts(:stderr, "Please check file permissions and try again.")
    System.halt(1)
  end

  defp handle_error({:git, reason}) do
    IO.puts(:stderr, "Git error: #{reason}")
    IO.puts(:stderr, "Please ensure Git is installed and the repository is valid.")
    System.halt(1)
  end

  defp handle_error({:parse, reason}) do
    IO.puts(:stderr, "Error parsing input: #{reason}")
    IO.puts(:stderr, "Please check your input format and try again.")
    System.halt(1)
  end

  defp handle_error({:analysis, reason}) do
    IO.puts(:stderr, "Error during analysis: #{reason}")
    IO.puts(:stderr, "Try adjusting analysis parameters and try again.")
    System.halt(1)
  end

  defp handle_error({:commit, reason}) do
    IO.puts(:stderr, "Error processing commit: #{reason}")
    IO.puts(:stderr, "The log file may be malformed or corrupt.")
    System.halt(1)
  end

  defp handle_error(reason) when is_binary(reason) do
    IO.puts(:stderr, "Error: #{reason}")
    System.halt(1)
  end

  defp handle_error(reason) do
    IO.puts(:stderr, "Error: #{inspect(reason)}")
    System.halt(1)
  end

  # Displays general help information or help for a specific investigation.
  defp display_help([]) do
    IO.puts("""
    Gitlock v#{@version} - Forensic Code Analysis Tool

    Usage: 
      gitlock [investigation] [options]
      gitlock --investigation TYPE [options]  (Legacy style)

    Available Investigations:
      hotspots           - Find frequently changed complex files
      knowledge-silos    - Find files owned primarily by one developer
      couplings          - Discover files that change together
      coupled-hotspots   - Identify risky coupled files 
      blast-radius       - Assess impact of changing specific files
      summary            - General repository statistics
      team-communication - Map team communication patterns
      code-health        - Overall code health assessment

    Repository Source Options:
      --repo, -r PATH     Path to repository or log file (recommended)
      --url, -u URL       URL to remote Git repository
      --log, -l PATH      Path to log file (deprecated, use --repo instead)
      --vcs TYPE          Version control system type (git, svn, github)

    Common Options:
      --format, -f FORMAT Output format: csv, json, stdout (default: csv)
      --output, -o FILE   Write output to file (default: timestamped file)
      --limit NUMBER      Limit number of results (default: 20)
      --dir, -d PATH      Directory for complexity analysis
      --help, -h          Show this help
      --version, -v       Show version

    Legacy Options (backward compatibility):
      --investigation, -i TYPE  Investigation type (alternative to positional argument)
      --rows NUMBER       Limit number of results (equivalent to --limit)
      --arch-group, -a PATH  Architecture grouping file (equivalent to --group)
      --time-period, -t PERIOD  Time period for temporal analysis
      
    Blast Radius Options:
      --target-files FILE  Target files (can be used multiple times or comma-separated)
      --blast-threshold VAL  Minimum coupling threshold (default: 0.3)
      --max-radius NUM    Maximum blast radius depth (default: 2)

    Examples:
      gitlock hotspots --repo ./my_project --dir ./my_project
      gitlock knowledge-silos --repo ./git_log.txt
      gitlock blast-radius --repo ./my_project --target-files lib/core.ex --dir ./my_project
      
      # Legacy style
      gitlock --investigation hotspots --log ./git_log.txt --vcs git

    Use 'gitlock --help [investigation]' for information about a specific investigation.
    """)
  end

  defp display_help([investigation | _]) do
    case investigation do
      "hotspots" ->
        IO.puts("""
        Gitlock - Hotspot Analysis

        Identifies frequently changed files with high complexity, which are 
        likely to be bug-prone or cause maintenance issues.

        Usage: 
          gitlock hotspots [options]

        Options:
          --repo, -r PATH     Repository or log file path (default: .)
          --url, -u URL       URL to remote repository
          --format, -f FORMAT Output format: csv, json, stdout (default: csv)
          --output, -o FILE   Write output to file (default: timestamped file)
          --limit NUMBER      Limit number of results (default: 20)
          --dir, -d PATH      Directory for complexity analysis (required)

        Legacy Options:
          --log, -l PATH      Git log file path (equivalent to --repo)
          --vcs TYPE          Version control system type
          --rows NUMBER       Limit number of results (equivalent to --limit)

        Example:
          gitlock hotspots --repo ./my_project --dir ./my_project
          
        Output Columns:
          entity         - File path
          revisions      - Number of times the file changed
          complexity     - Cyclomatic complexity measure
          loc            - Lines of code
          risk_score     - Combined risk score (higher is riskier)
          risk_factor    - Risk category (high, medium, low)
        """)

      "knowledge_silos" ->
        IO.puts("""
        Gitlock - Knowledge Silo Analysis

        Identifies files that are primarily modified by a single developer,
        representing knowledge concentration and potential team risks.

        Usage: 
          gitlock knowledge-silos [options]

        Options:
          --repo, -r PATH     Repository or log file path (default: .)
          --url, -u URL       URL to remote repository
          --format, -f FORMAT Output format: csv, json, stdout (default: csv)
          --output, -o FILE   Write output to file (default: timestamped file)
          --limit NUMBER      Limit number of results (default: 20)

        Legacy Options:
          --log, -l PATH      Git log file path (equivalent to --repo)
          --vcs TYPE          Version control system type
          --rows NUMBER       Limit number of results (equivalent to --limit)
          --team-map PATH     Team mapping file (for team-level silos)

        Example:
          gitlock knowledge-silos --repo ./my_project
          
        Output Columns:
          entity           - File path
          main_author      - Developer with most changes
          ownership_ratio  - Percentage of changes by main author
          num_authors      - Total number of unique contributors
          num_commits      - Total number of commits to the file
          risk_level       - Risk assessment (high, medium, low)
        """)

      "couplings" ->
        IO.puts("""
        Gitlock - Coupling Analysis

        Identifies files that frequently change together, indicating potential
        logical dependencies that might not be obvious from the code structure.

        Usage: 
          gitlock couplings [options]

        Options:
          --repo, -r PATH       Repository or log file path (default: .)
          --url, -u URL         URL to remote repository
          --format, -f FORMAT   Output format: csv, json, stdout (default: csv)
          --output, -o FILE     Write output to file (default: timestamped file)
          --limit NUMBER        Limit number of results (default: 20)
          --min-coupling NUMBER Minimum coupling strength % (default: 30)
          --min-windows NUMBER  Minimum co-change count (default: 5)

        Legacy Options:
          --log, -l PATH        Git log file path (equivalent to --repo)
          --vcs TYPE            Version control system type
          --rows NUMBER         Limit number of results (equivalent to --limit)
          --arch-group, -a PATH Architecture grouping file
          --time-period, -t PERIOD Time period for temporal analysis

        Example:
          gitlock couplings --repo ./my_project --min-coupling 20
          
        Output Columns:
          entity    - First file in the coupling relationship
          coupled   - Second file that changes with the first
          degree    - Percentage of co-changes (higher means stronger coupling)
          windows   - Number of commits where both files changed
          trend     - Change in coupling over time (positive means increasing)
        """)

      "coupled_hotspots" ->
        IO.puts("""
        Gitlock - Coupled Hotspots Analysis

        Identifies pairs of files that are both risky (hotspots) and coupled,
        representing the highest-risk areas in your codebase.

        Usage: 
          gitlock coupled-hotspots [options]

        Options:
          --repo, -r PATH     Repository or log file path (default: .)
          --url, -u URL       URL to remote repository
          --format, -f FORMAT Output format: csv, json, stdout (default: csv)
          --output, -o FILE   Write output to file (default: timestamped file)
          --limit NUMBER      Limit number of results (default: 20)
          --dir, -d PATH      Directory for complexity analysis (required)

        Legacy Options:
          --log, -l PATH      Git log file path (equivalent to --repo)
          --vcs TYPE          Version control system type
          --rows NUMBER       Limit number of results (equivalent to --limit)

        Example:
          gitlock coupled-hotspots --repo ./my_project --dir ./my_project
          
        Output Columns:
          entity              - First file in the coupled pair
          coupled             - Second file in the coupled pair
          combined_risk_score - Multiplication of individual risk scores
          trend               - Change in coupling over time
          individual_risks    - Risk scores for each file
        """)

      "blast_radius" ->
        IO.puts("""
        Gitlock - Blast Radius Analysis

        Assesses the potential impact of changing specific files by analyzing
        their coupling relationships and architectural boundaries.

        Usage: 
          gitlock blast-radius [options]

        Options:
          --repo, -r PATH          Repository or log file path (default: .)
          --url, -u URL            URL to remote repository
          --format, -f FORMAT      Output format: csv, json, stdout (default: csv)
          --output, -o FILE        Write output to file (default: timestamped file)
          --limit NUMBER           Limit number of results (default: 20)
          --dir, -d PATH           Directory for complexity analysis (required)
          --target-files FILE      Files to analyze impact (multiple allowed, required)
          --blast-threshold NUMBER Minimum coupling to include (default: 0.3)
          --max-radius NUMBER      Maximum distance to analyze (default: 2)

        Legacy Options:
          --log, -l PATH           Git log file path (equivalent to --repo)
          --vcs TYPE               Version control system type
          --rows NUMBER            Limit number of results (equivalent to --limit)
          --tf FILE                Target file (equivalent to --target-files)
          --bt NUMBER              Blast threshold (equivalent to --blast-threshold)
          --mr NUMBER              Max radius (equivalent to --max-radius)

        Example:
          gitlock blast-radius --repo ./my_project --dir ./my_project --target-files lib/core.ex
          
        Output Columns:
          entity                  - Target file being analyzed
          risk_score              - Overall risk assessment for changing the file
          impact_severity         - Qualitative severity level (high, medium, low)
          affected_files_count    - Number of files likely to be impacted
          affected_components_count - Number of architectural components affected
          suggested_reviewers     - Developers with knowledge of the affected code
        """)

      "summary" ->
        IO.puts("""
        Gitlock - Summary Analysis

        Provides general statistics about the repository including commit counts,
        author counts, and entity counts.

        Usage: 
          gitlock summary [options]

        Options:
          --repo, -r PATH     Repository or log file path (default: .)
          --url, -u URL       URL to remote repository
          --format, -f FORMAT Output format: csv, json, stdout (default: csv)
          --output, -o FILE   Write output to file (default: timestamped file)

        Legacy Options:
          --log, -l PATH      Git log file path (equivalent to --repo)
          --vcs TYPE          Version control system type

        Example:
          gitlock summary --repo ./my_project
          
        Output Columns:
          statistic - Name of the statistic (e.g., number-of-commits)
          value     - Value of the statistic
        """)

      _ ->
        IO.puts("No help available for unknown investigation: #{investigation}")
        display_help([])
    end
  end

  # Displays the current version of Gitlock.
  defp display_version do
    IO.puts("Gitlock v#{@version}")
  end

  # Displays error message for invalid options.
  defp display_invalid_options(invalid) do
    invalid_options = Enum.map_join(invalid, ", ", fn {name, _} -> name end)
    IO.puts(:stderr, "Error: Invalid option(s): #{invalid_options}")
    IO.puts(:stderr, "Run 'gitlock --help' for usage information.")
    System.halt(1)
  end

  # Displays error message for unknown investigation type.
  defp display_unknown_investigation(name) do
    IO.puts(:stderr, "Error: Unknown investigation type: #{name}")
    IO.puts(:stderr, "Available investigations: #{available_investigations_string()}")
    IO.puts(:stderr, "Run 'gitlock --help' for usage information.")
    System.halt(1)
  end

  # Returns a comma-separated string of available investigation types.
  defp available_investigations_string do
    GitlockCore.available_investigations()
    |> Enum.map(&normalize_investigation_name/1)
    |> Enum.join(", ")
  end

  # Normalizes investigation name atoms to user-friendly strings.
  defp normalize_investigation_name(investigation) do
    investigation
    |> Atom.to_string()
    |> String.replace("_", "-")
  end
end
