defmodule GitlockMCP.Router do
  @moduledoc """
  Minimal Plug router for the standalone MCP server.

  Forwards /mcp to the Hermes StreamableHTTP transport and serves
  a health check at /health.
  """
  use Plug.Router

  plug(:match)
  plug(:dispatch)

  forward("/mcp",
    to: Hermes.Server.Transport.StreamableHTTP.Plug,
    init_opts: [server: GitlockMCP.Server]
  )

  get "/health" do
    send_resp(conn, 200, Jason.encode!(%{status: "ok", server: "gitlock-mcp"}))
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end
