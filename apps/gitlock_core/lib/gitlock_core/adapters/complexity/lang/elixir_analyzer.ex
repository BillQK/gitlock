defmodule GitlockCore.Adapters.Complexity.Lang.ElixirAnalyzer do
  @moduledoc """
  Complexity analyzer for Elixir code.
  Calculates cyclomatic complexity by analyzing the AST for branching
  statements (if, case, cond, with, try/rescue, receive, multi-clause
  functions, and boolean operators).
  """
  use GitlockCore.Adapters.Complexity.BaseAnalyzer

  def supported_extensions, do: [".ex", ".exs"]

  def calculate_complexity(content, file_path) do
    try do
      case Code.string_to_quoted(content) do
        {:ok, ast} ->
          1 + count_complexity(ast)

        {:error, {_line, _error, _token}} ->
          -1
      end
    rescue
      _e ->
        IO.warn("#{file_path}: Error analyzing code")
        -1
    end
  end

  # --- Leaf nodes ---
  defp count_complexity(nil), do: 0
  defp count_complexity(expr) when not is_tuple(expr) and not is_list(expr), do: 0

  # --- if/unless ---
  defp count_complexity({op, _, [condition, blocks]}) when op in [:if, :unless] do
    do_block = Keyword.get(blocks, :do, nil)
    else_block = Keyword.get(blocks, :else, nil)

    1 +
      count_complexity(condition) +
      count_complexity(do_block) +
      count_complexity(else_block)
  end

  # --- case ---
  defp count_complexity({:case, _, [expr, [do: clauses]]}) do
    clauses_complexity =
      Enum.reduce(clauses, 0, fn
        {:->, _, [_pattern, body]}, acc ->
          acc + 1 + count_complexity(body)
      end)

    count_complexity(expr) + clauses_complexity
  end

  # --- cond ---
  defp count_complexity({:cond, _, [[do: clauses]]}) do
    Enum.reduce(clauses, 0, fn
      {:->, _, [[condition], body]}, acc ->
        acc + 1 + count_complexity(condition) + count_complexity(body)
    end)
  end

  # --- with ---
  defp count_complexity({:with, _, args}) when is_list(args) do
    {clauses, blocks} = split_with_args(args)

    clauses_complexity =
      Enum.reduce(clauses, 0, fn
        {:<-, _, [_pattern, expr]}, acc -> acc + 1 + count_complexity(expr)
        expr, acc -> acc + count_complexity(expr)
      end)

    do_block = Keyword.get(blocks, :do, nil)
    else_clauses = Keyword.get(blocks, :else, [])

    else_complexity =
      case else_clauses do
        clauses when is_list(clauses) ->
          Enum.reduce(clauses, 0, fn
            {:->, _, [_pattern, body]}, acc -> acc + 1 + count_complexity(body)
            _, acc -> acc
          end)

        other ->
          count_complexity(other)
      end

    clauses_complexity + count_complexity(do_block) + else_complexity
  end

  # --- try/rescue/catch ---
  defp count_complexity({:try, _, [[{:do, do_block} | rest]]}) do
    rescue_complexity =
      case Keyword.get(rest, :rescue) do
        nil ->
          0

        clauses when is_list(clauses) ->
          Enum.reduce(clauses, 0, fn
            {:->, _, [_pattern, body]}, acc -> acc + 1 + count_complexity(body)
            _, acc -> acc
          end)
      end

    catch_complexity =
      case Keyword.get(rest, :catch) do
        nil ->
          0

        clauses when is_list(clauses) ->
          Enum.reduce(clauses, 0, fn
            {:->, _, [_pattern, body]}, acc -> acc + 1 + count_complexity(body)
            _, acc -> acc
          end)
      end

    after_block = Keyword.get(rest, :after, nil)

    count_complexity(do_block) +
      rescue_complexity +
      catch_complexity +
      count_complexity(after_block)
  end

  # --- receive ---
  defp count_complexity({:receive, _, [blocks]}) when is_list(blocks) do
    clauses = Keyword.get(blocks, :do, [])

    clauses_complexity =
      case clauses do
        c when is_list(c) ->
          Enum.reduce(c, 0, fn
            {:->, _, [_pattern, body]}, acc -> acc + 1 + count_complexity(body)
            _, acc -> acc
          end)

        other ->
          count_complexity(other)
      end

    after_clauses = Keyword.get(blocks, :after, nil)

    after_complexity =
      case after_clauses do
        nil -> 0
        c when is_list(c) ->
          Enum.reduce(c, 0, fn
            {:->, _, [_pattern, body]}, acc -> acc + 1 + count_complexity(body)
            _, acc -> acc
          end)
        other -> count_complexity(other)
      end

    clauses_complexity + after_complexity
  end

  # --- Anonymous fn with multiple clauses ---
  defp count_complexity({:fn, _, clauses}) when is_list(clauses) do
    if length(clauses) > 1 do
      # Multiple clauses = branching, count each
      Enum.reduce(clauses, 0, fn
        {:->, _, [_pattern, body]}, acc -> acc + 1 + count_complexity(body)
      end)
    else
      # Single clause fn, just recurse into body
      Enum.reduce(clauses, 0, fn
        {:->, _, [_pattern, body]}, acc -> acc + count_complexity(body)
      end)
    end
  end

  # --- Boolean operators ---
  defp count_complexity({op, _, [left, right]}) when op in [:and, :or, :&&, :||] do
    1 + count_complexity(left) + count_complexity(right)
  end

  # --- Multi-clause named functions ---
  # def/defp with when guards count the guard as a decision point
  defp count_complexity({op, _, [{:when, _, [_head, _guard]}, [do: body]]})
       when op in [:def, :defp] do
    1 + count_complexity(body)
  end

  defp count_complexity({op, _, [_head, [do: body]]}) when op in [:def, :defp] do
    count_complexity(body)
  end

  # --- Generic AST node recursion ---
  defp count_complexity({_op, _meta, args}) when is_list(args) do
    Enum.reduce(args, 0, fn arg, acc ->
      acc + count_complexity(arg)
    end)
  end

  # --- Lists (including keyword lists) ---
  defp count_complexity(list) when is_list(list) do
    Enum.reduce(list, 0, fn
      {_key, value}, acc -> acc + count_complexity(value)
      item, acc -> acc + count_complexity(item)
    end)
  end

  defp count_complexity(_), do: 0

  # --- Helpers ---

  # Splits `with` args into match clauses and keyword blocks (do/else)
  defp split_with_args(args) do
    {clauses, blocks} =
      Enum.split_while(args, fn
        [{:do, _} | _] -> false
        [do: _] -> false
        _ -> true
      end)

    blocks = List.flatten(blocks)
    {clauses, blocks}
  end
end
