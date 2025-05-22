defmodule GitlockHolmesCore.Adapters.Complexity.Lang.PythonAnalyzer do
  @moduledoc """
  Python complexity analyzer for GitlockHolmes forensic code analysis.

  This analyzer calculates cyclomatic complexity for Python files by counting:
  - Conditional statements (if, elif)
  - Loops (for, while)
  - Exception handling (except)
  - Logical operations (and, or)
  - Comprehensions (list, dict, set comprehensions with conditions)
  - Function/method definitions
  - Lambda expressions with conditions

  The analyzer uses regex patterns to identify these constructs, similar to
  the JavaScript analyzer implementation.
  """
  use GitlockHolmesCore.Adapters.Complexity.BaseAnalyzer

  @doc """
  Returns the file extensions this analyzer supports.
  """
  def supported_extensions, do: [".py"]

  # Calculates cyclomatic complexity for Python code.
  #
  # The calculation is based on counting control flow branches:
  # - Each function/method gets a base complexity of 1
  # - Each 'if', 'elif' adds 1
  # - Each 'for', 'while' loop adds 1
  # - Each 'except' block adds 1
  # - Each 'and', 'or' in conditions adds 1
  # - Each conditional expression (ternary) adds 1
  # - Each comprehension with 'if' condition adds 1
  #
  # ## Parameters
  #   * `content` - Python code as string
  #   * `file_path` - Path to the source file (used for error reporting)
  #
  # ## Returns
  #   A non-negative integer representing the cyclomatic complexity
  defp calculate_complexity(content, _file_path) do
    # Remove comments and strings to avoid false positives
    cleaned_content = clean_python_content(content)

    # Calculate base complexity - start with 1 for the module itself
    base_complexity = 1

    # Define all patterns to search for
    patterns = [
      # Function and method definitions (including async)
      function_def: ~r/\b(async\s+)?def\s+\w+\s*\(/,

      # Class definitions (each adds a decision point)
      class_def: ~r/\bclass\s+\w+/,

      # Conditional statements
      if_stmt: ~r/\bif\s+.+:/,
      elif_stmt: ~r/\belif\s+.+:/,

      # Loops
      for_loop: ~r/\bfor\s+.+\s+in\s+.+:/,
      while_loop: ~r/\bwhile\s+.+:/,

      # Exception handling
      except_block: ~r/\bexcept(\s+\w+)?(\s+as\s+\w+)?:/,

      # Logical operators in conditions (but not in assignments)
      # This is tricky with regex, so we'll count them separately
      and_op: ~r/\s+and\s+/,
      or_op: ~r/\s+or\s+/,

      # Ternary/conditional expressions
      ternary: ~r/\bif\s+.+\s+else\s+/,

      # Comprehensions with conditions
      list_comp_if: ~r/\[\s*[^]]+\s+if\s+[^]]+\]/,
      dict_comp_if: ~r/\{\s*[^}]+\s+if\s+[^}]+\}/,
      set_comp_if: ~r/\{\s*[^}]+\s+if\s+[^}]+\}/,
      gen_exp_if: ~r/\(\s*[^)]+\s+if\s+[^)]+\)/,

      # Lambda with conditions (rough approximation)
      lambda_if: ~r/lambda\s+[^:]+:.*\bif\b/,

      # Match/case statements (Python 3.10+)
      match_stmt: ~r/\bmatch\s+.+:/,
      case_clause: ~r/\bcase\s+.+:/
    ]

    # Count occurrences of each pattern
    complexity_counts =
      Task.async_stream(
        patterns,
        fn {_name, pattern} ->
          count_pattern_occurrences(cleaned_content, pattern)
        end,
        on_timeout: :kill_task
      )
      |> Enum.reduce(0, fn {:ok, count}, acc -> acc + count end)

    # Calculate the total cyclomatic complexity
    base_complexity + complexity_counts
  end

  # Removes comments and string literals from Python code to avoid false positives.
  #
  # This is a simplified approach that handles most common cases but may not be
  # perfect for all edge cases (e.g., nested quotes, raw strings).
  @spec clean_python_content(String.t()) :: String.t()
  defp clean_python_content(content) do
    content
    # Remove single-line comments
    |> String.replace(~r/#.*$/, "", global: true)
    # Remove triple-quoted strings (docstrings)
    |> String.replace(~r/"""[\s\S]*?"""|'''[\s\S]*?'''/m, "", global: true)
    # Remove double-quoted strings
    |> String.replace(~r/"(?:[^"\\]|\\.)*"/, "", global: true)
    # Remove single-quoted strings
    |> String.replace(~r/'(?:[^'\\]|\\.)*'/, "", global: true)
  end

  # Counts occurrences of a regex pattern in the content.
  #
  # ## Parameters
  #   * `content` - The cleaned Python code
  #   * `pattern` - The regex pattern to search for
  #
  # ## Returns
  #   Number of matches found
  @spec count_pattern_occurrences(String.t(), Regex.t()) :: non_neg_integer()
  defp count_pattern_occurrences(content, pattern) do
    Regex.scan(pattern, content) |> length()
  end
end
