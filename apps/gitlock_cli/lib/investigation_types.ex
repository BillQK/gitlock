defmodule GitlockCLI.InvestigationTypes do
  @moduledoc """
  Handles normalization and validation of investigation types.

  Supports both underscore and dash formats, with aliases for common variations.
  """

  @investigation_aliases %{
    "hotspot" => "hotspots",
    "hotspots" => "hotspots",
    "coupling" => "couplings",
    "couplings" => "couplings",
    "knowledge-silo" => "knowledge_silos",
    "knowledge_silos" => "knowledge_silos",
    "silo" => "knowledge_silos",
    "silos" => "knowledge_silos",
    "coupled-hotspot" => "coupled-hotspots",
    "coupled_hotspots" => "coupled_hotspots",
    "summary" => "summary",
    "blast-radius" => "blast_radius",
    "blast" => "blast_radius",
    "impact" => "blast_radius",
    "code_age" => "code_age",
    "code-age" => "code_age"
  }

  @doc """
  Validates and normalizes the investigation type from parsed arguments.

  Returns:
  - `{:ok, investigation_atom, prepared_args}` - Valid investigation
  - `{:error, reason}` - Invalid or unknown investigation
  """
  def validate_investigation(%{investigation_type: investigation_type} = args) do
    case normalize_investigation_type(investigation_type) do
      {:ok, normalized_type} ->
        investigation_atom = String.to_atom(normalized_type)

        if investigation_atom in GitlockCore.available_investigations() do
          {:ok, investigation_atom, args}
        else
          {:error,
           "Unknown investigation type: #{investigation_type}. Available investigations: #{available_investigations_string()}"}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Returns a list of available investigation aliases for help display.
  """
  def available_aliases do
    @investigation_aliases
    |> Map.keys()
    |> Enum.sort()
  end

  @doc """
  Returns the canonical investigation name for a given alias.
  """
  def canonical_name(alias_name) do
    normalized = alias_name |> to_string() |> String.downcase() |> String.trim()
    Map.get(@investigation_aliases, normalized)
  end

  # Converts investigation names to the canonical form
  defp normalize_investigation_type(type) do
    normalized = type |> to_string() |> String.downcase() |> String.trim()

    case Map.get(@investigation_aliases, normalized) do
      nil -> {:error, "Unknown investigation type: #{type}"}
      investigation -> {:ok, investigation}
    end
  end

  # Returns a comma-separated string of available investigation types
  defp available_investigations_string do
    GitlockCore.available_investigations()
    |> Enum.map_join(", ", &to_string/1)
  end
end
