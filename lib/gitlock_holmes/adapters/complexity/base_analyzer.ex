defmodule GitlockHolmes.Adapters.Complexity.BaseAnalyzer do
  @moduledoc """
  Base adapter for complexity analyzers.

  This module provides shared functionality for complexity analyzers through
  a macro that can be used by concrete implementations.

  It supports analyzing a single file or a directory of files by delegating to
  `analyze_file/1`.
  """

  @doc """
  When used, provides default implementations for the `ComplexityAnalyzerPort` behavior.

  ## Examples

      defmodule MyAnalyzer do
        use GitlockHolmes.Adapters.Complexity.BaseAnalyzer
        
        def supported_extensions, do: [".ex", ".exs"]
        
        defp calculate_complexity(content, _file_path) do
          # Implement language-specific complexity calculation
          1
        end
      end
  """
  @spec __using__(any()) :: Macro.t()
  defmacro __using__(_) do
    quote do
      @behaviour GitlockHolmes.Ports.ComplexityAnalyzerPort

      @doc """
      Analyzes the complexity of a file.

      ## Parameters
        * `file_path` - Path to the file to analyze

      ## Returns
        A map with the following keys:
          * `:file_path`
          * `:loc`
          * `:cyclomatic_complexity`
          * `:language`
          * `:error` (optional)
      """
      @impl true
      @spec analyze_file(file_path :: String.t()) :: %{
              file_path: String.t(),
              loc: non_neg_integer(),
              cyclomatic_complexity: non_neg_integer(),
              language: atom(),
              error: String.t() | nil
            }
      def analyze_file(file_path) do
        case File.read(file_path) do
          {:ok, content} ->
            %{
              file_path: file_path,
              loc: count_lines(content),
              cyclomatic_complexity: calculate_complexity(content, file_path),
              language: detect_language(file_path),
              error: nil
            }

          {:error, reason} ->
            %{
              file_path: file_path,
              loc: 1,
              cyclomatic_complexity: 0,
              language: :unknown,
              error: "Could not read file: #{reason}"
            }
        end
      end

      @impl true
      @spec analyze_directory(directory :: String.t(), opts :: map()) ::
              %{String.t() => map()} | {:error, String.t()}
      def analyze_directory(directory, opts \\ %{}) do
        case File.dir?(directory) do
          true ->
            files = collect_all_files(directory)

            files
            |> Task.async_stream(
              fn file ->
                relative_path = Path.relative_to(file, directory)
                result = analyze_file(file)
                {relative_path, result}
              end,
              max_concurrency: Map.get(opts, :concurrency, System.schedulers_online())
            )
            |> Enum.map(fn {:ok, result} -> result end)
            |> Enum.into(%{})

          false ->
            {:error, "Invalid or inaccessible directory: #{directory}"}
        end
      end

      defp collect_all_files(dir) do
        Path.wildcard(Path.join([dir, "**", "*"]))
        |> Enum.filter(&File.regular?/1)
      end

      @spec count_lines(content :: String.t()) :: non_neg_integer()
      defp count_lines(content) do
        content |> String.split("\n") |> length()
      end

      @spec detect_language(file_path :: String.t()) :: atom()
      defp detect_language(file_path) do
        ext = Path.extname(file_path)

        cond do
          ext in [".ex", ".exs"] -> :elixir
          ext in [".js", ".jsx"] -> :javascript
          ext in [".rb"] -> :ruby
          ext in [".py"] -> :python
          ext in [".java"] -> :java
          true -> :unknown
        end
      end

      @doc """
      Calculates the cyclomatic complexity of code content.

      This function **must** be implemented by any module using this base.

      ## Parameters
        * `content` - The code content to analyze
        * `file_path` - Path to the file (for context)

      ## Returns
        The calculated cyclomatic complexity as an integer
      """
      @spec calculate_complexity(content :: String.t(), file_path :: String.t()) ::
              non_neg_integer()

      defoverridable analyze_file: 1
      defoverridable analyze_directory: 2
    end
  end
end

