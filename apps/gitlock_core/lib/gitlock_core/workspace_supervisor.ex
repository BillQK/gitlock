defmodule GitlockCore.WorkspaceSupervisor do
  @moduledoc """
  Supervisor for workspace-related processes.
  Uses rest_for_one because Manager and Cleaner depend on Store.
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      GitlockCore.Infrastructure.Workspace.Store,
      GitlockCore.Infrastructure.Workspace.Manager,
      GitlockCore.Infrastructure.Workspace.Cleaner
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
