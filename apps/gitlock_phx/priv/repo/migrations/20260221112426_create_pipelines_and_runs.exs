defmodule GitlockPhx.Repo.Migrations.CreatePipelinesAndRuns do
  use Ecto.Migration

  def change do
    create table(:pipelines) do
      add :user_id, references(:users, on_delete: :delete_all)
      add :name, :string, null: false
      add :description, :text, default: ""
      add :config, :map, null: false, default: %{}
      add :is_template, :boolean, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:pipelines, [:user_id])
    create index(:pipelines, [:is_template])

    create table(:pipeline_runs) do
      add :pipeline_id, references(:pipelines, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :repo_url, :string, null: false
      add :status, :string, null: false, default: "running"
      add :results, :map, default: %{}
      add :error, :text
      add :started_at, :utc_datetime
      add :completed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:pipeline_runs, [:pipeline_id])
    create index(:pipeline_runs, [:user_id])
    create index(:pipeline_runs, [:status])
  end
end
