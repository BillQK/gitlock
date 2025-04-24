defmodule GitlockHolmes.Domain.Services.ComplexityCollector do
  @moduledoc """
  Service that collects and normalizes complexity metrics using a given analyzer.
  """

  alias GitlockHolmes.Domain.Entities.ComplexityMetrics

  @typedoc "Module implementing the ComplexityAnalyzerPort behavior"
  @type analyzer_port :: module()

  @spec collect_complexity(analyzer_port(), String.t()) ::
          %{String.t() => ComplexityMetrics.t()}
  def collect_complexity(analyzer, dir) do
    case analyzer.analyze_directory(dir) do
      {:ok, results} -> results
      # fall back to empty if there's an error
      {:error, _} -> %{}
    end
  end
end
