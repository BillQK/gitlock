defmodule GitlockWorkflows.RuntimeSupervisor do
  @moduledoc """
  Supervisor for the GitlockWorkflows Runtime system.

  Manages the lifecycle of runtime components including:
  - Registry for node registration and discovery
  - Engine for workflow execution
  - Any other runtime services
  """
  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_init_arg) do
    children = [
      # Start the Registry first as other components depend on it
      {GitlockWorkflows.Runtime.Registry, []},

      # Start the Engine for workflow execution
      {GitlockWorkflows.Runtime.Engine, []}

      # Add other runtime components here as needed
      # {GitlockWorkflows.Runtime.Scheduler, []},
      # {GitlockWorkflows.Runtime.Monitor, []},
    ]

    # Restart strategy: if one crashes, restart only that one
    # Max 3 restarts within 5 seconds
    Supervisor.init(children, strategy: :one_for_one, max_restarts: 3, max_seconds: 5)
  end

  @doc """
  Registers all built-in nodes after the supervisor starts.

  This should be called from your application's start callback:

      def start(_type, _args) do
        children = [
          GitlockWorkflows.RuntimeSupervisor
        ]
        
        opts = [strategy: :one_for_one, name: GitlockWorkflows.Supervisor]
        
        with {:ok, pid} <- Supervisor.start_link(children, opts) do
          GitlockWorkflows.RuntimeSupervisor.register_builtin_nodes()
          {:ok, pid}
        en
      end
  """
  def register_builtin_nodes do
    GitlockWorkflows.Runtime.Registry.register_builtin_nodes()
  end
end
