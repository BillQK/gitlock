defmodule GitlockHolmesCore.Adapters.Reporters.JsonReporter do
  @moduledoc """
  JSON reporter for formatting analysis results.
  """
  @behaviour GitlockHolmesCore.Ports.ReportPort

  @impl true
  @spec report(results :: [map()], opts :: map()) :: {:ok, String.t()} | {:error, String.t()}
  def report(results, options) do
    results =
      Enum.map(results, fn
        %{__struct__: _} = struct -> Map.from_struct(struct)
        map -> map
      end)

    results =
      if options[:rows], do: Enum.take(results, options[:rows]), else: results

    {:ok, Jason.encode!(results, pretty: true)}
  end
end
