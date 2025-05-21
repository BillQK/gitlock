defmodule GitlockHolmesCore.Core.Investigations.Methodology.IdentifyCouplings do
  @moduledoc """
  Use case for identifying couplings in the codebase
  """

  use GitlockHolmesCore.Core.Investigations.Investigation, complexity: false
  alias GitlockHolmesCore.Domain.Services.CouplingDetection

  def analyze(commits, _complexity_map, _options) do
    CouplingDetection.detect_couplings(commits)
  end
end
