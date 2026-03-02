defmodule GitlockWorkflows.Runtime.Nodes.Logic.Merge do
  @moduledoc """
  Combines items from two input sources.

  ## Modes

  - `append` — Concatenate both lists
  - `interleave` — Alternate items from each list
  - `keep_a` — Keep only items_a (pass-through, useful after IF branches)
  """
  use GitlockWorkflows.Runtime.Node
  require Logger

  @impl true
  def metadata do
    %{
      id: "gitlock.logic.merge",
      displayName: "Merge",
      group: "logic",
      version: 1,
      description: "Combines items from two inputs into one output",
      inputs: [
        %{name: "items_a", type: :any, required: true, description: "First set of items"},
        %{name: "items_b", type: :any, required: false, description: "Second set of items"}
      ],
      outputs: [%{name: "items", type: :any}],
      parameters: [
        %{
          name: "mode",
          displayName: "Mode",
          type: "select",
          required: false,
          default: "append",
          options: [
            %{value: "append", label: "Append (A then B)"},
            %{value: "interleave", label: "Interleave (alternate)"},
            %{value: "keep_a", label: "Keep A only"}
          ],
          description: "How to combine the two inputs"
        }
      ]
    }
  end

  @impl true
  def execute(input_data, parameters, _context) do
    items_a = to_list(Map.get(input_data, :items_a))
    items_b = to_list(Map.get(input_data, :items_b))
    mode = Map.get(parameters, "mode", "append")

    merged =
      case mode do
        "interleave" -> interleave(items_a, items_b)
        "keep_a" -> items_a
        _ -> items_a ++ items_b
      end

    Logger.info("Merge (#{mode}): #{length(items_a)} + #{length(items_b)} → #{length(merged)}")
    {:ok, %{items: merged}}
  end

  @impl true
  def validate_parameters(_), do: :ok

  defp to_list(v) when is_list(v), do: v
  defp to_list(_), do: []

  defp interleave([], b), do: b
  defp interleave(a, []), do: a
  defp interleave([ha | ta], [hb | tb]), do: [ha, hb | interleave(ta, tb)]
end
