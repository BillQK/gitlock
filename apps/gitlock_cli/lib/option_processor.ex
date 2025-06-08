defmodule GitlockCLI.OptionProcessor do
  @moduledoc """
  Handles preparation and normalization of command-line options.

  Converts between legacy and new option formats, handles special cases like
  target_files, and normalizes option keys to their canonical forms.
  """

  @doc """
  Prepares options for investigation execution, handling special cases and normalization.
  """
  def prepare_options(options, _args) do
    # Process target_files from both --target-files and --tf options
    target_files = extract_and_process_target_files(options)

    # Convert options keyword list to map, handling aliases
    base_options =
      options
      |> Enum.reduce(%{}, fn
        {:target_files, _}, acc -> acc
        {:tf, _}, acc -> acc
        {key, value}, acc -> Map.put(acc, key, value)
      end)
      |> normalize_option_keys()

    # Add target_files if present
    if target_files && length(target_files) > 0 do
      Map.put(base_options, :target_files, target_files)
    else
      base_options
    end
  end

  @doc """
  Normalizes option keys, converting both legacy and new option names to canonical form.
  """
  def normalize_option_keys(options) do
    options
    |> Enum.map(fn
      # Legacy options to canonical form
      {key, value} when key in [:l, :log] -> {:log, value}
      {key, value} when key in [:rows] -> {:rows, value}
      {key, value} when key in [:f, :format] -> {:format, value}
      {key, value} when key in [:a, :arch_group] -> {:group, value}
      {key, value} when key in [:t, :time_period] -> {:temporal_period, value}
      # New options to canonical form
      {key, value} when key in [:r, :repo] -> {:repo, value}
      {key, value} when key in [:u, :url] -> {:url, value}
      {key, value} when key in [:o, :output] -> {:output, value}
      {key, value} when key in [:limit] -> {:rows, value}
      {key, value} when key in [:d, :dir] -> {:dir, value}
      {key, value} when key in [:bt, :blast_threshold] -> {:blast_threshold, value}
      {key, value} when key in [:mr, :max_radius] -> {:max_radius, value}
      # Preserve other options
      {key, value} -> {key, value}
    end)
    |> Map.new()
  end

  @doc """
  Validates that required options are present for specific investigation types.
  """
  def validate_required_options(investigation_type, options) do
    case investigation_type do
      type when type in [:hotspots, :coupled_hotspots, :blast_radius] ->
        validate_complexity_analysis_options(options)

      :blast_radius ->
        validate_blast_radius_options(options)

      _ ->
        :ok
    end
  end

  # Extracts and processes target_files options
  defp extract_and_process_target_files(options) do
    # Handle multiple --target-files or --tf options
    multiple_target_files = extract_multiple_target_files(options)

    # Handle comma-separated target files (legacy support)
    comma_separated_files = extract_comma_separated_target_files(options)

    case {multiple_target_files, comma_separated_files} do
      {nil, nil} -> nil
      {files, nil} when is_list(files) -> files
      {nil, files} when is_list(files) -> files
      {multiple, comma} -> multiple ++ comma
    end
    |> filter_empty_files()
  end

  # Extracts target_files options that can be specified multiple times
  defp extract_multiple_target_files(options) do
    target_files_entries =
      options
      |> Enum.filter(fn {key, _} -> key == :target_files or key == :tf end)

    if Enum.empty?(target_files_entries) do
      nil
    else
      Enum.map(target_files_entries, fn {_, value} -> value end)
    end
  end

  # Handles comma-separated target files from the existing design
  defp extract_comma_separated_target_files(options) do
    value = options[:target_files] || options[:tf]

    if value && is_binary(value) do
      value
      |> String.split(",")
      |> Enum.map(&String.trim/1)
    else
      nil
    end
  end

  # Filters out empty file names
  defp filter_empty_files(nil), do: nil

  defp filter_empty_files(files) do
    filtered = Enum.filter(files, &(String.length(&1) > 0))
    if Enum.empty?(filtered), do: nil, else: filtered
  end

  # Validates options required for complexity analysis
  defp validate_complexity_analysis_options(options) do
    if options[:dir] do
      :ok
    else
      {:error, "Directory option (--dir) is required for complexity analysis"}
    end
  end

  # Validates options specific to blast radius analysis
  defp validate_blast_radius_options(options) do
    cond do
      not options[:target_files] ->
        {:error, "Target files (--target-files) are required for blast radius analysis"}

      not options[:dir] ->
        {:error, "Directory option (--dir) is required for blast radius analysis"}

      true ->
        :ok
    end
  end
end
