defmodule GitlockMCP.CLI do
  @moduledoc """
  Entry point for running gitlock-mcp as a standalone server.

  Can be run as:
  - `mix run --no-halt --app gitlock_mcp` (during development)
  - Escript: `bin/gitlock-mcp` (starts HTTP server on port 4100)

  Connect AI agents via mcp-proxy:
    mcp-proxy http://localhost:4100/mcp
  """

  def main(args) do
    # Parse optional port arg
    port = parse_port(args)
    if port, do: Application.put_env(:gitlock_mcp, :port, port)

    Application.ensure_all_started(:gitlock_mcp)

    # Keep alive
    Process.sleep(:infinity)
  end

  defp parse_port(["--port", port | _]), do: String.to_integer(port)
  defp parse_port(["-p", port | _]), do: String.to_integer(port)
  defp parse_port(_), do: nil
end
