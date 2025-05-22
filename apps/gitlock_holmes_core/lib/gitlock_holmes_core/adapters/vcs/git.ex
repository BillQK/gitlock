defmodule GitlockHolmesCore.Adapters.VCS.Git do
  @moduledoc """
  Git adapter for accessing Git commit history.
  """

  @behaviour GitlockHolmesCore.Ports.VersionControlPort

  alias GitlockHolmesCore.Domain.Entities.Commit
  alias GitlockHolmesCore.Domain.Values.FileChange
  alias GitlockHolmesCore.Domain.Entities.Author

  @type error_reason :: {:io, String.t(), term()} | {:parse, String.t()} | {:commit, String.t()}
  @type get_history_result :: {:ok, [Commit.t()]} | {:error, error_reason()}

  @impl true
  @spec get_commit_history(String.t(), map()) :: get_history_result()
  def get_commit_history(log_file, _options) do
    with {:ok, content} <- File.read(log_file) |> annotate_error({:io, log_file}) do
      parse_git_log(content)
    end
  end

  @spec parse_git_log(String.t()) :: {:ok, [Commit.t()]} | {:error, error_reason()}
  defp parse_git_log(content) do
    try do
      result =
        content
        |> String.split("\n\n", trim: true)
        |> Enum.reduce_while({:ok, []}, fn commit_text, {:ok, commits} ->
          case parse_commit(commit_text) do
            {:ok, commit} -> {:cont, {:ok, [commit | commits]}}
            {:error, reason} -> {:halt, {:error, reason}}
          end
        end)

      case result do
        {:ok, commits} -> {:ok, Enum.reverse(commits)}
        error -> error
      end
    rescue
      e -> {:error, {:parse, "Failed to parse git log: #{Exception.message(e)}"}}
    end
  end

  @spec parse_commit(String.t()) :: {:ok, Commit.t()} | {:error, error_reason()}
  @spec parse_commit(String.t()) :: {:ok, Commit.t()} | {:error, error_reason()}
  defp parse_commit(commit_text) do
    with {:ok, lines} <- extract_lines(commit_text),
         {:ok, header, file_lines} <- split_header_and_files(lines),
         {:ok, id, date, author_name} <- parse_header(header),
         {:ok, file_changes} <- parse_file_changes(file_lines) do
      # Create the commit with parsed data
      author = Author.new(author_name)
      {:ok, Commit.new(id, author, date, "", file_changes)}
    end
  end

  # Extract lines from commit text
  defp extract_lines(""), do: {:error, {:commit, "Empty commit text"}}

  defp extract_lines(commit_text) do
    lines = String.split(commit_text, "\n", trim: true)
    if Enum.empty?(lines), do: {:error, {:commit, "Empty commit text"}}, else: {:ok, lines}
  end

  # Split header and file lines
  defp split_header_and_files([]), do: {:error, {:commit, "No header line found"}}
  defp split_header_and_files([header | file_lines]), do: {:ok, header, file_lines}

  # Parse header information
  defp parse_header(header) do
    case Regex.run(~r/--(.+?)--(.+?)--(.+)/, header) do
      [_, id, date, author] -> {:ok, id, date, author}
      _ -> {:error, {:commit, "Invalid commit header format: #{header}"}}
    end
  end

  # Parse file changes
  defp parse_file_changes(file_lines) do
    file_lines
    |> Enum.filter(&String.contains?(&1, "\t"))
    |> Enum.reduce_while({:ok, []}, fn line, {:ok, changes} ->
      parse_file_change_line(line, changes)
    end)
    |> case do
      {:ok, changes} -> {:ok, Enum.reverse(changes)}
      error -> error
    end
  end

  # Parse a single file change line
  defp parse_file_change_line(line, changes) do
    case String.split(line, "\t", parts: 3) do
      [added, deleted, file] ->
        {:cont, {:ok, [FileChange.new(file, added, deleted) | changes]}}

      _ ->
        {:halt, {:error, {:commit, "Malformed file change line: #{line}"}}}
    end
  end

  # Helper to annotate error tuples with additional context
  defp annotate_error({:ok, value}, _context), do: {:ok, value}

  defp annotate_error({:error, reason}, {context_type, context_value}),
    do: {:error, {context_type, context_value, reason}}
end
