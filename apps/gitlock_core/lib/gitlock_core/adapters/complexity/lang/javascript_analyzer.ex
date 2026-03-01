defmodule GitlockCore.Adapters.Complexity.Lang.JavaScriptAnalyzer do
  @moduledoc """
  JavaScript complexity analyzer for CodeMaat-style forensic code analysis.

  Calculates cyclomatic complexity for JavaScript/TypeScript files by counting:
  - Conditional statements (if, switch-case, ternary)
  - Loops (for, while, do-while)
  - Logical operations (&&, ||, ??)
  - Try-catch blocks
  - Function definitions (each function adds +1 baseline)

  Comments and string literals are stripped before analysis to prevent
  false positives.
  """
  use GitlockCore.Adapters.Complexity.BaseAnalyzer

  def supported_extensions, do: [".js", ".jsx"]

  defp calculate_complexity(content, _file_path) do
    cleaned = clean_js_content(content)

    base_complexity = 1

    patterns = [
      if: ~r/\bif\s*\(/,
      else_if: ~r/\belse\s+if\s*\(/,
      for: ~r/\bfor\s*\(/,
      while: ~r/\bwhile\s*\(/,
      do_while: ~r/\bdo\s*\{/,
      case: ~r/\bcase\s+[^:]+:/,
      catch: ~r/\bcatch\s*[\(\{]/,
      logical_and: ~r/&&/,
      logical_or: ~r/\|\|/,
      nullish: ~r/\?\?(?!=)/,
      ternary: ~r/[^?]\?[^?.]/,
      function_decl: ~r/\bfunction\s+\w+\s*\(/,
      function_expr: ~r/\b(?:const|let|var)\s+\w+\s*=\s*function\s*\(/,
      arrow_fn: ~r/(?:=>)/
    ]

    complexity_counts =
      Task.async_stream(
        patterns,
        fn {_name, pattern} ->
          count_regex(cleaned, pattern)
        end,
        on_timeout: :kill_task
      )
      |> Enum.reduce(0, fn {:ok, count}, acc -> acc + count end)

    base_complexity + complexity_counts
  end

  # Strip comments and string literals to avoid false positives.
  defp clean_js_content(content) do
    content
    # Remove single-line comments
    |> String.replace(~r|//.*$|m, "")
    # Remove multi-line comments
    |> String.replace(~r|/\*[\s\S]*?\*/|, "")
    # Remove template literals (backtick strings)
    |> String.replace(~r/`(?:[^`\\]|\\.)*`/s, "\"\"")
    # Remove double-quoted strings
    |> String.replace(~r/"(?:[^"\\]|\\.)*"/, "\"\"")
    # Remove single-quoted strings
    |> String.replace(~r/'(?:[^'\\]|\\.)*'/, "''")
  end

  defp count_regex(content, pattern) do
    Regex.scan(pattern, content) |> length()
  end
end
