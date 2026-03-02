defmodule GitlockPhxWeb.ResultSerializer do
  @moduledoc """
  Converts raw runtime node output into JSON-safe maps for the frontend.

  Runtime nodes return port-keyed maps like `%{hotspots: [%Hotspot{...}, ...]}`.
  This module:
  - Extracts the primary data from single-port output maps
  - Converts structs to plain string-keyed maps
  - Ensures all values are JSON-serializable
  """

  @doc """
  Serializes runtime node output for push_event to Svelte.

  If the output is a single-key map (typical port output like `%{hotspots: [...]}`),
  extracts the inner value. Converts all structs to plain maps with string keys.
  """
  @spec serialize(term()) :: term()
  def serialize(output) when is_map(output) and not is_struct(output) do
    case Map.to_list(output) do
      # Single port output — extract the value directly
      [{_port, value}] ->
        serialize_value(value)

      # Multiple ports — serialize each value
      pairs when length(pairs) > 1 ->
        Map.new(pairs, fn {k, v} -> {to_string(k), serialize_value(v)} end)

      [] ->
        %{}
    end
  end

  def serialize(output), do: serialize_value(output)

  @doc """
  Serializes the complete results map from pipeline_complete.

  Results are `%{node_id => {:ok, %{data: output}} | {:error, reason}}`.
  """
  @spec serialize_results(map()) :: map()
  def serialize_results(results) when is_map(results) do
    Map.new(results, fn
      {node_id, {:ok, %{data: data} = meta}} ->
        {node_id, {:ok, %{meta | data: serialize(data)}}}

      {node_id, other} ->
        {node_id, other}
    end)
  end

  @doc """
  Serializes results into a fully JSON-safe map for database storage.

  Converts `{:ok, ...}` / `{:error, ...}` tuples into plain maps with
  a `"status"` key, suitable for JSONB columns.
  """
  @spec serialize_for_storage(map()) :: map()
  def serialize_for_storage(results) when is_map(results) do
    Map.new(results, fn
      {node_id, {:ok, %{data: data} = meta}} ->
        {node_id,
         %{
           "status" => "ok",
           "node_id" => to_string(Map.get(meta, :node_id, node_id)),
           "type" => to_string(Map.get(meta, :type, "unknown")),
           "label" => to_string(Map.get(meta, :label, node_id)),
           "data" => serialize(data)
         }}

      {node_id, {:error, reason}} ->
        {node_id,
         %{
           "status" => "error",
           "error" => to_string(reason)
         }}

      {node_id, _other} ->
        {node_id, %{"status" => "unknown"}}
    end)
  end

  # ── Private ──────────────────────────────────────────────────

  defp serialize_value(list) when is_list(list) do
    Enum.map(list, &serialize_value/1)
  end

  defp serialize_value(%{__struct__: _} = struct) do
    struct
    |> Map.from_struct()
    |> Map.new(fn {k, v} -> {to_string(k), serialize_value(v)} end)
  end

  defp serialize_value(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), serialize_value(v)} end)
  end

  defp serialize_value(atom) when is_atom(atom) and not is_nil(atom) and not is_boolean(atom) do
    Atom.to_string(atom)
  end

  defp serialize_value(tuple) when is_tuple(tuple) do
    tuple |> Tuple.to_list() |> Enum.map(&serialize_value/1)
  end

  defp serialize_value(other), do: other
end
