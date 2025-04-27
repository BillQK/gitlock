defmodule GitlockHolmes.Core.Investigations.Methodology.IdentifyCoupledHotspots do
  @moduledoc "Use case for identifying coupled hotspots."

  use GitlockHolmes.Core.Investigations.Investigation, complexity: true

  alias GitlockHolmes.Domain.Services.CoupledHotspotAnalysis

  @impl true
  def analyze(commits, complexity_map) do
    CoupledHotspotAnalysis.detect_combined(commits, complexity_map)
  end
end
