defmodule GitlockPhxWeb.WorkflowLive do
  use GitlockPhxWeb, :live_view

  alias GitlockWorkflows.{Pipeline, Node, Edge, Serializer, Executor}
  alias GitlockPhx.Pipelines
  alias GitlockPhxWeb.ResultSerializer

  require Logger

  @impl true
  def mount(params, _session, socket) do
    templates = Pipelines.list_templates()
    user = current_user(socket)

    {pipeline, saved_id} = load_initial_pipeline(params, user)

    my_pipelines =
      if user, do: Pipelines.list_pipelines(user.id), else: []

    {:ok,
     assign(socket,
       pipeline: pipeline,
       saved_pipeline_id: saved_id,
       dirty: false,
       templates: templates,
       my_pipelines: my_pipelines,
       validation: :ok,
       execution: :idle,
       node_progress: %{},
       results: nil,
       current_run: nil,
       show_save_dialog: false,
       save_name: pipeline.name,
       page_title: pipeline.name
     )}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    user = current_user(socket)

    case params do
      %{"id" => id} ->
        case load_saved_pipeline(id, user) do
          {:ok, pipeline, saved_id} ->
            {:noreply,
             socket
             |> assign(
               pipeline: pipeline,
               saved_pipeline_id: saved_id,
               dirty: false,
               save_name: pipeline.name,
               page_title: pipeline.name
             )
             |> push_pipeline_state()}

          :error ->
            {:noreply,
             socket
             |> put_flash(:error, "Pipeline not found")
             |> push_navigate(to: ~p"/workflows")}
        end

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="workflow-page">
      <header class="workflow-header">
        <div class="workflow-title-group">
          <h1
            contenteditable="true"
            phx-blur="rename"
            phx-hook="ContentEditable"
            id="pipeline-name"
            spellcheck="false"
          >{@pipeline.name}</h1>
          <%= if @dirty do %>
            <span class="dirty-badge">Unsaved</span>
          <% end %>
          <%= if @saved_pipeline_id do %>
            <span class="saved-badge">Saved</span>
          <% end %>
        </div>

        <div class="workflow-actions">
          <form phx-change="load_template" class="template-dropdown">
            <select name="template_id" class="template-select">
              <option value="">Load template</option>
              <optgroup label="Templates">
                <%= for tpl <- @templates do %>
                  <option value={"tpl:#{tpl.id}"}>{tpl.name}</option>
                <% end %>
              </optgroup>
              <%= if length(@my_pipelines) > 0 do %>
                <optgroup label="My Pipelines">
                  <%= for p <- @my_pipelines do %>
                    <option value={"saved:#{p.id}"}>{p.name}</option>
                  <% end %>
                </optgroup>
              <% end %>
            </select>
          </form>

          <span class={["validation-badge", validation_class(@validation)]}>
            {validation_label(@validation)}
          </span>
          <button phx-click="validate" class="btn btn-secondary">Validate</button>

          <%= if current_user(assigns) do %>
            <button phx-click="save" class="btn btn-secondary">
              <%= if @saved_pipeline_id, do: "Save", else: "Save As" %>
            </button>
          <% end %>

          <button
            phx-click="execute"
            class={["btn btn-execute", execution_class(@execution)]}
            disabled={@execution == :running}
          >
            {execution_label(@execution)}
          </button>
        </div>
      </header>

      <%= if @show_save_dialog do %>
        <div class="save-dialog-overlay" phx-click="cancel_save">
          <div class="save-dialog" phx-click-away="cancel_save">
            <h3>Save Pipeline</h3>
            <form phx-submit="confirm_save">
              <div class="save-field">
                <label for="save-name">Name</label>
                <input
                  type="text"
                  id="save-name"
                  name="name"
                  value={@save_name}
                  autofocus
                  class="save-input"
                  phx-debounce="100"
                />
              </div>
              <div class="save-actions">
                <button type="button" phx-click="cancel_save" class="btn btn-secondary">Cancel</button>
                <button type="submit" class="btn btn-execute">Save</button>
              </div>
            </form>
          </div>
        </div>
      <% end %>

      <div id="workflow-canvas" phx-hook="WorkflowCanvas" phx-update="ignore" class="workflow-canvas">
        <!-- Svelte mounts here -->
      </div>
    </div>
    """
  end

  # ── Events ───────────────────────────────────────────────────

  @impl true
  def handle_event("request_state", _params, socket) do
    socket =
      socket
      |> push_pipeline_state()
      |> push_catalog()

    {:noreply, socket}
  end

  def handle_event("load_template", %{"template_id" => ""}, socket), do: {:noreply, socket}

  def handle_event("load_template", %{"template_id" => "tpl:" <> id}, socket) do
    template = Pipelines.get_pipeline!(String.to_integer(id))
    pipeline = Pipelines.to_workflow(template)

    {:noreply,
     socket
     |> assign(
       pipeline: pipeline,
       saved_pipeline_id: nil,
       dirty: false,
       validation: :ok,
       execution: :idle,
       results: nil,
       node_progress: %{},
       save_name: pipeline.name,
       page_title: pipeline.name
     )
     |> push_pipeline_state()}
  end

  def handle_event("load_template", %{"template_id" => "saved:" <> id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/workflows/#{id}")}
  end

  # Back-compat for old format
  def handle_event("load_template", %{"template_id" => id}, socket) do
    template = Pipelines.get_pipeline!(String.to_integer(id))
    pipeline = Pipelines.to_workflow(template)

    {:noreply,
     socket
     |> assign(
       pipeline: pipeline,
       saved_pipeline_id: nil,
       dirty: false,
       validation: :ok,
       execution: :idle,
       results: nil,
       node_progress: %{},
       save_name: pipeline.name
     )
     |> push_pipeline_state()}
  end

  def handle_event("rename", %{"value" => name}, socket) do
    name = String.trim(name)
    name = if name == "", do: "Untitled Pipeline", else: name
    pipeline = %{socket.assigns.pipeline | name: name}

    {:noreply, assign(socket, pipeline: pipeline, save_name: name, dirty: true, page_title: name)}
  end

  def handle_event("add_node", %{"type_id" => type_id, "position" => pos}, socket) do
    type_atom = String.to_existing_atom(type_id)
    position = {pos["x"], pos["y"]}

    case Node.new(type_atom, position: position) do
      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Unknown node type: #{type_id}")}

      node ->
        case Pipeline.add_node(socket.assigns.pipeline, node) do
          {:error, reason} ->
            {:noreply, put_flash(socket, :error, "Cannot add node: #{reason}")}

          pipeline ->
            {:noreply,
             socket
             |> assign(pipeline: pipeline, execution: :idle, results: nil, dirty: true)
             |> push_pipeline_state()}
        end
    end
  end

  def handle_event("connect", params, socket) do
    edge =
      Edge.new(
        params["source_node_id"],
        params["source_port_id"],
        params["target_node_id"],
        params["target_port_id"]
      )

    case Pipeline.add_edge(socket.assigns.pipeline, edge) do
      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Cannot connect: #{reason}")}

      pipeline ->
        {:noreply, socket |> assign(pipeline: pipeline, dirty: true) |> push_pipeline_state()}
    end
  end

  def handle_event("node_moved", %{"node_id" => node_id, "position" => pos}, socket) do
    pipeline = socket.assigns.pipeline
    position = {pos["x"], pos["y"]}

    case Map.fetch(pipeline.nodes, node_id) do
      {:ok, node} ->
        updated_node = %{node | position: position}
        updated_nodes = Map.put(pipeline.nodes, node_id, updated_node)
        pipeline = %{pipeline | nodes: updated_nodes}
        {:noreply, assign(socket, pipeline: pipeline, dirty: true)}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("update_node_config", %{"node_id" => node_id, "config" => config}, socket) do
    pipeline = socket.assigns.pipeline

    case Map.fetch(pipeline.nodes, node_id) do
      {:ok, node} ->
        merged_config = Map.merge(node.config, normalize_config(config))
        updated_node = %{node | config: merged_config}
        updated_nodes = Map.put(pipeline.nodes, node_id, updated_node)
        pipeline = %{pipeline | nodes: updated_nodes}
        {:noreply, assign(socket, pipeline: pipeline, dirty: true)}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("delete_elements", %{"nodes" => node_ids, "edges" => edge_ids}, socket) do
    pipeline =
      socket.assigns.pipeline
      |> remove_edges(edge_ids)
      |> remove_nodes(node_ids)

    {:noreply, socket |> assign(pipeline: pipeline, dirty: true) |> push_pipeline_state()}
  end

  def handle_event("validate", _params, socket) do
    validation = Pipeline.validate(socket.assigns.pipeline)
    {:noreply, assign(socket, validation: validation)}
  end

  def handle_event("save", _params, socket) do
    user = current_user(socket)

    cond do
      is_nil(user) ->
        {:noreply, put_flash(socket, :error, "Log in to save pipelines")}

      socket.assigns.saved_pipeline_id ->
        # Update existing
        do_update_pipeline(socket, user)

      true ->
        # Show save-as dialog
        {:noreply, assign(socket, show_save_dialog: true, save_name: socket.assigns.pipeline.name)}
    end
  end

  def handle_event("confirm_save", %{"name" => name}, socket) do
    user = current_user(socket)
    name = String.trim(name)
    name = if name == "", do: "Untitled Pipeline", else: name

    pipeline = %{socket.assigns.pipeline | name: name}

    case Pipelines.save_pipeline(user.id, pipeline) do
      {:ok, saved} ->
        my_pipelines = Pipelines.list_pipelines(user.id)

        {:noreply,
         socket
         |> assign(
           pipeline: pipeline,
           saved_pipeline_id: saved.id,
           dirty: false,
           show_save_dialog: false,
           my_pipelines: my_pipelines,
           save_name: name,
           page_title: name
         )
         |> put_flash(:info, "Pipeline saved")
         |> push_patch(to: ~p"/workflows/#{saved.id}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(show_save_dialog: false)
         |> put_flash(:error, "Save failed: #{inspect_errors(changeset)}")}
    end
  end

  def handle_event("cancel_save", _params, socket) do
    {:noreply, assign(socket, show_save_dialog: false)}
  end

  def handle_event("execute", _params, socket) do
    pipeline = socket.assigns.pipeline

    repo_url = find_repo_url(pipeline)

    cond do
      repo_url == nil or repo_url == "" ->
        {:noreply, put_flash(socket, :error, "Configure a Repository URL on the Git Log node")}

      match?({:error, _}, Pipeline.validate(pipeline)) ->
        validation = Pipeline.validate(pipeline)

        {:noreply,
         socket
         |> assign(validation: validation)
         |> put_flash(:error, "Fix validation errors before executing")}

      true ->
        user = current_user(socket)
        {socket, run} = maybe_create_run(socket, user, pipeline, repo_url)

        Executor.run(pipeline, repo_url, self(), %{format: "json"})

        {:noreply,
         socket
         |> assign(
           validation: :ok,
           execution: :running,
           node_progress: %{},
           results: nil,
           current_run: run
         )
         |> push_event("execution_started", %{})}
    end
  end

  # ── Async execution messages ─────────────────────────────────

  @impl true
  def handle_info({:pipeline_progress, node_id, :running}, socket) do
    progress = Map.put(socket.assigns.node_progress, node_id, :running)

    {:noreply,
     socket
     |> assign(node_progress: progress)
     |> push_event("node_progress", %{node_id: node_id, status: "running"})}
  end

  def handle_info({:pipeline_progress, node_id, {:status, message}}, socket) do
    {:noreply,
     push_event(socket, "node_progress", %{node_id: node_id, status: "running", status_text: message})}
  end

  def handle_info({:pipeline_progress, node_id, {:done, result}}, socket) do
    progress = Map.put(socket.assigns.node_progress, node_id, :done)
    serialized = ResultSerializer.serialize(result)
    results = Map.put(socket.assigns.results || %{}, node_id, serialized)

    {:noreply,
     socket
     |> assign(node_progress: progress, results: results)
     |> push_event("node_progress", %{node_id: node_id, status: "done", result: serialized})}
  end

  def handle_info({:pipeline_progress, node_id, {:error, reason}}, socket) do
    progress = Map.put(socket.assigns.node_progress, node_id, {:error, reason})

    {:noreply,
     socket
     |> assign(node_progress: progress)
     |> push_event("node_progress", %{
       node_id: node_id,
       status: "error",
       error: inspect(reason)
     })}
  end

  def handle_info({:pipeline_complete, results}, socket) do
    {successes, failures} =
      results |> Map.values() |> Enum.split_with(fn {:ok, _} -> true; _ -> false end)

    {level, message} =
      case {length(successes), length(failures)} do
        {s, 0} -> {:info, "Pipeline complete — #{s} step(s) succeeded"}
        {0, f} -> {:error, "Pipeline failed — #{f} step(s) failed"}
        {s, f} -> {:warning, "Pipeline done — #{s} succeeded, #{f} failed"}
      end

    serialized_results = ResultSerializer.serialize_results(results)

    # Persist run results
    persist_run_results(socket.assigns[:current_run], results, failures)

    {:noreply,
     socket
     |> assign(execution: :done, results: serialized_results, current_run: nil)
     |> put_flash(level, message)}
  end

  # ── Run persistence helpers ──────────────────────────────────

  defp maybe_create_run(socket, nil, _pipeline, _repo_url), do: {socket, nil}

  defp maybe_create_run(socket, user, pipeline, repo_url) do
    {socket, pipeline_id} = ensure_saved(socket, user, pipeline)

    if pipeline_id do
      case Pipelines.create_run(pipeline_id, user.id, repo_url) do
        {:ok, run} -> {socket, run}
        {:error, _} -> {socket, nil}
      end
    else
      {socket, nil}
    end
  end

  defp ensure_saved(socket, user, pipeline) do
    case socket.assigns.saved_pipeline_id do
      nil ->
        case Pipelines.save_pipeline(user.id, pipeline) do
          {:ok, saved} ->
            my_pipelines = Pipelines.list_pipelines(user.id)

            socket =
              assign(socket,
                saved_pipeline_id: saved.id,
                dirty: false,
                my_pipelines: my_pipelines
              )

            {socket, saved.id}

          {:error, _} ->
            {socket, nil}
        end

      id ->
        if socket.assigns.dirty do
          saved = Pipelines.get_pipeline!(id)
          Pipelines.update_pipeline(saved, pipeline)
          {assign(socket, dirty: false), id}
        else
          {socket, id}
        end
    end
  end

  defp persist_run_results(nil, _results, _failures), do: :ok

  defp persist_run_results(run, results, failures) do
    storable = ResultSerializer.serialize_for_storage(results)

    {status, error} =
      case failures do
        [] ->
          {"completed", nil}

        _ ->
          error_msg =
            failures
            |> Enum.map(fn {:error, r} -> inspect(r) end)
            |> Enum.join("; ")

          {"failed", error_msg}
      end

    Pipelines.finish_run(run, status, storable, error)
  end

  # ── Private helpers ──────────────────────────────────────────

  defp current_user(%{assigns: %{current_scope: %{user: %{id: _} = user}}}), do: user
  defp current_user(_), do: nil

  defp load_initial_pipeline(%{"id" => id}, user) do
    case load_saved_pipeline(id, user) do
      {:ok, pipeline, saved_id} -> {pipeline, saved_id}
      :error -> {Pipeline.new("New Pipeline"), nil}
    end
  end

  defp load_initial_pipeline(_params, _user) do
    {Pipeline.new("New Pipeline"), nil}
  end

  defp load_saved_pipeline(id, _user) do
    saved = Pipelines.get_pipeline!(String.to_integer(id))
    pipeline = Pipelines.to_workflow(saved)

    if saved.is_template do
      # Templates load as a new unsaved copy
      {:ok, pipeline, nil}
    else
      {:ok, pipeline, saved.id}
    end
  rescue
    Ecto.NoResultsError -> :error
  end

  defp do_update_pipeline(socket, _user) do
    saved = Pipelines.get_pipeline!(socket.assigns.saved_pipeline_id)

    case Pipelines.update_pipeline(saved, socket.assigns.pipeline) do
      {:ok, _saved} ->
        {:noreply,
         socket
         |> assign(dirty: false)
         |> put_flash(:info, "Pipeline saved")}

      {:error, changeset} ->
        {:noreply, put_flash(socket, :error, "Save failed: #{inspect_errors(changeset)}")}
    end
  end

  defp find_repo_url(%Pipeline{nodes: nodes}) do
    nodes
    |> Map.values()
    |> Enum.find(&(&1.type == :git_log))
    |> case do
      nil -> nil
      node -> Map.get(node.config, "repo_url") || Map.get(node.config, :repo_url)
    end
  end

  defp normalize_config(config) when is_map(config) do
    Map.new(config, fn
      {k, v} when is_binary(v) and byte_size(v) == 0 -> {k, nil}
      {k, v} -> {k, v}
    end)
  end

  defp push_pipeline_state(socket) do
    push_event(socket, "pipeline_state", %{
      pipeline: Serializer.to_map(socket.assigns.pipeline)
    })
  end

  defp push_catalog(socket) do
    push_event(socket, "catalog", %{catalog: Serializer.catalog_to_list()})
  end

  defp remove_nodes(pipeline, node_ids) do
    Enum.reduce(node_ids, pipeline, &Pipeline.remove_node(&2, &1))
  end

  defp remove_edges(pipeline, edge_ids) do
    Enum.reduce(edge_ids, pipeline, &Pipeline.remove_edge(&2, &1))
  end

  defp inspect_errors(%Ecto.Changeset{} = cs) do
    Ecto.Changeset.traverse_errors(cs, fn {msg, _opts} -> msg end) |> inspect()
  end

  defp inspect_errors(other), do: inspect(other)

  defp validation_class(:ok), do: "valid"
  defp validation_class({:error, _}), do: "invalid"

  defp validation_label(:ok), do: "Valid"
  defp validation_label({:error, errors}), do: "#{length(errors)} issue(s)"

  defp execution_class(:idle), do: ""
  defp execution_class(:running), do: "running"
  defp execution_class(:done), do: "done"

  defp execution_label(:idle), do: "Execute"
  defp execution_label(:running), do: "Running..."
  defp execution_label(:done), do: "Done"
end
