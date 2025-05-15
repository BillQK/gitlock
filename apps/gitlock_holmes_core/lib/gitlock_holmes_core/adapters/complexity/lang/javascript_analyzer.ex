defmodule GitlockHolmesCore.Adapters.Complexity.Lang.JavaScriptAnalyzer do
  @moduledoc """
  JavaScript complexity analyzer for CodeMaat-style forensic code analysis.
  This analyzer calculates cyclomatic complexity for JavaScript files by counting:
  - Conditional statements (if, switch-case, ternary)
  - Loops (for, while, do-while)
  - Logical operations (&&, ||)
  - Try-catch blocks
  - Functions definitions (each function is a +1 baseline complexity)
  It implements the ComplexityAnalyzerPort behavior using the BaseAnalyzer.
  """
  use GitlockHolmesCore.Adapters.Complexity.BaseAnalyzer

  @doc """
  Returns the file extensions this analyzer supports.
  """
  def supported_extensions, do: [".js", ".jsx", ".ts", ".tsx"]

  # Calculates cyclomatic complexity for JavaScript code.
  #
  # The calculation is based on counting control flow branches:
  # - Each function gets a base complexity of 1
  # - Each 'if', 'else if', 'switch case', 'for', 'while', etc. adds 1
  # - Each '&&', '||' in conditions adds 1
  # - Each 'catch' block adds 1
  #
  # ## Parameters
  #   * `content` - JavaScript code as string
  #   * `file_path` - Path to the source file (used for error reporting)
  #
  # ## Returns
  #   A non-negative integer representing the cyclomatic complexity
  defp calculate_complexity(content, _file_path) do
    # Calculate base complexity - start with 1 for the program itself
    base_complexity = 1

    # Define all patterns to search for
    patterns = [
      if: ~r/\bif\s*\(/,
      else_if: ~r/\belse\s+if\s*\(/,
      ternary: ~r/\?\s*[^:]+\s*:/,
      for: ~r/\bfor\s*\(/,
      while: ~r/\bwhile\s*\(/,
      do_while: ~r/\bdo\s*\{/,
      function1: ~r/\bfunction\s+[a-zA-Z_$][a-zA-Z0-9_$]*\s*\(/,
      function2: ~r/\b(const|let|var)\s+[a-zA-Z_$][a-zA-Z0-9_$]*\s*=\s*function\s*\(/,
      function3: ~r/\b(const|let|var)\s+[a-zA-Z_$][a-zA-Z0-9_$]*\s*=\s*\([^)]*\)\s*=>/,
      case: ~r/\bcase\s+[^:]+:/,
      logical_ops: ~r/\s+&&\s+|\s+\|\|\s+/,
      catch: ~r/\bcatch\s*\(/
    ]

    # Run all regex scans in parallel and collect results
    complexity_counts =
      Task.async_stream(
        patterns,
        fn {_name, pattern} ->
          count_regex(content, pattern)
        end,
        on_timeout: :kill_task
      )
      |> Enum.reduce(0, fn {:ok, count}, acc -> acc + count end)

    # Calculate the total cyclomatic complexity
    base_complexity + complexity_counts
  end

  @spec count_regex(String.t(), Regex.t()) :: non_neg_integer()
  defp count_regex(content, pattern) do
    Regex.scan(pattern, content) |> length()
  end
end
