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

      alias GitlockHolmes.Domain.Entities.ComplexityMetrics

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
      @spec analyze_file(String.t()) ::
              {:ok, ComplexityMetrics.t()}
              | {:error, {:io, String.t(), term()}}
      def analyze_file(file_path) do
        case File.read(file_path) do
          {:ok, content} ->
            metrics =
              ComplexityMetrics.new(
                file_path,
                count_lines(content),
                calculate_complexity(content, file_path),
                detect_language(file_path)
              )

            {:ok, metrics}

          {:error, reason} ->
            {:error, {:io, file_path, reason}}
        end
      end

      @doc """
      Recursively analyze supported files in `directory` concurrently.

      Returns a map of relative paths to `%ComplexityMetrics{}` on success,
      or `{:error, reason}` if `directory` isn’t a valid directory.

      Options:
        * `opts` (map) – reserved for future use.

      ## Example

          iex> analyze_directory("lib/my_app", %{})
          %{"foo.ex" => %ComplexityMetrics{...}, "bar/baz.ex" => %ComplexityMetrics{...}}
      """
      @impl true
      @spec analyze_directory(directory :: String.t(), opts :: map()) ::
              %{String.t() => map()} | {:error, String.t()}
      def analyze_directory(directory, opts \\ %{}) do
        if File.dir?(directory) do
          supported_ext = supported_extensions()

          directory
          |> collect_all_files()
          |> Enum.filter(fn file ->
            ext = Path.extname(file)
            "*" in supported_ext || ext in supported_ext
          end)
          |> Task.async_stream(&analyze_file/1, on_timeout: :kill_task)
          |> Enum.reduce(%{}, fn
            {:ok, {:ok, %ComplexityMetrics{} = m}}, acc ->
              relative_path = Path.relative_to(m.file_path, directory)
              Map.put(acc, relative_path, m)

            {:ok, {:error, {:io, path, reason}}}, acc ->
              Map.put(acc, path, %{error: "I/O error: #{inspect(reason)}"})

            {:exit, reason}, acc ->
              Map.put(acc, "exit_#{inspect(reason)}", %{error: "Task crashed"})
          end)
        else
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
