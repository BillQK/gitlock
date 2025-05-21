defmodule GitlockHolmesCore.Core.Investigations.Methodology.IdentifyHotspots do
  @moduledoc """
  Use case for identifying hotspots in the codebase.
  """
  alias GitlockHolmesCore.Domain.Services.HotspotDetection
  use GitlockHolmesCore.Core.Investigations.Investigation, complexity: true

  def analyze(commits, complexity_map, _options) do
    HotspotDetection.detect_hotspots(commits, complexity_map)
  end
end
