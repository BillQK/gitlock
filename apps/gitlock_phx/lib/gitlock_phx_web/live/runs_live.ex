defmodule GitlockPhxWeb.RunsLive do
  use GitlockPhxWeb, :live_view

  alias GitlockPhx.Pipelines

  @impl true
  def mount(_params, _session, socket) do
    user = current_user(socket)

    runs = if user, do: Pipelines.list_runs_for_user(user.id), else: []

    {:ok,
     assign(socket,
       runs: runs,
       page_title: "Run History"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="runs-page">
      <div class="runs-container">
        <header class="runs-header">
          <h1>Run History</h1>
          <p class="runs-subtitle">Past pipeline executions and their results.</p>
        </header>

        <%= if current_user(assigns) do %>
          <%= if length(@runs) > 0 do %>
            <div class="runs-list">
              <%= for run <- @runs do %>
                <.link navigate={~p"/runs/#{run.id}"} class="run-row">
                  <div class="run-row-main">
                    <span class={"run-status-dot #{run.status}"}></span>
                    <div class="run-info">
                      <span class="run-pipeline-name">{pipeline_name(run)}</span>
                      <span class="run-repo">{run.repo_url}</span>
                    </div>
                  </div>
                  <div class="run-row-meta">
                    <span class={"run-status-label #{run.status}"}>{run.status}</span>
                    <span class="run-duration">{format_duration(run)}</span>
                    <span class="run-time">{format_time(run.started_at || run.inserted_at)}</span>
                  </div>
                </.link>
              <% end %>
            </div>
          <% else %>
            <div class="runs-empty">
              <p>No runs yet.</p>
              <p>
                <.link navigate={~p"/analyze"}>Run an analysis</.link>
                or <.link navigate={~p"/workflows"}>execute a pipeline</.link>
                to see results here.
              </p>
            </div>
          <% end %>
        <% else %>
          <div class="runs-empty">
            <p>
              <.link navigate={~p"/users/log-in"}>Log in</.link> to see your run history.
            </p>
          </div>
        <% end %>
      </div>
    </div>
    """
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    user = current_user(socket)

    if user do
      run = Pipelines.get_run!(String.to_integer(id))

      if run.user_id == user.id do
        GitlockPhx.Repo.delete(run)
        runs = Pipelines.list_runs_for_user(user.id)
        {:noreply, socket |> assign(runs: runs) |> put_flash(:info, "Run deleted")}
      else
        {:noreply, put_flash(socket, :error, "Not authorized")}
      end
    else
      {:noreply, put_flash(socket, :error, "Log in to manage runs")}
    end
  end

  # ── Helpers ──────────────────────────────────────────────────

  defp current_user(%{assigns: %{current_scope: %{user: %{id: _} = user}}}), do: user
  defp current_user(_), do: nil

  defp pipeline_name(%{pipeline: %{name: name}}), do: name
  defp pipeline_name(_), do: "Unknown Pipeline"

  defp format_duration(%{started_at: nil}), do: ""
  defp format_duration(%{completed_at: nil}), do: "running..."

  defp format_duration(%{started_at: started, completed_at: completed}) do
    diff = DateTime.diff(completed, started, :millisecond)

    cond do
      diff < 1_000 -> "#{diff}ms"
      diff < 60_000 -> "#{Float.round(diff / 1_000, 1)}s"
      true -> "#{div(diff, 60_000)}m #{rem(div(diff, 1_000), 60)}s"
    end
  end

  defp format_time(nil), do: ""

  defp format_time(dt) do
    now = DateTime.utc_now()
    diff = DateTime.diff(now, dt, :second)

    cond do
      diff < 60 -> "just now"
      diff < 3600 -> "#{div(diff, 60)}m ago"
      diff < 86400 -> "#{div(diff, 3600)}h ago"
      diff < 604_800 -> "#{div(diff, 86400)}d ago"
      true -> Calendar.strftime(dt, "%b %d, %Y %H:%M")
    end
  end
end
