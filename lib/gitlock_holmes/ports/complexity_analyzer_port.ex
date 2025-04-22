defmodule GitlockHolmes.Ports.ComplexityAnalyzerPort do
  @moduledoc """
  Port for complexity analysis operations.
  """

  @callback analyze_file(String.t()) :: map()
  @callback analyze_directory(directory :: String.t(), opts :: map()) ::
              %{String.t() => map()} | {:error, String.t()}
  @callback supported_extensions() :: list(String.t())
end
