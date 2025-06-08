defmodule GitlockCLI.ErrorHandler do
  @moduledoc """
  Handles various error cases with user-friendly messages and appropriate exit codes.

  Provides consistent error formatting and actionable guidance for users.
  """

  @doc """
  Handles various error cases with user-friendly messages.
  """
  def handle_error({:io, path, :enoent}) do
    IO.puts(:stderr, "Error: File not found: #{path}")
    IO.puts(:stderr, "Please verify the path and try again.")
    System.halt(1)
  end

  def handle_error({:io, path, reason}) do
    IO.puts(:stderr, "Error reading file #{path}: #{inspect(reason)}")
    IO.puts(:stderr, "Please check file permissions and try again.")
    System.halt(1)
  end

  def handle_error({:git, reason}) do
    IO.puts(:stderr, "Git error: #{reason}")
    IO.puts(:stderr, "Please ensure Git is installed and the repository is valid.")
    System.halt(1)
  end

  def handle_error({:parse, reason}) do
    IO.puts(:stderr, "Error parsing input: #{reason}")
    IO.puts(:stderr, "Please check your input format and try again.")
    System.halt(1)
  end

  def handle_error({:analysis, reason}) do
    IO.puts(:stderr, "Error during analysis: #{reason}")
    IO.puts(:stderr, "Try adjusting analysis parameters and try again.")
    System.halt(1)
  end

  def handle_error({:commit, reason}) do
    IO.puts(:stderr, "Error processing commit: #{reason}")
    IO.puts(:stderr, "The log file may be malformed or corrupt.")
    System.halt(1)
  end

  def handle_error({:validation, reason}) do
    IO.puts(:stderr, "Validation error: #{reason}")
    IO.puts(:stderr, "Please check your command-line arguments and try again.")
    System.halt(1)
  end

  def handle_error(reason) when is_binary(reason) do
    IO.puts(:stderr, "Error: #{reason}")
    System.halt(1)
  end

  def handle_error(reason) do
    IO.puts(:stderr, "Error: #{inspect(reason)}")
    System.halt(1)
  end

  @doc """
  Displays error message for invalid command-line options.
  """
  def display_invalid_options(invalid) do
    invalid_options = Enum.map_join(invalid, ", ", fn {name, _} -> name end)
    IO.puts(:stderr, "Error: Invalid option(s): #{invalid_options}")
    IO.puts(:stderr, "Run 'gitlock --help' for usage information.")
    System.halt(1)
  end

  @doc """
  Displays a warning message to stderr without halting execution.
  """
  def warn(message) do
    IO.puts(:stderr, "Warning: #{message}")
  end

  @doc """
  Displays an informational message about deprecated features.
  """
  def deprecation_warning(old_feature, new_feature) do
    warn("The #{old_feature} is deprecated. Please use #{new_feature} instead.")
  end

  @doc """
  Formats validation errors in a consistent way.
  """
  def format_validation_error(field, message) do
    "#{field}: #{message}"
  end

  @doc """
  Handles file access errors with specific guidance.
  """
  def handle_file_error(path, operation) do
    case File.stat(path) do
      {:error, :enoent} ->
        handle_error({:io, path, :enoent})

      {:error, :eacces} ->
        IO.puts(:stderr, "Error: Permission denied when trying to #{operation} #{path}")
        IO.puts(:stderr, "Please check file permissions and try again.")
        System.halt(1)

      {:error, reason} ->
        handle_error({:io, path, reason})

      {:ok, _} ->
        # File exists but there might be other issues
        IO.puts(:stderr, "Error: Unable to #{operation} #{path}")
        IO.puts(:stderr, "The file exists but may be locked or in use by another process.")
        System.halt(1)
    end
  end
end
