defmodule GitlockHolmesCore.Adapters.VCS.Git do
  @moduledoc """
  Git adapter for accessing Git commit history.
  """

  @behaviour GitlockHolmesCore.Ports.VersionControlPort

  alias GitlockHolmesCore.Domain.Entities.Commit
  alias GitlockHolmesCore.Domain.Values.FileChange
  alias GitlockHolmesCore.Domain.Entities.Author

  @type parse_error :: {:error, String.t()}

  @impl true
  @spec get_commit_history(String.t(), map()) :: {:ok, [Commit.t()]} | parse_error()
  def get_commit_history(log_file, _options) do
    with {:ok, content} <- File.read(log_file),
         {:ok, commits} <- parse_git_log(content) do
      {:ok, commits}
    else
      {:error, reason} -> {:error, "Failed to read Git log: #{reason}"}
    end
  end

  @spec parse_git_log(String.t()) :: {:ok, [Commit.t()]} | parse_error()
  defp parse_git_log(content) do
    # Simplified parsing logic
    commits =
      content
      |> String.split("\n\n", trim: true)
      |> Enum.map(&parse_commit/1)

    {:ok, commits}
  rescue
    e -> {:error, Exception.message(e)}
  end

  @spec parse_commit(String.t()) :: Commit.t() | parse_error()
  defp parse_commit(commit_text) do
    try do
      # Just a simplified example of parsing a Git commit
      [header | file_lines] = String.split(commit_text, "\n", trim: true)

      # Extract header info for the new format: --commit_id--date--author
      case Regex.run(~r/--(.+?)--(.+?)--(.+)/, header) do
        [_, id, date, author] ->
          # Parse file changes
          file_changes =
            Enum.filter(file_lines, fn line ->
              # Filter out non-file change lines if any
              String.contains?(line, "\t")
            end)
            |> Enum.map(fn line ->
              case String.split(line, "\t", parts: 3) do
                [added, deleted, file] ->
                  FileChange.new(file, added, deleted)

                _ ->
                  # Handle malformed lines
                  nil
              end
            end)
            # Remove any nil entries from malformed lines
            |> Enum.filter(&(&1 != nil))

          author = Author.new(author)
          Commit.new(id, author, date, "", file_changes)

        nil ->
          {:error, "Invalid commit header format: #{header}"}
      end
    rescue
      e -> {:error, "Failed to parse commit: #{Exception.message(e)}"}
    end
  end
end
