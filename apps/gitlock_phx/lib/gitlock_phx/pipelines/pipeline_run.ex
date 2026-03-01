defmodule GitlockPhx.Pipelines.PipelineRun do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pipeline_runs" do
    field :repo_url, :string
    field :status, :string, default: "running"
    field :results, :map, default: %{}
    field :error, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime

    belongs_to :pipeline, GitlockPhx.Pipelines.SavedPipeline
    belongs_to :user, GitlockPhx.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :repo_url,
      :status,
      :results,
      :error,
      :started_at,
      :completed_at,
      :pipeline_id,
      :user_id
    ])
    |> validate_required([:repo_url, :status, :pipeline_id, :user_id])
    |> validate_inclusion(:status, ~w(running completed failed))
    |> foreign_key_constraint(:pipeline_id)
    |> foreign_key_constraint(:user_id)
  end
end
