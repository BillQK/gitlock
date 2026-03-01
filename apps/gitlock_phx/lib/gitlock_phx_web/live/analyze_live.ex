defmodule GitlockPhxWeb.AnalyzeLive do
  use GitlockPhxWeb, :live_view

  alias GitlockPhx.Pipelines
  alias GitlockPhx.Pipelines.PipelineRun
  alias GitlockWorkflows.{Pipeline, Executor}
  alias GitlockPhxWeb.ResultSerializer

  @impl true
  def mount(_params, _session, socket) do
    templates = Pipelines.list_templates()

    {:ok,
     assign(socket,
       templates: templates,
       selected_template: nil,
       repo_url: "",
       execution: :idle,
       node_progress: %{},
       results: %{},
       parsed_results: [],
       pipeline: nil,
       current_run: nil,
       error: nil,
       page_title: "Analyze Repository"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="analyze-page">
      <div class="analyze-container">
        <header class="analyze-header">
          <h1>Analyze a Repository</h1>
          <p class="analyze-subtitle">
            Paste a Git URL or local path to discover hotspots, knowledge silos, and technical debt.
          </p>
        </header>

        <div class="analyze-form">
          <form phx-submit="run_analysis" phx-change="form_change">
            <div class="form-group">
              <label for="repo_url">Repository</label>
              <input
                type="text"
                id="repo_url"
                name="repo_url"
                value={@repo_url}
                placeholder="https://github.com/org/repo or /path/to/local/repo"
                class="analyze-input"
                phx-debounce="300"
                autofocus
              />
            </div>

            <div class="form-group">
              <label>Analysis Template</label>
              <div class="template-grid">
                <%= for tpl <- @templates do %>
                  <button
                    type="button"
                    class={"template-card #{if @selected_template && @selected_template.id == tpl.id, do: "selected", else: ""}"}
                    phx-click="select_template"
                    phx-value-id={tpl.id}
                  >
                    <span class="template-name">{tpl.name}</span>
                    <span class="template-desc">{tpl.description}</span>
                    <span class="template-nodes">{map_size(tpl.config["nodes"] || %{})} steps</span>
                  </button>
                <% end %>
              </div>
            </div>

            <button
              type="submit"
              class={"analyze-submit #{if @execution == :running, do: "running"}"}
              disabled={@repo_url == "" or @selected_template == nil or @execution == :running}
            >
              {submit_label(@execution)}
            </button>
          </form>
        </div>

        <%= if @execution == :running do %>
          <div class="analyze-progress">
            <h2>Running Analysis</h2>
            <div class="progress-nodes">
              <%= for {node_id, status} <- @node_progress do %>
                <div class={"progress-node #{status_class(status)}"}>
                  <span class="progress-indicator">{status_icon(status)}</span>
                  <span class="progress-label">{node_label(node_id, @pipeline)}</span>
                  <%= if status_text(status) do %>
                    <span class="progress-status-text">{status_text(status)}</span>
                  <% end %>
                </div>
              <% end %>
            </div>
          </div>
        <% end %>

        <%= if @execution == :done and length(@parsed_results) > 0 do %>
          <div class="analyze-results">
            <h2>Results</h2>
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
                      <%= for row <- Enum.take(rows, 30) do %>
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
                  <%= if length(rows) > 30 do %>
                    <p class="result-truncated">Showing 30 of {length(rows)} rows</p>
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
        <% end %>

        <%= if @error do %>
          <div class="analyze-error">
            <p>{@error}</p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("form_change", %{"repo_url" => url}, socket) do
    {:noreply, assign(socket, repo_url: String.trim(url))}
  end

  def handle_event("select_template", %{"id" => id}, socket) do
    template = Enum.find(socket.assigns.templates, &(to_string(&1.id) == id))
    {:noreply, assign(socket, selected_template: template)}
  end

  def handle_event("run_analysis", _params, socket) do
    template = socket.assigns.selected_template
    repo_url = socket.assigns.repo_url

    if template == nil or repo_url == "" do
      {:noreply, assign(socket, error: "Select a template and enter a repository URL")}
    else
      pipeline = Pipelines.to_workflow(template)

      # Persist run for logged-in users
      run = maybe_create_run(socket, template, repo_url)

      Executor.run(pipeline, repo_url, self(), %{format: "json"})

      {:noreply,
       assign(socket,
         pipeline: pipeline,
         current_run: run,
         execution: :running,
         node_progress: %{},
         results: %{},
         parsed_results: [],
         error: nil
       )}
    end
  end

  @impl true
  def handle_info({:pipeline_progress, node_id, :running}, socket) do
    progress = Map.put(socket.assigns.node_progress, node_id, :running)
    {:noreply, assign(socket, node_progress: progress)}
  end

  def handle_info({:pipeline_progress, node_id, {:status, message}}, socket) do
    progress = Map.put(socket.assigns.node_progress, node_id, {:running, message})
    {:noreply, assign(socket, node_progress: progress)}
  end

  def handle_info({:pipeline_progress, node_id, {:done, _result}}, socket) do
    progress = Map.put(socket.assigns.node_progress, node_id, :done)
    {:noreply, assign(socket, node_progress: progress)}
  end

  def handle_info({:pipeline_progress, node_id, {:error, _reason}}, socket) do
    progress = Map.put(socket.assigns.node_progress, node_id, :error)
    {:noreply, assign(socket, node_progress: progress)}
  end

  def handle_info({:pipeline_complete, results}, socket) do
    serialized = ResultSerializer.serialize_results(results)
    parsed = parse_results(serialized, socket.assigns.pipeline)

    # Persist run results
    persist_run_results(socket.assigns[:current_run], results)

    {:noreply,
     assign(socket,
       execution: :done,
       results: serialized,
       parsed_results: parsed,
       current_run: nil
     )}
  end

  # ── Parse execution results into display-ready structs ───────

  defp parse_results(results, pipeline) do
    results
    |> Enum.map(fn {node_id, outcome} ->
      label = node_label(node_id, pipeline)

      case outcome do
        {:ok, %{data: data}} ->
          parse_success(label, data)

        {:ok, data} ->
          parse_success(label, data)

        {:error, reason} ->
          %{label: label, status: :error, error: inspect(reason), rows: [], columns: []}
      end
    end)
    |> Enum.sort_by(& &1.label)
  end

  defp parse_success(label, data) when is_binary(data) do
    case Jason.decode(data) do
      {:ok, rows} when is_list(rows) and length(rows) > 0 ->
        cols = rows |> List.first() |> Map.keys() |> prioritize_columns()
        %{label: label, status: :ok, rows: rows, columns: cols}

      {:ok, map} when is_map(map) ->
        rows = Enum.map(map, fn {k, v} -> %{"field" => k, "value" => format_cell(v)} end)
        %{label: label, status: :ok, rows: rows, columns: ["field", "value"]}

      _ ->
        %{label: label, status: :ok, rows: [%{"output" => data}], columns: ["output"]}
    end
  end

  defp parse_success(label, data) when is_list(data) and length(data) > 0 do
    rows =
      Enum.map(data, fn
        %{__struct__: _} = s -> Map.from_struct(s) |> stringify_keys()
        m when is_map(m) -> stringify_keys(m)
        other -> %{"value" => inspect(other)}
      end)

    cols = rows |> List.first() |> Map.keys() |> prioritize_columns()
    %{label: label, status: :ok, rows: rows, columns: cols}
  end

  defp parse_success(label, data) when is_map(data) and not is_struct(data) do
    # Check if this is a port-keyed output map (e.g., %{hotspots: [...]})
    # After ResultSerializer, keys are strings and structs are plain maps
    values = Map.values(data)

    case values do
      [list] when is_list(list) and length(list) > 0 ->
        # Single port output with a list — display the list as a table
        parse_success(label, list)

      [single] when is_map(single) ->
        # Single port output with a map — display as key-value
        rows =
          Enum.map(single, fn {k, v} -> %{"field" => to_string(k), "value" => format_cell(v)} end)

        %{label: label, status: :ok, rows: rows, columns: ["field", "value"]}

      _ ->
        # Multi-port or other map — show as key-value pairs
        rows =
          Enum.map(data, fn {k, v} -> %{"field" => to_string(k), "value" => format_cell(v)} end)

        %{label: label, status: :ok, rows: rows, columns: ["field", "value"]}
    end
  end

  defp parse_success(label, data) do
    %{label: label, status: :ok, rows: [%{"output" => inspect(data)}], columns: ["output"]}
  end

  defp stringify_keys(map) do
    Map.new(map, fn {k, v} -> {to_string(k), v} end)
  end

  # Put the most important columns first
  defp prioritize_columns(cols) do
    priority =
      ~w(file path name entity label author changes revisions complexity score risk normalized_score percentile)

    {front, rest} =
      Enum.split_with(cols, fn c ->
        String.downcase(c) in priority
      end)

    sorted_front =
      Enum.sort_by(front, fn c ->
        Enum.find_index(priority, &(&1 == String.downcase(c))) || 999
      end)

    sorted_front ++ Enum.sort(rest)
  end

  # ── Run persistence ─────────────────────────────────────────

  defp current_user(%{assigns: %{current_scope: %{user: %{id: _} = user}}}), do: user
  defp current_user(_), do: nil

  defp maybe_create_run(socket, template, repo_url) do
    case current_user(socket) do
      nil ->
        nil

      user ->
        case Pipelines.create_run(template.id, user.id, repo_url) do
          {:ok, run} -> run
          {:error, _} -> nil
        end
    end
  end

  defp persist_run_results(nil, _results), do: :ok

  defp persist_run_results(%PipelineRun{} = run, results) do
    storable = ResultSerializer.serialize_for_storage(results)

    failures =
      results
      |> Map.values()
      |> Enum.filter(fn
        {:error, _} -> true
        _ -> false
      end)

    {status, error} =
      case failures do
        [] ->
          {"completed", nil}

        _ ->
          error_msg = failures |> Enum.map(fn {:error, r} -> inspect(r) end) |> Enum.join("; ")
          {"failed", error_msg}
      end

    Pipelines.finish_run(run, status, storable, error)
  end

  # ── Helpers ──────────────────────────────────────────────

  defp submit_label(:idle), do: "Run Analysis"
  defp submit_label(:running), do: "Running..."
  defp submit_label(:done), do: "Run Again"

  defp status_class({:running, _}), do: "running"
  defp status_class(:running), do: "running"
  defp status_class(:done), do: "done"
  defp status_class(:error), do: "error"
  defp status_class(_), do: ""

  defp status_text({:running, msg}) when is_binary(msg), do: msg
  defp status_text(_), do: nil

  defp status_icon({:running, _}), do: status_icon(:running)

  defp status_icon(:running),
    do:
      raw(
        ~s[<svg class="status-spin" width="14" height="14" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="6" stroke="currentColor" stroke-width="2" stroke-dasharray="28" stroke-dashoffset="8"/></svg>]
      )

  defp status_icon(:done),
    do:
      raw(
        ~s[<svg width="14" height="14" viewBox="0 0 16 16" fill="none"><path d="M3 8.5L6.5 12L13 4" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/></svg>]
      )

  defp status_icon(:error),
    do:
      raw(
        ~s[<svg width="14" height="14" viewBox="0 0 16 16" fill="none"><path d="M4 4L12 12M12 4L4 12" stroke="currentColor" stroke-width="2" stroke-linecap="round"/></svg>]
      )

  defp status_icon(_),
    do:
      raw(
        ~s[<svg width="14" height="14" viewBox="0 0 16 16" fill="none"><circle cx="8" cy="8" r="5" stroke="currentColor" stroke-width="1.5"/></svg>]
      )

  defp node_label(node_id, %Pipeline{nodes: nodes}) do
    case Map.get(nodes, node_id) do
      nil -> node_id
      node -> node.label
    end
  end

  defp node_label(node_id, _), do: node_id

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
  defp format_cell(v) when is_atom(v), do: Atom.to_string(v)
  defp format_cell(v) when is_list(v), do: Enum.join(Enum.map(v, &to_string/1), ", ")
  defp format_cell(v) when is_map(v), do: inspect(v, limit: 5)
  defp format_cell(v), do: inspect(v)
end
