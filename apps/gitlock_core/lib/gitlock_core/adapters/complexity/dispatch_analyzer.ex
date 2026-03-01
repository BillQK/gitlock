defmodule GitlockCore.Adapters.Complexity.DispatchAnalyzer do
  @moduledoc """
  A dispatch analyzer that delegates to specific language analyzers based on file extensions.

  This analyzer implements the ComplexityAnalyzerPort behavior but internally routes
  analysis requests to the appropriate language-specific analyzer based on file extension.
  This allows for multi-language projects to be analyzed correctly without changing the
  coordinator's interface.
  """

  use GitlockCore.Adapters.Complexity.BaseAnalyzer, delegating: true

  alias GitlockCore.Domain.Values.ComplexityMetrics

  alias GitlockCore.Adapters.Complexity.Lang.{
    ElixirAnalyzer,
    JavaScriptAnalyzer,
    TypeScriptAnalyzer,
    PythonAnalyzer,
    MockAnalyzer
  }

  @available_analyzers [
    ElixirAnalyzer,
    JavaScriptAnalyzer,
    TypeScriptAnalyzer,
    PythonAnalyzer,
    MockAnalyzer
  ]

  # Real analyzers (excludes MockAnalyzer which is a fallback)
  @real_analyzers [
    ElixirAnalyzer,
    JavaScriptAnalyzer,
    TypeScriptAnalyzer,
    PythonAnalyzer
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

  @doc """
  Analyze complexity from file content directly, without reading from disk.

  Used for historical analysis where file content comes from `git show`.
  """
  @impl true
  def analyze_content(content, file_path) do
    extension = Path.extname(file_path)

    case find_real_analyzer(extension) do
      nil -> {:error, :unsupported_language}
      analyzer -> analyzer.analyze_content(content, file_path)
    end
  end

  defp select_analyzer(extension) do
    @available_analyzers
    |> Enum.find(MockAnalyzer, fn analyzer ->
      extension in analyzer.supported_extensions()
    end)
  end

  defp find_real_analyzer(extension) do
    Enum.find(@real_analyzers, fn analyzer ->
      extension in analyzer.supported_extensions()
    end)
  end
end
