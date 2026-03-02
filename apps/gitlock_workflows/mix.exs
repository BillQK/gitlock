defmodule GitlockWorkflows.MixProject do
  use Mix.Project

  def project do
    [
      app: :gitlock_workflows,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.18",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      mod: {GitlockWorkflows.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:gitlock_core, in_umbrella: true},
      {:reactor, "~> 0.15.6"},
      {:jason, "~> 1.4"}
    ]
  end
end
