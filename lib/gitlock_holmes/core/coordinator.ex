defmodule GitlockHolmes.Core.Coordinator do
  @moduledoc "Coordinates adapter setup and invokes investigations"

  alias GitlockHolmes.Core.Investigations.Methodology.{
    IdentifyHotspots,
    IdentifyCouplings,
    IdentifyCoupledHotspots,
    GetSummary
  }

  alias GitlockHolmes.Adapters.Outbound.VCS.Git
  alias GitlockHolmes.Adapters.Complexity.MockAnalyzer
  alias GitlockHolmes.Adapters.Outbound.Reporters.{CsvReporter, JsonReporter}

  @investigations %{
    hotspots: IdentifyHotspots,
    couplings: IdentifyCouplings,
    summary: GetSummary,
    coupled_hotspots: IdentifyCoupledHotspots
  }

  @doc """
  Analyze a codebase using the specified investigation type.

  ## Parameters
    * `investigation_type` - One of :hotspots, :couplings, :summary, :coupled_hotspots
    * `repo_path`         - Path to the repository log or folder
    * `options`           - Map of options (e.g. :dir, :format, :vcs)

  ## Returns
    * `{:ok, report_string}` on success
    * `{:error, reason}` on failure
  """
  @spec investigate(atom(), String.t(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def investigate(type, repo_path, options \\ %{}) do
    options = Map.merge(%{format: "csv", vcs: "git"}, options)

    with {:ok, inv_mod} <- fetch_investigation(type),
         {:ok, vcs_mod} <- fetch_vcs(options.vcs),
         {:ok, reporter} <- fetch_reporter(options.format),
         {:ok, analyzer} <- fetch_analyzer(type, options),
         do: inv_mod.investigate(repo_path, vcs_mod, reporter, analyzer, options)
  end

  defp fetch_investigation(type) do
    case @investigations[type] do
      nil -> {:error, "Unknown investigation: #{inspect(type)}"}
      mod -> {:ok, mod}
    end
  end

  defp fetch_vcs("git"), do: {:ok, Git}
  defp fetch_vcs(other), do: {:error, "Unsupported VCS: #{other}"}

  defp fetch_reporter("json"), do: {:ok, JsonReporter}
  defp fetch_reporter("csv"), do: {:ok, CsvReporter}
  defp fetch_reporter(fmt), do: {:error, "Unsupported format: #{fmt}"}

  defp fetch_analyzer(type, opts) do
    if type in [:hotspots, :coupled_hotspots] and not Map.has_key?(opts, :dir) do
      {:error, "Directory path required for #{inspect(type)} analysis"}
    else
      {:ok, MockAnalyzer}
    end
  end
end
