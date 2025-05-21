defmodule GitlockHolmesCore.Core.Investigations.Methodology.IdentifyCoupledHotspots do
  @moduledoc "Use case for identifying coupled hotspots."

  use GitlockHolmesCore.Core.Investigations.Investigation, complexity: true

  alias GitlockHolmesCore.Domain.Services.CoupledHotspotAnalysis

  @impl true
  def analyze(commits, complexity_map, _options) do
    CoupledHotspotAnalysis.detect_combined(commits, complexity_map)
  end
end
