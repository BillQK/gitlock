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
    case analyzer.analyze_directory(dir, %{}) do
      # Return empty map on error
      {:error, _reason} -> %{}
      result when is_map(result) -> result
      # Handle any unexpected return type
      _ -> %{}
    end
  end
end
