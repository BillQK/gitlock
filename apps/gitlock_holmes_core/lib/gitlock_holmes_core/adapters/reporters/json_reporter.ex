defmodule GitlockHolmesCore.Adapters.Reporters.JsonReporter do
  @moduledoc """
  JSON reporter for formatting analysis results.
  """
  @behaviour GitlockHolmesCore.Ports.ReportPort

  @impl true
  @spec report(results :: [map()], opts :: map()) :: {:ok, String.t()} | {:error, String.t()}
  def report(results, _opts) do
    {:ok, Jason.encode!(results, pretty: true)}
  end
end
