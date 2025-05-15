defmodule GitlockHolmesCore.Adapters.Complexity.Lang.ElixirAnalyzer do
  @moduledoc """
  Complexity analyzer for Elixir code.
  Calculates cyclomatic complexity by analyzing the AST for branching
  statements (if, case, cond, with, etc.).
  """
  use GitlockHolmesCore.Adapters.Complexity.BaseAnalyzer

  def supported_extensions, do: [".ex", ".exs"]

  # Must be a public function to override the BaseAnalyzer
  def calculate_complexity(content, _file_path) do
    try do
      # Parse the code to AST
      {:ok, ast} = Code.string_to_quoted(content)

      # Calculate complexity (starting at 1 for baseline)
      complexity = 1 + count_complexity(ast)

      # Return complexity value
      complexity
    rescue
      # Default complexity if parsing fails
      _ -> 1
    end
  end

  # Traverses the AST to count decision points
  defp count_complexity(nil), do: 0
  defp count_complexity(expr) when not is_tuple(expr) and not is_list(expr), do: 0

  # If statements add 1 complexity
  defp count_complexity({:if, _, [condition, blocks]}) do
    # Count the if statement itself
    condition_complexity = count_complexity(condition)

    # Extract do and else blocks
    do_block = Keyword.get(blocks, :do, nil)
    else_block = Keyword.get(blocks, :else, nil)

    # Count complexity in both branches
    do_complexity = count_complexity(do_block)
    else_complexity = count_complexity(else_block)

    # Return total
    1 + condition_complexity + do_complexity + else_complexity
  end

  # Case expressions add 1 for each pattern match
  defp count_complexity({:case, _, [expr, [do: clauses]]}) do
    expr_complexity = count_complexity(expr)

    # Count 1 for each clause plus complexity within each clause
    clauses_complexity =
      Enum.reduce(clauses, 0, fn
        {:->, _, [_pattern, body]}, acc ->
          acc + 1 + count_complexity(body)
      end)

    expr_complexity + clauses_complexity
  end

  # Cond statements add 1 for each condition
  defp count_complexity({:cond, _, [[do: clauses]]}) do
    Enum.reduce(clauses, 0, fn
      {:->, _, [[condition], body]}, acc ->
        acc + 1 + count_complexity(condition) + count_complexity(body)
    end)
  end

  # Boolean operators add complexity
  defp count_complexity({op, _, [left, right]}) when op in [:and, :or, :&&, :||] do
    1 + count_complexity(left) + count_complexity(right)
  end

  # Function definitions
  defp count_complexity({:def, _, [_head, [do: body]]}) do
    count_complexity(body)
  end

  defp count_complexity({:defp, _, [_head, [do: body]]}) do
    count_complexity(body)
  end

  # Recursively process nodes
  defp count_complexity({_op, _meta, args}) when is_list(args) do
    Enum.reduce(args, 0, fn arg, acc ->
      acc + count_complexity(arg)
    end)
  end

  # Handle lists (including keyword lists)
  defp count_complexity(list) when is_list(list) do
    Enum.reduce(list, 0, fn
      {_key, value}, acc -> acc + count_complexity(value)
      item, acc -> acc + count_complexity(item)
    end)
  end

  # Default for anything else
  defp count_complexity(_), do: 0
end
