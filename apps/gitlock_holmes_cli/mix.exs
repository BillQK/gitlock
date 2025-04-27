defmodule GitlockHolmesCLI.MixProject do
  use Mix.Project

  def project do
    [
      app: :gitlock_holmes_cli,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:gitlock_holmes_core, in_umbrella: true}
    ]
  end

  defp escript do
    [
      main_module: GitlockHolmesCLI.Main,
      path: "../../bin/gitlock_holmes"
    ]
  end
end
