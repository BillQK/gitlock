defmodule GitlockCLI.OutputHandler do
  @moduledoc """
  Handles output formatting and file writing for investigation results.

  Supports multiple output formats and both file and stdout output modes.
  """

  alias GitlockCLI.ErrorHandler

  @doc """
  Handles successful execution of an investigation with support for multiple output modes.
  """
  def handle_success(result, options, investigation_type) do
    cond do
      # Write to specified output file
      options[:output] ->
        write_to_file(result, options[:output])

      # Format is explicitly set to stdout
      options[:format] == "stdout" ->
        IO.puts(result)

      # Legacy style: Write to timestamped file in output directory
      true ->
        write_to_timestamped_file(result, options, investigation_type)
    end

    :ok
  end

  @doc """
  Writes content to a specified file with error handling.
  """
  def write_to_file(content, filepath) do
    case ensure_directory_exists(filepath) do
      :ok ->
        case File.write(filepath, content) do
          :ok ->
            IO.puts("Results written to #{filepath}")

          {:error, _reason} ->
            ErrorHandler.handle_file_error(filepath, "write to")
        end

      {:error, reason} ->
        ErrorHandler.handle_error("Failed to create directory for #{filepath}: #{reason}")
    end
  end

  @doc """
  Writes content to a timestamped file in the output directory.
  """
  def write_to_timestamped_file(content, options, investigation_type) do
    format = determine_output_format(options)
    filename = generate_timestamped_filename(investigation_type, format)

    write_to_file(content, filename)
  end

  @doc """
  Generates a timestamped filename for output files.
  """
  def generate_timestamped_filename(investigation_type, format \\ "csv") do
    timestamp = generate_timestamp()
    output_dir = Application.get_env(:gitlock_cli, :output_dir, "output")
    Path.join(output_dir, "#{investigation_type}-#{timestamp}.#{format}")
  end

  @doc """
  Determines the output format from options, with sensible defaults.
  """
  def determine_output_format(options) do
    format = options[:format] || "csv"
    # Convert stdout format to txt for file output
    if format == "stdout", do: "txt", else: format
  end

  @doc """
  Formats content according to the specified format.
  """
  def format_content(content, format) do
    case format do
      "json" -> format_as_json(content)
      # Assume content is already in CSV format
      "csv" -> content
      "txt" -> content
      "stdout" -> content
      _ -> content
    end
  end

  @doc """
  Validates that the specified output format is supported.
  """
  def validate_format(format) do
    supported_formats = ["csv", "json", "txt", "stdout"]

    if format in supported_formats do
      :ok
    else
      {:error,
       "Unsupported output format: #{format}. Supported formats: #{Enum.join(supported_formats, ", ")}"}
    end
  end

  @doc """
  Estimates the size of output content for large result warnings.
  """
  def estimate_content_size(content) when is_binary(content) do
    byte_size(content)
  end

  def estimate_content_size(_content), do: 0

  @doc """
  Warns user if output content is very large.
  """
  def warn_if_large_output(content, threshold \\ 10_000_000) do
    size = estimate_content_size(content)

    if size > threshold do
      size_mb = Float.round(size / 1_000_000, 2)

      ErrorHandler.warn(
        "Output is quite large (#{size_mb} MB). Consider using --limit to reduce results."
      )
    end
  end

  @doc """
  Outputs content to stdout according to the specified format.
  This function is added to meet test expectations.
  """
  def output_to_stdout(content, options) do
    # Format content if needed
    formatted_content = format_content(content, options[:format])

    # Output to stdout
    IO.puts(formatted_content)
  end

  @doc """
  Outputs content to a file according to the specified format and options.
  This function is added to meet test expectations.
  """
  def output_to_file(content, _investigation_type, options, output_file) do
    # Format content if needed
    formatted_content = format_content(content, options[:format])

    # Write to the specified file
    write_to_file(formatted_content, output_file)
  end

  @doc """
  Generate an output filename based on investigation type and format.
  This function is an alias for generate_timestamped_filename for backward compatibility.
  """
  def generate_output_filename(investigation_type, options) do
    format = options[:format] || "csv"
    generate_timestamped_filename(investigation_type, format)
  end

  # Ensures the directory for a file path exists
  defp ensure_directory_exists(filepath) do
    dir = Path.dirname(filepath)

    case File.mkdir_p(dir) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Generates a timestamp for filenames
  defp generate_timestamp do
    DateTime.utc_now()
    |> Calendar.strftime("%Y%m%d-%H%M%S")
  end

  # Formats content as JSON (placeholder - would need actual JSON encoding)
  defp format_as_json(content) do
    # This is a placeholder - in a real implementation, you'd use a JSON library
    # like Jason to properly encode the content
    content
  end
end
