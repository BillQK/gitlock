defmodule GitlockMCP.Application do
  @moduledoc false
  use Application
  require Logger

  @default_port 4100

  @impl true
  def start(_type, _args) do
    port = Application.get_env(:gitlock_mcp, :port, @default_port)

    children = [
      GitlockMCP.Cache,
      Hermes.Server.Registry,
      {GitlockMCP.Server, transport: :streamable_http},
      {Bandit, plug: GitlockMCP.Router, port: port}
    ]

    Logger.info("Gitlock MCP server starting on http://localhost:#{port}/mcp")

    opts = [strategy: :one_for_one, name: GitlockMCP.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
