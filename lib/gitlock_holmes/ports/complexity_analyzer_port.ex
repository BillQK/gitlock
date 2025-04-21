defmodule GitlockHolmes.Ports.ComplexityAnalyzerPort do
  @moduledoc """
  Port for complexity analysis operations.
  """

  @callback analyze_file(String.t()) :: map()
  @callback supported_extensions() :: list(String.t())
end
