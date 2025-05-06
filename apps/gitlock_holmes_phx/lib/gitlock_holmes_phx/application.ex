defmodule GitlockHolmesPhx.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      GitlockHolmesPhxWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:gitlock_holmes_phx, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: GitlockHolmesPhx.PubSub},
      # Start the Finch HTTP client for sending emails
      {Finch, name: GitlockHolmesPhx.Finch},
      # Start a worker by calling: GitlockHolmesPhx.Worker.start_link(arg)
      # {GitlockHolmesPhx.Worker, arg},
      # Start to serve requests, typically the last entry
      GitlockHolmesPhxWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: GitlockHolmesPhx.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    GitlockHolmesPhxWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
