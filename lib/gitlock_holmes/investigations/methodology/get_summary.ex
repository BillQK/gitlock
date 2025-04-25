defmodule GitlockHolmes.Investigations.Methodology.GetSummary do
  @moduledoc """
  Investigation that summarizes commit history of a codebase.
  """

  use GitlockHolmes.Investigations.Investigation, complexity: false
  alias GitlockHolmes.Domain.Services.Summary

  @impl true
  def analyze(commits, _complexity_map) do
    Summary.summarize(commits)
  end
end
