defmodule GitlockWorkflows.Application do
  @moduledoc false
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GitlockWorkflows.RuntimeSupervisor
    ]

    opts = [strategy: :one_for_one, name: GitlockWorkflows.Supervisor]

    with {:ok, pid} <- Supervisor.start_link(children, opts) do
      # Register built-in runtime nodes after supervisor is up
      GitlockWorkflows.Runtime.Registry.register_builtin_nodes()
      {:ok, pid}
    end
  end
end
