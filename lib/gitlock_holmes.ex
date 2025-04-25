defmodule GitlockHolmes do
  @moduledoc """
  GitlockHolmes is a forensic code analysis tool inspired by Adam Tornhill's
  "Your Code as Crime Scene" methodology.
  This module provides the main entry points for using the library programmatically.
  """

  alias GitlockHolmes.Investigations.Methodology.{
    IdentifyHotspots,
    IdentifyCouplings,
    IdentifyCoupledHotspots,
    GetSummary
  }

  alias GitlockHolmes.Adapters.VCS.Git
  alias GitlockHolmes.Adapters.Complexity.MockAnalyzer
  alias GitlockHolmes.Adapters.Reporters.{CsvReporter, JsonReporter}

  @doc """
  Analyze a codebase using the specified investigation type.
  ## Parameters
    * `investigation_type` - The type of investigation to perform (e.g., :hotspots, :coupling)
    * `repository_path` - Path to the repository or log file
    * `options` - Options for the investigation
  ## Examples
      iex> GitlockHolmes.investigate(:hotspots, "path/to/repo", %{dir: "src"})
      {:ok, [...]}
  """
  @spec investigate(atom(), String.t(), map()) :: {:ok, any()} | {:error, String.t()}
  def investigate(investigation_type, repository_path, options \\ %{}) do
    # Set default options
    options = Map.merge(%{format: "csv"}, options)

    # Get the appropriate investigation module
    with {:ok, investigation} <- get_investigation_module(investigation_type),
         # Get the appropriate VCS adapter
         {:ok, vcs} <- get_vcs_adapter(options[:vcs] || "git"),
         # Get the appropriate reporter
         {:ok, reporter} <- get_reporter(options[:format]),
         # Get the appropriate complexity analyzer if needed
         {:ok, analyzer} <- get_complexity_analyzer(investigation_type, options) do
      # Run the investigation
      investigation.investigate(repository_path, vcs, reporter, analyzer, options)
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Maps investigation type atoms to modules
  defp get_investigation_module(type) do
    case type do
      :hotspots -> {:ok, IdentifyHotspots}
      :couplings -> {:ok, IdentifyCouplings}
      :summary -> {:ok, GetSummary}
      :coupled_hotspots -> {:ok, IdentifyCoupledHotspots}
      _ -> {:error, "Unknown investigation type: #{inspect(type)}"}
    end
  end

  # Gets the appropriate VCS adapter
  defp get_vcs_adapter(vcs) do
    case vcs do
      "git" -> {:ok, Git}
      _ -> {:error, "Unsupported VCS: #{vcs}"}
    end
  end

  # Gets the appropriate reporter based on format
  defp get_reporter(format) do
    case format do
      "csv" -> {:ok, CsvReporter}
      "json" -> {:ok, JsonReporter}
      _ -> {:error, "Unsupported format: #{format}"}
    end
  end

  # Determines if an analyzer is needed based on investigation type
  defp get_complexity_analyzer(investigation_type, options) do
    needs_complexity = investigation_type in [:hotspots, :coupled_hotspots]

    if needs_complexity && !options[:dir] do
      {:error, "Directory path required for complexity analysis with #{investigation_type}"}
    else
      # could be configurable
      {:ok, MockAnalyzer}
    end
  end
end

