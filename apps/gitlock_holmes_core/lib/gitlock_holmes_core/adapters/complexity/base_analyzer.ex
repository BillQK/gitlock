defmodule GitlockHolmesCore.Adapters.Complexity.BaseAnalyzer do
  @moduledoc """
  Base adapter for complexity analyzers.

  This module provides shared functionality for complexity analyzers through
  a macro that can be used by concrete implementations.

  It supports analyzing a single file or a directory of files by delegating to
  `analyze_file/1`.
  """
  # Define a standardized error type
  @typedoc "Standard error format for complexity analyzers"
  # File I/O errors
  @type complexity_error ::
          {:io_error, String.t(), term()}
          # Parsing errors
          | {:parse_error, String.t(), term()}
          # Analysis errors
          | {:analysis_error, String.t(), term()}

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
  defmacro __using__(opts) do
    quote do
      @behaviour GitlockHolmesCore.Ports.ComplexityAnalyzerPort

      alias GitlockHolmesCore.Domain.Values.ComplexityMetrics
      alias GitlockHolmesCore.Adapters.Complexity.BaseAnalyzer

      # Determine if this is a delegating analyzer that doesn't calculate complexity directly
      @is_delegating_analyzer unquote(Keyword.get(opts, :delegating, false))

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
              | {:error, BaseAnalyzer.complexity_error()}
      def analyze_file(file_path) do
        with {:ok, content} <- File.read(file_path) |> handle_io_error(file_path),
             {:ok, complexity} <- calculate_complexity(content, file_path) do
          metrics =
            ComplexityMetrics.new(
              file_path,
              count_lines(content),
              complexity,
              detect_language(file_path)
            )

          {:ok, metrics}
        end
      end

      defp handle_io_error({:ok, content}, _file_path), do: {:ok, content}

      defp handle_io_error({:error, reason}, file_path),
        do: {:error, {:io_error, file_path, reason}}

      @doc """
      Recursively analyze supported files in `directory` concurrently.

      Returns a map of relative paths to `%ComplexityMetrics{}` on success,
      or `{:error, reason}` if `directory` isn't a valid directory.

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

            {:ok, {:error, error}}, acc ->
              # Format error for the specific file, include a default metrics struct
              # with a warning flag set
              error_description = format_error(error)
              relative_path = Path.relative_to(error_description.file_path, directory)

              Map.put(acc, relative_path, %{
                file_path: error_description.file_path,
                loc: 0,
                cyclomatic_complexity: 1,
                language: :unknown,
                error: error_description.message
              })

            {:exit, reason}, acc ->
              Map.put(acc, "exit_#{inspect(reason)}", %{error: "Task crashed: #{inspect(reason)}"})
          end)
        else
          {:error, "Invalid or inaccessible directory: #{directory}"}
        end
      end

      defp format_error({:io_error, file_path, reason}),
        do: %{file_path: file_path, message: "I/O error: #{inspect(reason)}"}

      defp format_error({:parse_error, file_path, reason}),
        do: %{file_path: file_path, message: "Parse error: #{inspect(reason)}"}

      defp format_error({:analysis_error, file_path, reason}),
        do: %{file_path: file_path, message: "Analysis error: #{inspect(reason)}"}

      defp format_error(other),
        do: %{file_path: "unknown", message: "Unknown error: #{inspect(other)}"}

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

      # For delegating analyzers, provide a default implementation
      if @is_delegating_analyzer do
        # Default implementation for delegating analyzers that don't do complexity calculation directly.
        # This is never called when the analyze_file method is overridden.
        defp calculate_complexity(_content, _file_path), do: 0
      else
        @doc """
        Calculates the cyclomatic complexity of code content.

        This function **must** be implemented by any non-delegating analyzer module using this base.

        ## Parameters
          * `content` - The code content to analyze
          * `file_path` - Path to the file (for context)

        ## Returns
          The calculated cyclomatic complexity as an integer
        """
        @spec calculate_complexity(content :: String.t(), file_path :: String.t()) ::
                non_neg_integer()
      end

      defoverridable analyze_file: 1
      defoverridable analyze_directory: 2
    end
  end
end
