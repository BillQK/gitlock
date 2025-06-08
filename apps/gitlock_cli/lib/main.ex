defmodule GitlockCLI.Main do
  @moduledoc """
  Main entry point for the Gitlock CLI application.

  This module orchestrates the CLI workflow by delegating to specialized modules
  for argument parsing, validation, and execution.
  """

  alias GitlockCLI.{ArgumentParser, InvestigationTypes, ErrorHandler, HelpDisplay, OutputHandler}

  @version "0.1.0"

  @doc """
  Entry point for the CLI application.

  Parses command-line arguments and orchestrates the investigation execution.
  """
  def main(args) do
    start_time = :os.timestamp()

    case ArgumentParser.parse(args) do
      {:help, remaining} ->
        HelpDisplay.display_help(remaining)

      {:version} ->
        HelpDisplay.display_version(@version)

      {:invalid_options, invalid} ->
        ErrorHandler.display_invalid_options(invalid)

      {:ok, parsed_args} ->
        execute_workflow(parsed_args, start_time)

      {:error, reason} ->
        ErrorHandler.handle_error(reason)
    end
  end

  # Executes the main workflow after successful argument parsing
  defp execute_workflow(args, start_time) do
    case InvestigationTypes.validate_investigation(args) do
      {:ok, investigation_type, prepared_args} ->
        run_investigation(investigation_type, prepared_args, start_time)

      {:error, reason} ->
        ErrorHandler.handle_error(reason)
    end
  end

  # Runs the actual investigation
  defp run_investigation(investigation_type, args, start_time) do
    IO.puts("Running #{investigation_type} analysis on #{args.repo_source}...")

    case GitlockCore.investigate(investigation_type, args.repo_source, args.options) do
      {:ok, result} ->
        OutputHandler.handle_success(result, args.options, investigation_type)
        report_execution_time(start_time)

      {:error, reason} ->
        ErrorHandler.handle_error(reason)
    end
  end

  # Reports execution time
  defp report_execution_time(start_time) do
    end_time = :os.timestamp()
    execution_time = :timer.now_diff(end_time, start_time) / 1_000_000
    IO.puts("Execution Time: #{Float.round(execution_time, 3)}s")
  end
end
