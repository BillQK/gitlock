defmodule GitlockHolmes.Adapters.UI.CLI do
  @moduledoc """
  Command-line interface for Gitlock Holmes.
  """
  alias GitlockHolmes.Adapters.VCS.{Git}
  alias GitlockHolmes.Adapters.Reporters.{CsvReporter}
  alias GitlockHolmes.Investigations.Methodology.{IdentifyHotspots}
  alias GitlockHolmes.Adapters.Complexity.{MockAnalyzer}

  @doc """
  Entry point for the CLI application.
  """
  def main(args) do
    {parsed_opts, remaining_args, invalid_opts} = parse_options(args)

    cond do
      Enum.any?(invalid_opts) ->
        display_invalid_options(invalid_opts)

      parsed_opts[:help] || Enum.empty?(parsed_opts) ->
        display_help()

      !parsed_opts[:log] ->
        IO.puts("Error: No log file specified. Use --log or -l.")

      !parsed_opts[:vcs] ->
        IO.puts("Error: No version control system specified. Use --vcs or -v.")

      !parsed_opts[:investigation] ->
        IO.puts("Error: No investigation specified. Use --investigation or -i.")

      !parsed_opts[:dir] ->
        IO.puts(
          "Error: No code directory specified. Use --dir to provide path for complexity analysis."
        )

      true ->
        run_investigation(parsed_opts, remaining_args)
    end
  end

  defp parse_options(args) do
    OptionParser.parse(args,
      switches: [
        log: :string,
        vcs: :string,
        investigation: :string,
        format: :string,
        rows: :integer,
        arch_group: :string,
        time_period: :integer,
        team_map: :string,
        min_revs: :integer,
        dir: :string,
        help: :boolean
      ],
      aliases: [
        l: :log,
        v: :vcs,
        i: :investigation,
        f: :format,
        r: :rows,
        a: :arch_group,
        t: :time_period,
        h: :help
      ]
    )
  end

  defp display_invalid_options(invalid_opts) do
    IO.puts(
      "Error: Invalid option(s): #{Enum.map_join(invalid_opts, ", ", fn {opt, _} -> opt end)}"
    )

    display_help()
  end

  defp display_help do
    IO.puts("""
    Gitlock Holmes: Forensic code analysis tool

    USAGE:
      gitlock_holmes [OPTIONS]

    OPTIONS:
      -l, --log FILE               Path to the VCS log file
      -v, --vcs VCS                Version control system (git, svn, github)
      -i, --investigation TYPE     Type of investigation to perform
      -f, --format FORMAT          Output format (csv, json, html) [default: csv]
      -r, --rows NUM               Limit output to NUM rows
      -a, --arch-group FILE        Path to architectural grouping definition
      -t, --time-period DAYS       Time window for temporal grouping (in days)
          --team-map FILE          Path to team mapping file
          --min-revs NUM           Minimum revisions threshold
          --dir DIRECTORY          Path to code directory for complexity analysis
      -h, --help                   Display this help message

    INVESTIGATIONS:
      knowledge_silos              Detect knowledge concentration
      hotspots                     Identify high-risk areas
      coupling                     Find logical coupling patterns
      team_communication           Map team communication patterns
      code_health                  Assess overall code health
    """)
  end

  defp run_investigation(options, _args) do
    options_map = Map.new(options)

    vcs_adapter = get_vcs_adapter(options_map.vcs)
    reporter = get_reporter(options_map[:format] || "csv")
    investigation = get_investigation(options_map.investigation)
    analyzer = get_analyzer(options_map[:analyzer] || "mock")

    case investigation.investigate(
           options_map.log,
           vcs_adapter,
           reporter,
           analyzer,
           options_map
         ) do
      {:ok, output} ->
        File.write("output.csv", output)

      {:error, reason} ->
        IO.puts("Investigation failed: #{reason}")
        System.halt(1)
    end
  end

  defp get_vcs_adapter("git"), do: Git
  defp get_reporter("csv"), do: CsvReporter
  defp get_investigation("hotspots"), do: IdentifyHotspots
  defp get_analyzer("mock"), do: MockAnalyzer
end
