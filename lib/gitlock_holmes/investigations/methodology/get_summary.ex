defmodule GitlockHolmes.Investigations.Methodology.GetSummary do
  @moduledoc """
  Investigation that summarizes commit history of a codebase.
  """

  @behaviour GitlockHolmes.Investigations.Investigation

  alias GitlockHolmes.Domain.Services.Summary

  @impl true
  def investigate(log_file, vcs_port, reporter_port, _complexity_analyzer_port, options \\ %{}) do
    with {:ok, commits} <- vcs_port.get_commit_history(log_file, options),
         summary <- Summary.summarize(commits),
         {:ok, report} <- reporter_port.report(summary, options) do
      {:ok, report}
    else
      {:error, reason} -> {:error, "Failed to summarize history: #{reason}"}
      _ -> {:error, "Unknown error during summary investigation"}
    end
  end
end
