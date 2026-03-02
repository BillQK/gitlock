defmodule GitlockPhx.Pipelines do
  @moduledoc """
  Context for managing saved pipelines and execution runs.
  Bridges between the in-memory GitlockWorkflows.Pipeline and the database.
  """

  import Ecto.Query
  alias GitlockPhx.Repo
  alias GitlockPhx.Pipelines.{SavedPipeline, PipelineRun}
  alias GitlockWorkflows.{Pipeline, Node, Edge, Port, NodeCatalog, Serializer, Templates}

  # ── Pipeline CRUD ────────────────────────────────────────────

  def list_pipelines(user_id) do
    SavedPipeline
    |> where(user_id: ^user_id, is_template: false)
    |> order_by(desc: :updated_at)
    |> Repo.all()
  end

  def list_templates do
    SavedPipeline
    |> where(is_template: true)
    |> order_by(:name)
    |> Repo.all()
  end

  def get_pipeline!(id), do: Repo.get!(SavedPipeline, id)

  def save_pipeline(user_id, %Pipeline{} = pipeline) do
    config = Serializer.to_map(pipeline)

    %SavedPipeline{}
    |> SavedPipeline.changeset(%{
      name: pipeline.name,
      description: pipeline.description,
      config: config,
      user_id: user_id
    })
    |> Repo.insert()
  end

  def update_pipeline(%SavedPipeline{} = saved, %Pipeline{} = pipeline) do
    config = Serializer.to_map(pipeline)

    saved
    |> SavedPipeline.changeset(%{
      name: pipeline.name,
      description: pipeline.description,
      config: config
    })
    |> Repo.update()
  end

  def delete_pipeline(%SavedPipeline{} = saved) do
    Repo.delete(saved)
  end

  @doc "Converts a saved pipeline DB record back to a workflow Pipeline struct."
  def to_workflow(%SavedPipeline{config: config}) do
    hydrate_pipeline(config)
  end

  # ── Pipeline Runs ────────────────────────────────────────────

  def create_run(pipeline_id, user_id, repo_url) do
    %PipelineRun{}
    |> PipelineRun.changeset(%{
      pipeline_id: pipeline_id,
      user_id: user_id,
      repo_url: repo_url,
      status: "running",
      started_at: DateTime.utc_now()
    })
    |> Repo.insert()
  end

  def complete_run(%PipelineRun{} = run, results) do
    run
    |> PipelineRun.changeset(%{
      status: "completed",
      results: results,
      completed_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  def fail_run(%PipelineRun{} = run, error) do
    run
    |> PipelineRun.changeset(%{
      status: "failed",
      error: to_string(error),
      completed_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  @doc "Finishes a run with status, results, and optional error. Stores partial results even on failure."
  def finish_run(%PipelineRun{} = run, status, results, error \\ nil) do
    run
    |> PipelineRun.changeset(%{
      status: status,
      results: results,
      error: if(error, do: to_string(error)),
      completed_at: DateTime.utc_now()
    })
    |> Repo.update()
  end

  def list_runs(pipeline_id) do
    PipelineRun
    |> where(pipeline_id: ^pipeline_id)
    |> order_by(desc: :inserted_at)
    |> limit(20)
    |> Repo.all()
  end

  def list_runs_for_user(user_id, opts \\ []) do
    limit_val = Keyword.get(opts, :limit, 50)

    PipelineRun
    |> where(user_id: ^user_id)
    |> order_by(desc: :inserted_at)
    |> limit(^limit_val)
    |> preload(:pipeline)
    |> Repo.all()
  end

  def get_run!(id), do: Repo.get!(PipelineRun, id)

  def get_run_with_pipeline!(id) do
    PipelineRun
    |> preload(:pipeline)
    |> Repo.get!(id)
  end

  # ── Templates ────────────────────────────────────────────────

  @doc "Seeds built-in pipeline templates. Idempotent."
  def seed_templates! do
    for template_info <- Templates.list() do
      pipeline = Templates.build(template_info.id)
      now = DateTime.utc_now() |> DateTime.truncate(:second)
      config = Serializer.to_map(pipeline)

      case Repo.one(
             from p in SavedPipeline,
               where: p.name == ^template_info.name and p.is_template == true
           ) do
        nil ->
          Repo.insert!(%SavedPipeline{
            name: template_info.name,
            description: template_info.description,
            config: config,
            is_template: true,
            user_id: nil,
            inserted_at: now,
            updated_at: now
          })

        existing ->
          existing
          |> SavedPipeline.changeset(%{
            description: template_info.description,
            config: config
          })
          |> Repo.update!()
      end
    end
  end

  # ── Hydration ────────────────────────────────────────────────

  defp hydrate_pipeline(config) when is_map(config) do
    pipeline = Pipeline.new(config["name"] || "Untitled")
    pipeline = %{pipeline | id: config["id"] || pipeline.id}

    nodes =
      (config["nodes"] || %{})
      |> Enum.map(fn {_id, node_data} -> hydrate_node(node_data) end)
      |> Enum.reject(&is_nil/1)

    pipeline =
      Enum.reduce(nodes, pipeline, fn node, acc ->
        case Pipeline.add_node(acc, node) do
          {:error, _} -> acc
          p -> p
        end
      end)

    edges =
      (config["edges"] || %{})
      |> Enum.map(fn {_id, edge_data} -> hydrate_edge(edge_data, pipeline) end)
      |> Enum.reject(&is_nil/1)

    Enum.reduce(edges, pipeline, fn edge, acc ->
      case Pipeline.add_edge(acc, edge) do
        {:error, _} -> acc
        p -> p
      end
    end)
  end

  defp hydrate_node(data) do
    type = data["type"] |> to_string() |> String.to_existing_atom()
    [x, y] = data["position"] || [0, 0]

    case NodeCatalog.get_type(type) do
      {:ok, type_def} ->
        %Node{
          id: data["id"],
          type: type,
          label: data["label"] || type_def.label,
          config: data["config"] || %{},
          position: {x, y},
          input_ports: rebuild_ports(data["input_ports"], type_def.input_ports),
          output_ports: rebuild_ports(data["output_ports"], type_def.output_ports)
        }

      {:error, _} ->
        nil
    end
  rescue
    _ -> nil
  end

  # Rebuild ports from the catalog definition (source of truth),
  # preserving stored port IDs where names match so edges stay valid.
  defp rebuild_ports(stored_ports, catalog_ports) do
    stored_by_name =
      (stored_ports || [])
      |> Map.new(fn p -> {p["name"], p["id"]} end)

    Enum.map(catalog_ports, fn catalog_port ->
      optional = Map.get(catalog_port, :optional, false)

      # Reuse stored ID if this port existed before, otherwise generate new
      id =
        Map.get(stored_by_name, catalog_port.name) ||
          :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)

      %Port{
        id: id,
        name: catalog_port.name,
        data_type: catalog_port.data_type,
        optional: optional
      }
    end)
  end

  defp hydrate_edge(data, _pipeline) do
    %Edge{
      id: data["id"] || :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower),
      source_node_id: data["source_node_id"],
      source_port_id: data["source_port_id"],
      target_node_id: data["target_node_id"],
      target_port_id: data["target_port_id"]
    }
  rescue
    _ -> nil
  end
end
