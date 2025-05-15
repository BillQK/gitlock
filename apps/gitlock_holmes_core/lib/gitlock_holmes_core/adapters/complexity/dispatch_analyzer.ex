defmodule GitlockHolmesCore.Adapters.Complexity.DispatchAnalyzer do
  @moduledoc """
  A dispatch  analyzer that delegates to specific language analyzers based on file extensions.

  This analyzer implements the ComplexityAnalyzerPort behavior but internally routes
  analysis requests to the appropriate language-specific analyzer based on file extension.
  This allows for multi-language projects to be analyzed correctly without changing the
  coordinator's interface.
  """

  use GitlockHolmesCore.Adapters.Complexity.BaseAnalyzer, delegating: true

  alias GitlockHolmesCore.Domain.Values.ComplexityMetrics

  alias GitlockHolmesCore.Adapters.Complexity.Lang.{
    ElixirAnalyzer,
    JavaScriptAnalyzer,
    MockAnalyzer
  }

  # Define all available analyzers
  @available_analyzers [
    ElixirAnalyzer,
    JavaScriptAnalyzer,
    MockAnalyzer
  ]

  @impl true
  def supported_extensions() do
    @available_analyzers
    |> Enum.flat_map(& &1.supported_extensions())
    |> Enum.uniq()
  end

  @impl true
  def analyze_file(file_path) do
    extension = Path.extname(file_path)
    analyzer = select_analyzer(extension)

    analyzer.analyze_file(file_path)
  end

  defp select_analyzer(extension) do
    @available_analyzers
    |> Enum.find(MockAnalyzer, fn analyzer ->
      extension in analyzer.supported_extensions()
    end)
  end
end
