defmodule GitlockHolmes.Core.Investigations.Methodology.IdentifyCouplings do
  @moduledoc """
  Use case for identifying couplings in the codebase
  """

  use GitlockHolmes.Core.Investigations.Investigation, complexity: false
  alias GitlockHolmes.Domain.Services.CouplingDetection

  @impl true
  def analyze(commits, _complexity_map) do
    CouplingDetection.detect_couplings(commits)
  end
end
