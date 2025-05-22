defmodule GitlockHolmesCore.Core.Coordinator do
  @moduledoc "Coordinates adapter setup and invokes investigations"

  alias GitlockHolmesCore.Adapters.Complexity.DispatchAnalyzer

  alias GitlockHolmesCore.Core.Investigations.Methodology.{
    IdentifyHotspots,
    IdentifyCouplings,
    IdentifyCoupledHotspots,
    IdentifyKnowledgeSilos,
    IdentifyBlastRadius,
    GetSummary
  }

  alias GitlockHolmesCore.Adapters.VCS.Git
  alias GitlockHolmesCore.Adapters.Reporters.{CsvReporter, JsonReporter}

  @investigations %{
    hotspots: IdentifyHotspots,
    couplings: IdentifyCouplings,
    summary: GetSummary,
    coupled_hotspots: IdentifyCoupledHotspots,
    knowledge_silos: IdentifyKnowledgeSilos,
    blast_radius: IdentifyBlastRadius
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
    with :ok <- validate_type(type),
         :ok <- validate_repo_path(repo_path),
         options <- Map.merge(%{format: "csv", vcs: "git"}, options),
         {:ok, inv_mod} <- fetch_investigation(type),
         {:ok, vcs_mod} <- fetch_vcs(options.vcs),
         {:ok, reporter} <- fetch_reporter(options.format),
         {:ok, analyzer} <- fetch_analyzer(type, options) do
      inv_mod.investigate(repo_path, vcs_mod, reporter, analyzer, options)
    else
      {:error, reason} ->
        {:error, "Investigation failed: #{reason}"}
    end
  end

  @spec validate_type(atom()) :: :ok | {:error, String.t()}
  defp validate_type(type) when is_atom(type) do
    if Map.has_key?(@investigations, type) do
      :ok
    else
      available_types = Map.keys(@investigations) |> Enum.map(&to_string/1) |> Enum.join(", ")

      {:error,
       "Unknown investigation type: #{inspect(type)}. Available types: #{available_types}"}
    end
  end

  defp validate_type(type),
    do: {:error, "Investigation type must be an atom, got: #{inspect(type)}"}

  @spec validate_repo_path(term()) :: :ok | {:error, String.t()}
  defp validate_repo_path(nil), do: {:error, "Repository path cannot be nil"}

  defp validate_repo_path(path) when not is_binary(path),
    do: {:error, "Repository path must be a string, got: #{inspect(path)}"}

  defp validate_repo_path(path) do
    if File.exists?(path) do
      :ok
    else
      {:error, "Repository path does not exist: #{path}"}
    end
  end

  defp fetch_investigation(type) do
    case Map.fetch(@investigations, type) do
      {:ok, mod} -> {:ok, mod}
      :error -> {:error, "Unknown investigation: #{inspect(type)}"}
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
      # The DispatchAnalyzer handles multi-language code by delegating 
      # to appropriate analyzers
      {:ok, DispatchAnalyzer}
    end
  end
end
