defmodule GitlockHolmesCore.Core.Investigations.Methodology.GetSummary do
  @moduledoc """
  Investigation that summarizes commit history of a codebase.
  """

  use GitlockHolmesCore.Core.Investigations.Investigation, complexity: false
  alias GitlockHolmesCore.Domain.Services.Summary

  @impl true
  def analyze(commits, _complexity_map) do
    Summary.summarize(commits)
  end
end
