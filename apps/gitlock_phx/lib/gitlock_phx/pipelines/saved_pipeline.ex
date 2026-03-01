defmodule GitlockPhx.Pipelines.SavedPipeline do
  use Ecto.Schema
  import Ecto.Changeset

  schema "pipelines" do
    field :name, :string
    field :description, :string, default: ""
    field :config, :map, default: %{}
    field :is_template, :boolean, default: false

    belongs_to :user, GitlockPhx.Accounts.User
    has_many :runs, GitlockPhx.Pipelines.PipelineRun

    timestamps(type: :utc_datetime)
  end

  def changeset(pipeline, attrs) do
    pipeline
    |> cast(attrs, [:name, :description, :config, :is_template, :user_id])
    |> validate_required([:name, :config])
    |> validate_length(:name, min: 1, max: 100)
    |> maybe_require_user()
    |> foreign_key_constraint(:user_id)
  end

  defp maybe_require_user(changeset) do
    if get_field(changeset, :is_template) do
      changeset
    else
      validate_required(changeset, [:user_id])
    end
  end
end
