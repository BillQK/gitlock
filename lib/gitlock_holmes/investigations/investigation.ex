defmodule GitlockHolmes.Investigations.Investigation do
  @moduledoc """
  A behavior that defines the contract for investigation implementations.
  This allows different investigation strategies to share a common interface.
  """

  @typedoc "Module implementing the VersionControlPort behavior"
  @type vcs_port :: module()

  @typedoc "Module implementing the ReportPort behavior"
  @type reporter_port :: module()

  @typedoc "Module implementing the ComplexityAnalyzerPort behavior"
  @type complexity_analyzer_port :: module()

  @typedoc "Options for the investigation"
  @type investigation_options :: %{
          optional(:rows) => non_neg_integer(),
          optional(:repo_path) => String.t(),
          optional(:complexity_enabled) => boolean()
        }

  @typedoc "Result of the investigation"
  @type investigation_result :: {:ok, String.t()} | {:error, String.t()}

  @doc """
  Execute the investigation.

  ## Parameters
    - log_file: Path to VCS log file
    - vcs_port: Module implementing VersionControlPort
    - reporter_port: Module implementing ReportPort
    - complexity_analyzer_port: Module implementing ComplexityAnalyzerPort (or nil to disable)
    - options: Additional options for analysis
      - rows: Maximum number of results to include in output
      - repo_path: Path to repository (defaults to log_file directory)
      - complexity_enabled: Whether to include complexity metrics (defaults to true if analyzer provided)
      
  Returns the investigation results.
  """
  @callback investigate(
              log_file :: String.t(),
              vcs_port :: vcs_port(),
              reporter_port :: reporter_port(),
              complexity_analyzer_port :: complexity_analyzer_port() | nil,
              options :: investigation_options()
            ) :: investigation_result()
end
