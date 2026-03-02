defmodule GitlockPhxWeb.PipelinesLive do
  use GitlockPhxWeb, :live_view

  alias GitlockPhx.Pipelines

  @impl true
  def mount(_params, _session, socket) do
    user = current_user(socket)

    pipelines = if user, do: Pipelines.list_pipelines(user.id), else: []
    templates = Pipelines.list_templates()

    {:ok,
     assign(socket,
       pipelines: pipelines,
       templates: templates,
       page_title: "My Pipelines"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="pipelines-page">
      <div class="pipelines-container">
        <header class="pipelines-header">
          <h1>Pipelines</h1>
          <.link navigate={~p"/workflows"} class="btn btn-execute">
            + New Pipeline
          </.link>
        </header>

        <%= if current_user(assigns) do %>
          <%= if length(@pipelines) > 0 do %>
            <section class="pipelines-section">
              <h2>My Pipelines</h2>
              <div class="pipelines-grid">
                <%= for p <- @pipelines do %>
                  <div class="pipeline-card">
                    <div class="pipeline-card-body">
                      <h3>
                        <.link navigate={~p"/workflows/#{p.id}"}>{p.name}</.link>
                      </h3>
                      <p class="pipeline-desc">{p.description || "No description"}</p>
                      <div class="pipeline-meta">
                        <span>{node_count(p)} nodes</span>
                        <span>Updated {format_time(p.updated_at)}</span>
                      </div>
                    </div>
                    <div class="pipeline-card-actions">
                      <.link navigate={~p"/workflows/#{p.id}"} class="btn btn-secondary btn-sm">
                        Open
                      </.link>
                      <button
                        phx-click="delete"
                        phx-value-id={p.id}
                        data-confirm="Delete this pipeline?"
                        class="btn btn-danger btn-sm"
                      >
                        Delete
                      </button>
                    </div>
                  </div>
                <% end %>
              </div>
            </section>
          <% else %>
            <section class="pipelines-empty">
              <p>No saved pipelines yet.</p>
              <p>
                <.link navigate={~p"/workflows"}>Create a new pipeline</.link>
                or load a template to get started.
              </p>
            </section>
          <% end %>
        <% else %>
          <section class="pipelines-empty">
            <p>
              <.link navigate={~p"/users/log-in"}>Log in</.link> to save and manage your pipelines.
            </p>
          </section>
        <% end %>

        <section class="pipelines-section">
          <h2>Templates</h2>
          <div class="pipelines-grid">
            <%= for t <- @templates do %>
              <div class="pipeline-card template">
                <div class="pipeline-card-body">
                  <h3>
                    <.link navigate={~p"/workflows"} phx-click="load_template" phx-value-id={t.id}>
                      {t.name}
                    </.link>
                  </h3>
                  <p class="pipeline-desc">{t.description}</p>
                  <div class="pipeline-meta">
                    <span>{node_count(t)} nodes</span>
                    <span class="template-badge">Template</span>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        </section>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = current_user(socket)

    if user do
      saved = Pipelines.get_pipeline!(String.to_integer(id))

      if saved.user_id == user.id do
        Pipelines.delete_pipeline(saved)
        pipelines = Pipelines.list_pipelines(user.id)
        {:noreply, socket |> assign(pipelines: pipelines) |> put_flash(:info, "Pipeline deleted")}
      else
        {:noreply, put_flash(socket, :error, "Not authorized")}
      end
    else
      {:noreply, put_flash(socket, :error, "Log in to manage pipelines")}
    end
  end

  defp current_user(%{assigns: %{current_scope: %{user: user}}}) when not is_nil(user), do: user
  defp current_user(_), do: nil

  defp node_count(%{config: %{"nodes" => nodes}}) when is_map(nodes), do: map_size(nodes)

  defp node_count(%{config: config}) when is_map(config) do
    case Map.get(config, :nodes) || Map.get(config, "nodes") do
      nodes when is_map(nodes) -> map_size(nodes)
      _ -> 0
    end
  end

  defp node_count(_), do: 0

  defp format_time(dt) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(dt, "%b %d, %Y")
    end
  end
end
