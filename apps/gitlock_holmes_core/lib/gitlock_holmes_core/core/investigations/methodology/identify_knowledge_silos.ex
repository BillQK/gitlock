defmodule GitlockHolmesCore.Core.Investigations.Methodology.IdentifyKnowledgeSilos do
  @moduledoc """
  Investigation that identifies knowledge silos in the codebase.

  A knowledge silo occurs when a single developer has significantly more experience
  with specific files than other team members, creating risk if that developer
  becomes unavailable.
  """

  use GitlockHolmesCore.Core.Investigations.Investigation, complexity: false

  alias GitlockHolmesCore.Domain.Services.KnowledgeSiloDetection

  @impl true
  def analyze(commits, _complexity_map) do
    KnowledgeSiloDetection.detect_knowledge_silos(commits)
  end
end
