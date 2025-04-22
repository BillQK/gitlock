defmodule GitlockHolmes.Adapters.Reporters.JsonReporter do
  @moduledoc """
  JSON reporter for formatting analysis results.
  """
  @behaviour GitlockHolmes.Ports.ReportPort

  def report(results, _), do: {:ok, Jason.encode!(results, pretty: true)}
end
