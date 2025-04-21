defmodule GitlockHolmes.Ports.ReportPort do
  @moduledoc """
  Port for report analysis results.
  """

  @callback report(term(), map()) :: {:ok, String.t()} | {:error, String.t()}
end
