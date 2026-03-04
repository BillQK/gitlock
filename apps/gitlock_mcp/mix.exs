defmodule GitlockMCP.MixProject do
  use Mix.Project

  def project do
    [
      app: :gitlock_mcp,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      escript: escript()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {GitlockMCP.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:gitlock_core, in_umbrella: true},
      {:hermes_mcp, "~> 0.14"},
      {:jason, "~> 1.4"},
      {:bandit, "~> 1.0"},
      {:plug, "~> 1.15"}
    ]
  end

  defp escript do
    [
      main_module: GitlockMCP.CLI,
      path: "../../bin/gitlock-mcp"
    ]
  end
end
