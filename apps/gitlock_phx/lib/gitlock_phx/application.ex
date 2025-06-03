defmodule GitlockPhx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GitlockPhxWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:gitlock_phx, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GitlockPhx.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: GitlockPhx.Finch},
      # Start a worker by calling: GitlockPhx.Worker.start_link(arg)
      # {GitlockPhx.Worker, arg},
      # Start to serve requests, typically the last entry
      GitlockPhxWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GitlockPhx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GitlockPhxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
