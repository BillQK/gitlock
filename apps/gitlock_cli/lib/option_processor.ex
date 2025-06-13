defmodule GitlockCLI.OptionProcessor do
  @moduledoc """
  Processes and prepares options for the Gitlock CLI by normalizing values,
  applying defaults, and handling special cases.
  """

  @doc """
  Prepares options by normalizing values and applying defaults.

  Takes parsed options from OptionParser and any remaining arguments,
  then returns a processed map of options.
  """
  def prepare_options(parsed_options, remaining_args) do
    # Convert the list of tuples to a map, but preserve multiple occurrences of the same key
    options_map = handle_multiple_options(parsed_options)

    options_map
    |> normalize_aliases()
    |> process_target_files(remaining_args)
    |> process_special_options()
    |> apply_defaults()
  end

  # Handles options with multiple occurrences (specifically for :keep options)
  defp handle_multiple_options(options) do
    # Group options by key
    grouped = Enum.group_by(options, fn {k, _} -> k end, fn {_, v} -> v end)

    # Create a map where keys with multiple values are preserved as lists
    Enum.reduce(grouped, %{}, fn {key, values}, acc ->
      if length(values) > 1 do
        Map.put(acc, key, values)
      else
        Map.put(acc, key, List.first(values))
      end
    end)
  end

  # Normalizes option aliases to their full names
  defp normalize_aliases(options) do
    options
    |> maybe_use_alias(:r, :repo)
    |> maybe_use_alias(:l, :log)
    |> maybe_use_alias(:u, :url)
    |> maybe_use_alias(:i, :investigation)
    |> maybe_use_alias(:f, :format)
    |> maybe_use_alias(:o, :output)
    |> maybe_use_alias(:d, :dir)
    |> maybe_use_alias(:a, :arch_group)
    |> maybe_use_alias(:t, :time_period)
    |> maybe_use_alias(:tf, :target_files)
    |> maybe_use_alias(:bt, :blast_threshold)
    |> maybe_use_alias(:mr, :max_radius)
    |> handle_rows_as_limit()
  end

  # Makes rows an alias for limit
  defp handle_rows_as_limit(options) do
    case options do
      %{rows: rows} ->
        # If both limit and rows are present, prefer rows
        options
        |> Map.put(:limit, rows)
        # Keep rows for backward compatibility
        |> Map.put(:rows, rows)

      _ ->
        # If rows is not present, make sure limit gets copied to rows
        case options do
          %{limit: limit} -> Map.put(options, :rows, limit)
          _ -> options
        end
    end
  end

  # Uses the value from an alias if the main option is not present
  defp maybe_use_alias(options, alias_key, main_key) do
    cond do
      # If main option is not present but alias is, use the alias
      is_nil(options[main_key]) && options[alias_key] ->
        Map.put(options, main_key, options[alias_key])

      # Otherwise, keep options as is
      true ->
        options
    end
  end

  # Processes target files from both options and remaining args
  defp process_target_files(options, remaining_args) do
    target_files =
      options
      |> extract_target_files()
      |> merge_with_positional_files(remaining_args)
      |> expand_comma_separated_files()
      |> Enum.uniq()

    if Enum.empty?(target_files) do
      options
    else
      Map.put(options, :target_files, target_files)
    end
  end

  # Extracts target files from options
  defp extract_target_files(options) do
    case options[:target_files] do
      nil ->
        []

      # When we have a list of values (multiple --target-files)
      files when is_list(files) ->
        files

      # Single value
      file ->
        [file]
    end
  end

  # Merges with any files specified as positional arguments
  defp merge_with_positional_files(target_files, remaining_args) do
    target_files ++ remaining_args
  end

  # Expands any comma-separated file lists
  defp expand_comma_separated_files(files) do
    files
    |> Enum.flat_map(fn file ->
      if is_binary(file) && String.contains?(file, ",") do
        String.split(file, ",", trim: true)
      else
        [file]
      end
    end)
  end

  # Processes special options that need custom handling
  defp process_special_options(options) do
    options
  end

  # Applies default values for options that weren't specified
  defp apply_defaults(options) do
    options
    |> Map.put_new(:format, "csv")
    |> Map.put_new(:limit, 10)
    # Ensure rows always exists
    |> Map.put_new(:rows, Map.get(options, :limit, 10))
    |> Map.put_new(:min_revs, 5)
    |> Map.put_new(:min_coupling, 0.5)
    |> Map.put_new(:blast_threshold, 0.1)
    |> Map.put_new(:max_radius, 2)
  end
end
