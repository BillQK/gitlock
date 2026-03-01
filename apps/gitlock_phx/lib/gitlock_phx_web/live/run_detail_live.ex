defmodule GitlockPhxWeb.RunDetailLive do
  use GitlockPhxWeb, :live_view

  alias GitlockPhx.Pipelines

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    run = Pipelines.get_run_with_pipeline!(id)
    parsed = parse_stored_results(run.results)

    {:ok,
     assign(socket,
       run: run,
       parsed_results: parsed,
       page_title: "Run — #{pipeline_name(run)}"
     )}
  rescue
    Ecto.NoResultsError ->
      {:ok,
       socket
       |> put_flash(:error, "Run not found")
       |> push_navigate(to: ~p"/runs")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="run-detail-page">
      <div class="run-detail-container">
        <header class="run-detail-header">
          <div>
            <.link navigate={~p"/runs"} class="run-back">&larr; Run History</.link>
            <h1>{pipeline_name(@run)}</h1>
          </div>
          <div class="run-detail-meta">
            <span class={"run-status-label #{@run.status}"}>{@run.status}</span>
            <span class="run-meta-item">{@run.repo_url}</span>
            <span class="run-meta-item">{format_datetime(@run.started_at)}</span>
            <%= if @run.completed_at do %>
              <span class="run-meta-item">{format_duration(@run)}</span>
            <% end %>
          </div>
        </header>

        <%= if @run.error do %>
          <div class="run-error-banner">
            <strong>Error:</strong> {@run.error}
          </div>
        <% end %>

        <%= if length(@parsed_results) > 0 do %>
          <div class="analyze-results">
            <%= for %{label: label, status: :ok, rows: rows, columns: cols} <- @parsed_results do %>
              <div class="result-card">
                <div class="result-card-header">
                  <h3>{label}</h3>
                  <span class="result-count">{length(rows)} row{if length(rows) != 1, do: "s"}</span>
                </div>
                <div class="result-table-wrap">
                  <table class="result-table">
                    <thead>
                      <tr>
                        <%= for col <- cols do %>
                          <th>{format_column(col)}</th>
                        <% end %>
                      </tr>
                    </thead>
                    <tbody>
                      <%= for row <- Enum.take(rows, 50) do %>
                        <tr>
                          <%= for col <- cols do %>
                            <td title={to_string(Map.get(row, col, ""))}>
                              {format_cell(Map.get(row, col))}
                            </td>
                          <% end %>
                        </tr>
                      <% end %>
                    </tbody>
                  </table>
                  <%= if length(rows) > 50 do %>
                    <p class="result-truncated">Showing 50 of {length(rows)} rows</p>
                  <% end %>
                </div>
              </div>
            <% end %>

            <%= for %{label: label, status: :error, error: reason} <- @parsed_results do %>
              <div class="result-card error">
                <h3>{label}</h3>
                <pre class="result-error">{reason}</pre>
              </div>
            <% end %>
          </div>
        <% else %>
          <div class="runs-empty">
            <p>No result data stored for this run.</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  # ── Parse stored results ─────────────────────────────────────

  # Results from serialize_for_storage are maps like:
  # %{"node_id" => %{"status" => "ok", "label" => "...", "data" => ...}}
  defp parse_stored_results(nil), do: []
  defp parse_stored_results(results) when results == %{}, do: []

  defp parse_stored_results(results) when is_map(results) do
    results
    |> Enum.map(fn {_node_id, node_result} -> parse_node_result(node_result) end)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(& &1.label)
  end

  defp parse_node_result(%{"status" => "ok", "label" => label, "data" => data}) do
    parse_data(label, data)
  end

  defp parse_node_result(%{"status" => "error", "error" => reason}) do
    %{label: reason, status: :error, error: reason, rows: [], columns: []}
  end

  defp parse_node_result(_), do: nil

  defp parse_data(label, data) when is_list(data) and length(data) > 0 do
    rows = Enum.map(data, &stringify_keys/1)
    cols = rows |> List.first() |> Map.keys() |> prioritize_columns()
    %{label: label, status: :ok, rows: rows, columns: cols}
  end

  defp parse_data(label, data) when is_map(data) do
    values = Map.values(data)

    case values do
      [list] when is_list(list) and length(list) > 0 ->
        parse_data(label, list)

      _ ->
        rows =
          Enum.map(data, fn {k, v} -> %{"field" => to_string(k), "value" => format_cell(v)} end)

        %{label: label, status: :ok, rows: rows, columns: ["field", "value"]}
    end
  end

  defp parse_data(label, data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, decoded} -> parse_data(label, decoded)
      _ -> %{label: label, status: :ok, rows: [%{"output" => data}], columns: ["output"]}
    end
  end

  defp parse_data(label, _data) do
    %{label: label, status: :ok, rows: [], columns: []}
  end

  defp stringify_keys(map) when is_map(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  defp stringify_keys(other), do: %{"value" => inspect(other)}

  # ── Shared helpers ───────────────────────────────────────────

  defp pipeline_name(%{pipeline: %{name: name}}), do: name
  defp pipeline_name(_), do: "Unknown Pipeline"

  defp prioritize_columns(cols) do
    priority =
      ~w(file path name entity label author changes revisions complexity score risk normalized_score percentile)

    {front, rest} =
      Enum.split_with(cols, fn c -> String.downcase(c) in priority end)

    sorted_front =
      Enum.sort_by(front, fn c ->
        Enum.find_index(priority, &(&1 == String.downcase(c))) || 999
      end)

    sorted_front ++ Enum.sort(rest)
  end

  defp format_column(col) do
    col
    |> String.replace("_", " ")
    |> String.split(" ")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp format_cell(nil), do: "—"
  defp format_cell(v) when is_float(v), do: :erlang.float_to_binary(v, decimals: 3)
  defp format_cell(v) when is_integer(v), do: Integer.to_string(v)
  defp format_cell(v) when is_binary(v), do: v
  defp format_cell(v) when is_list(v), do: Enum.join(Enum.map(v, &to_string/1), ", ")
  defp format_cell(v) when is_map(v), do: inspect(v, limit: 5)
  defp format_cell(v), do: inspect(v)

  defp format_datetime(nil), do: ""
  defp format_datetime(dt), do: Calendar.strftime(dt, "%b %d, %Y at %H:%M UTC")

  defp format_duration(%{started_at: nil}), do: ""
  defp format_duration(%{completed_at: nil}), do: ""

  defp format_duration(%{started_at: started, completed_at: completed}) do
    diff = DateTime.diff(completed, started, :millisecond)

    cond do
      diff < 1_000 -> "#{diff}ms"
      diff < 60_000 -> "#{Float.round(diff / 1_000, 1)}s"
      true -> "#{div(diff, 60_000)}m #{rem(div(diff, 1_000), 60)}s"
    end
  end
end
