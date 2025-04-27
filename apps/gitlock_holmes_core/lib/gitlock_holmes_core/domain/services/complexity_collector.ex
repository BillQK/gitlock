defmodule GitlockHolmesCore.Domain.Services.ComplexityCollector do
  @moduledoc """
  Service that collects and normalizes complexity metrics using a given analyzer.
  """

  alias GitlockHolmesCore.Domain.Values.ComplexityMetrics

  @typedoc "Module implementing the ComplexityAnalyzerPort behavior"
  @type analyzer_port :: module()

  @spec collect_complexity(analyzer_port(), String.t()) ::
          %{String.t() => ComplexityMetrics.t()}
  def collect_complexity(analyzer, dir) do
    analyzer.analyze_directory(dir)
  end
end
