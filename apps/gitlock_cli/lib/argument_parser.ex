defmodule GitlockCLI.ArgumentParser do
  @moduledoc """
  Handles parsing and validation of command-line arguments for the Gitlock CLI.

  Supports both legacy style (--investigation) and new style (positional arg) commands.
  """

  alias GitlockCLI.{RepositorySource, OptionProcessor}

  @doc """
  Parses command-line arguments and returns structured results.

  Returns:
  - `{:help, remaining}` - Help was requested
  - `{:version}` - Version was requested
  - `{:invalid_options, invalid}` - Invalid options were provided
  - `{:ok, parsed_args}` - Successfully parsed arguments
  - `{:error, reason}` - Parsing error occurred
  """
  def parse(args) do
    {parsed, remaining, invalid} = parse_raw_args(args)

    cond do
      parsed[:help] || parsed[:h] ->
        {:help, remaining}

      parsed[:version] || parsed[:v] ->
        {:version}

      Enum.any?(invalid) ->
        {:invalid_options, invalid}

      true ->
        build_parsed_args(parsed, remaining)
    end
  end

  # Parses raw command-line arguments using OptionParser
  defp parse_raw_args(args) do
    OptionParser.parse(args,
      strict: [
        # Common options
        help: :boolean,
        h: :boolean,
        version: :boolean,
        v: :boolean,

        # Repository source options
        repo: :string,
        r: :string,
        log: :string,
        l: :string,
        url: :string,
        u: :string,
        vcs: :string,

        # Investigation options
        investigation: :string,
        i: :string,

        # Output options
        format: :string,
        f: :string,
        output: :string,
        o: :string,
        limit: :integer,
        rows: :integer,

        # Analysis options
        dir: :string,
        d: :string,
        arch_group: :string,
        a: :string,
        time_period: :integer,
        t: :integer,
        team_map: :string,
        min_revs: :integer,
        min_coupling: :float,
        min_windows: :integer,

        # Blast radius options
        target_files: :keep,
        tf: :keep,
        blast_threshold: :float,
        bt: :float,
        max_radius: :integer,
        mr: :integer
      ],
      aliases: [
        h: :help,
        v: :version,
        r: :repo,
        l: :log,
        u: :url,
        i: :investigation,
        f: :format,
        o: :output,
        d: :dir,
        a: :arch_group,
        t: :time_period,
        tf: :target_files,
        bt: :blast_threshold,
        mr: :max_radius
      ]
    )
  end

  # Builds the final parsed arguments structure
  defp build_parsed_args(parsed_options, remaining_args) do
    case extract_investigation_info(parsed_options, remaining_args) do
      {:ok, investigation_type, args_without_investigation} ->
        # Check if a positional repo path was provided (e.g., `gitlock hotspots /tmp/repo`)
        {repo_source, source_type} =
          case args_without_investigation do
            [path | _] when byte_size(path) > 0 ->
              {path, RepositorySource.determine_source_type(path)}

            _ ->
              RepositorySource.determine(parsed_options)
          end

        processed_options =
          OptionProcessor.prepare_options(parsed_options, args_without_investigation)

        parsed_args = %{
          investigation_type: investigation_type,
          repo_source: repo_source,
          options: Map.put(processed_options, :source_type, source_type)
        }

        {:ok, parsed_args}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Extracts investigation type from arguments (supports both new and legacy styles)
  defp extract_investigation_info(options, remaining_args) do
    cond do
      # New style: First positional argument is the investigation type
      Enum.any?(remaining_args) ->
        investigation_type = List.first(remaining_args)
        remaining = Enum.drop(remaining_args, 1)
        {:ok, investigation_type, remaining}

      # Legacy style: --investigation flag
      options[:investigation] || options[:i] ->
        investigation_type = options[:investigation] || options[:i]
        {:ok, investigation_type, []}

      # No investigation specified
      true ->
        {:error,
         "No investigation specified. Specify an investigation with --investigation TYPE or as the first argument."}
    end
  end
end
