defmodule GitlockHolmes.Investigations.Investigation do
  @moduledoc """
  A behavior that defines the contract for investigation implementations.
  This allows different investigation strategies to share a common interface.
  """

  @typedoc "Module implementing the VersionControlPort behavior"
  @type vcs_port :: module()

  @typedoc "Module implementing the ReportPort behavior"
  @type reporter_port :: module()

  @typedoc "Options for the investigation"
  @type investigation_options :: map()

  @typedoc "Result of the investigation"
  @type investigation_result :: {:ok, String.t()} | {:error, String.t()}

  @doc """
  Execute the investigation.

  ## Parameters
    - log_file: Path to VCS log file
    - vcs_port: Module implementing VersionControlPort
    - reporter_port: Module implementing ReportPort
    - options: Additional options for analysis

  Returns the investigation results.
  """
  @callback investigate(
              log_file :: String.t(),
              vcs_port :: vcs_port(),
              reporter_port :: reporter_port(),
              options :: investigation_options()
            ) :: investigation_result()
end
