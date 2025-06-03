defmodule GitlockCore.Ports.ComplexityAnalyzerPort do
  @moduledoc """
  Port for complexity analysis operations.
  """

  alias GitlockCore.Domain.Values.ComplexityMetrics

  @typedoc "Success tuple wrapping a ComplexityMetrics struct"
  @type ok_metric :: {:ok, ComplexityMetrics.t()}

  @typedoc "Error tuple for I/O or analysis failures"
  @type error_reason :: {:error, {:io, String.t(), term()}} | {:error, String.t()}

  @doc """
  Analyze a single file.

  ## Returns
    * `{:ok, %ComplexityMetrics{}}` on success
    * `{:error, {:io, file_path, reason}}` if the file can’t be read
  """
  @callback analyze_file(file_path :: String.t()) :: ok_metric() | error_reason()

  @doc """
  Analyze all supported files in a directory (recursively).

  ## Returns
    * `{:ok, %{relative_path => %ComplexityMetrics{}}}` on success
    * `{:error, reason}` if the directory is invalid or inaccessible
  """
  @callback analyze_directory(
              directory :: String.t(),
              opts :: map()
            ) :: {:ok, %{String.t() => ComplexityMetrics.t()}} | {:error, String.t()}

  @doc "List of file extensions this analyzer will process (e.g. [\".ex\", \".exs\"])."
  @callback supported_extensions() :: [String.t()]
end
