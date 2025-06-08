defmodule GitlockCLI.HelpDisplay do
  @moduledoc """
  Handles display of help information and version details for the Gitlock CLI.

  Provides comprehensive help for general usage and specific investigations.
  """

  @doc """
  Displays general help information or help for a specific investigation.
  """
  def display_help([]) do
    IO.puts(general_help())
  end

  def display_help([investigation | _]) do
    case investigation do
      "hotspots" ->
        IO.puts(hotspots_help())

      "knowledge_silos" ->
        IO.puts(knowledge_silos_help())

      "couplings" ->
        IO.puts(couplings_help())

      "coupled_hotspots" ->
        IO.puts(coupled_hotspots_help())

      "blast_radius" ->
        IO.puts(blast_radius_help())

      "summary" ->
        IO.puts(summary_help())

      _ ->
        IO.puts("No help available for unknown investigation: #{investigation}")
        display_help([])
    end
  end

  @doc """
  Displays the current version of Gitlock.
  """
  def display_version(version) do
    IO.puts("Gitlock v#{version}")
  end

  # General help content
  defp general_help do
    """
    Gitlock - Forensic Code Analysis Tool

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
      --url,  -u URL      URL to remote Git repository
      --log,  -l PATH     Path to log file (deprecated, use --repo instead)
      --vcs      TYPE     Version control system type (git, svn, github)

    Common Options:
      --format, -f FORMAT      Output format: csv, json, stdout (default: csv)
      --output, -o FILE        Write output to file (default: timestamped file)
      --limit      NUMBER      Limit number of results (default: 20)
      --dir     -d PATH        Directory for complexity analysis
      --help,   -h             Show this help
      --version -v             Show version

    Legacy Options (backward compatibility):
      --investigation  -i TYPE    Investigation type (alternative to positional argument)
      --rows NUMBER               Limit number of results (equivalent to --limit)
      --time-period    -t PERIOD  Time period for temporal analysis
      
    Blast Radius Options:
      --target-files     FILE    Target files (can be used multiple times or comma-separated)
      --blast-threshold  VAL     Minimum coupling threshold (default: 0.3)
      --max-radius       NUM     Maximum blast radius depth (default: 2)

    Examples:
      gitlock hotspots        --repo ./my_project --dir ./my_project
      gitlock knowledge-silos --repo ./git_log.txt
      gitlock blast-radius    --repo ./my_project --target-files lib/core.ex --dir ./my_project
      
      # Legacy style
      gitlock --investigation hotspots --log ./git_log.txt --vcs git

    Use 'gitlock --help [investigation]' for information about a specific investigation.
    """
  end

  # Hotspots help content
  defp hotspots_help do
    """
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
    """
  end

  # Knowledge silos help content
  defp knowledge_silos_help do
    """
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
    """
  end

  # Couplings help content
  defp couplings_help do
    """
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
    """
  end

  # Coupled hotspots help content
  defp coupled_hotspots_help do
    """
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
    """
  end

  # Blast radius help content
  defp blast_radius_help do
    """
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
    """
  end

  # Summary help content
  defp summary_help do
    """
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
    """
  end
end
