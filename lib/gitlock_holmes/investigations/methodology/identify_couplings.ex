defmodule GitlockHolmes.Investigations.Methodology.IdentifyCouplings do
  @moduledoc """
  Use case for identifying couplings in the codebase
  """

  alias GitlockHolmes.Domain.Services.CouplingDetection

  @behaviour GitlockHolmes.Investigations.Investigation

  @impl true
  def investigate(log_file, vcs_port, reporter_port, _analyzer, options \\ %{}) do
    with {:ok, commits} <- vcs_port.get_commit_history(log_file, options),
         results = CouplingDetection.detect_couplings(commits),
         {:ok, formatted_output} <- reporter_port.report(results, options) do
      {:ok, formatted_output}
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
