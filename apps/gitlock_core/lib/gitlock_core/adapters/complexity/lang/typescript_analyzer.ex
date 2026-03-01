defmodule GitlockCore.Adapters.Complexity.Lang.TypeScriptAnalyzer do
  @moduledoc """
  TypeScript complexity analyzer for Gitlock forensic code analysis.

  Builds on JavaScript patterns but handles TypeScript-specific concerns:
  - Strips type annotations, interfaces, and type aliases before analysis
    to prevent false positives (e.g. conditional types `T extends U ? X : Y`
    matching the ternary regex)
  - Counts optional chaining `?.` as a branch point
  - Counts type guard functions as decision points
  - Handles decorators, enums, and other TS syntax

  Comments, string literals, and type-only constructs are stripped before
  analysis to ensure accurate results.
  """
  use GitlockCore.Adapters.Complexity.BaseAnalyzer

  def supported_extensions, do: [".ts", ".tsx"]

  defp calculate_complexity(content, _file_path) do
    cleaned =
      content
      |> strip_comments_and_strings()
      |> strip_type_constructs()

    base_complexity = 1

    patterns = [
      # --- JS patterns (TS is a superset) ---
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
      function_decl: ~r/\bfunction\s+\w+\s*[\(<]/,
      function_expr: ~r/\b(?:const|let|var)\s+\w+\s*(?::\s*\w[^=]*)?\s*=\s*function\s*[\(<]/,
      arrow_fn: ~r/=>/,

      # --- TypeScript-specific ---
      # Optional chaining is a branch (short-circuits on null/undefined)
      optional_chain: ~r/\?\.\s*[\w\[(]/,
      # Type guard functions: `function isX(val): val is Type`
      type_guard: ~r/\)\s*:\s*\w+\s+is\s+\w+/
    ]

    complexity_counts =
      Task.async_stream(
        patterns,
        fn {_name, pattern} ->
          Regex.scan(pattern, cleaned) |> length()
        end,
        on_timeout: :kill_task
      )
      |> Enum.reduce(0, fn {:ok, count}, acc -> acc + count end)

    base_complexity + complexity_counts
  end

  # Strip comments and string literals to avoid false positives.
  # Same as JS analyzer — TS uses identical comment/string syntax.
  defp strip_comments_and_strings(content) do
    content
    |> String.replace(~r|//.*$|m, "")
    |> String.replace(~r|/\*[\s\S]*?\*/|, "")
    |> String.replace(~r/`(?:[^`\\]|\\.)*`/s, "\"\"")
    |> String.replace(~r/"(?:[^"\\]|\\.)*"/, "\"\"")
    |> String.replace(~r/'(?:[^'\\]|\\.)*'/, "''")
  end

  # Strip TypeScript type-only constructs that could cause false positives.
  #
  # Key problem: conditional types like `T extends U ? X : Y` contain `?`
  # which would falsely match the ternary regex. Interface/type declarations
  # can also contain patterns that look like runtime branches.
  defp strip_type_constructs(content) do
    content
    # Remove full interface declarations (multi-line)
    |> String.replace(~r/\binterface\s+\w+(?:\s+extends\s+[^{]+)?\s*\{[^}]*\}/s, "")
    # Remove type alias declarations (handles multi-line conditional types)
    |> String.replace(~r/\btype\s+\w+(?:<[^>]*>)?\s*=\s*[^;]+;/s, "")
    # Remove type annotations after `:` in params/returns
    # e.g. `(x: number, y: string): boolean` → `(x, y)`
    # IMPORTANT: must NOT include `{` or `}` — those delimit code blocks,
    # not just inline object types. Matching them eats function bodies.
    |> String.replace(~r/:\s*(?:readonly\s+)?[\w<>\[\]|&\s,.]+(?=\s*[,)=>{])/s, "")
    # Remove angle-bracket generics `<T extends Foo>` to avoid `extends` noise
    |> String.replace(~r/<[^>]*>/s, "")
    # Remove `as` type assertions: `x as Type`
    |> String.replace(~r/\bas\s+\w[\w.]*(?:\[\])?/s, "")
    # Remove `declare` statements (ambient declarations)
    |> String.replace(~r/\bdeclare\s+[^;{]+[;{]/s, "")
    # Remove `enum` declarations (members aren't branches)
    |> String.replace(~r/\benum\s+\w+\s*\{[^}]*\}/s, "")
  end
end
