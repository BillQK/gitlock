defmodule GitlockHolmesCore.Ports.ReportPort do
  @moduledoc """
  Port for formatting investigation results into an output string.
  """

  @typedoc "A list of result maps (or structs) to be formatted"
  @type results :: [map()]

  @typedoc "Options for report formatting (e.g. :rows limit, :format specifics)"
  @type options :: %{optional(atom()) => term()}

  @typedoc "Success tuple wrapping the rendered report"
  @type success :: {:ok, String.t()}

  @typedoc "Error tuple with a human‑readable reason"
  @type error :: {:error, String.t()}

  @doc """
  Format a collection of results according to the given options.

  ## Parameters

    * `results`  — a list of maps or structs representing analysis output  
    * `options`  — a map of formatting options (e.g. `:rows` to limit output)

  ## Returns

    * `{:ok, report_string}` on success  
    * `{:error, reason}` on failure  
  """
  @callback report(results(), options()) :: success() | error()
end
