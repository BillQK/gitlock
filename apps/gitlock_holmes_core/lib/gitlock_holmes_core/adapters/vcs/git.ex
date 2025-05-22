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
    with {:ok, content} <- File.read(log_file) |> annotate_error({:io, log_file}),
         {:ok, commits} <- parse_git_log(content) do
      {:ok, commits}
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
  defp parse_commit(commit_text) do
    try do
      # Just a simplified example of parsing a Git commit
      case String.split(commit_text, "\n", trim: true) do
        [] ->
          {:error, {:commit, "Empty commit text"}}

        [header | file_lines] ->
          # Extract header info for the new format: --commit_id--date--author
          case Regex.run(~r/--(.+?)--(.+?)--(.+)/, header) do
            [_, id, date, author] ->
              # Parse file changes
              file_changes =
                file_lines
                |> Enum.filter(&String.contains?(&1, "\t"))
                |> Enum.reduce_while({:ok, []}, fn line, {:ok, changes} ->
                  case String.split(line, "\t", parts: 3) do
                    [added, deleted, file] ->
                      {:cont, {:ok, [FileChange.new(file, added, deleted) | changes]}}

                    _ ->
                      {:halt, {:error, {:commit, "Malformed file change line: #{line}"}}}
                  end
                end)

              case file_changes do
                {:ok, changes} ->
                  author = Author.new(author)
                  {:ok, Commit.new(id, author, date, "", Enum.reverse(changes))}

                error ->
                  error
              end

            nil ->
              {:error, {:commit, "Invalid commit header format: #{header}"}}
          end
      end
    rescue
      e -> {:error, {:commit, "Failed to parse commit: #{Exception.message(e)}"}}
    end
  end

  # Helper to annotate error tuples with additional context
  defp annotate_error({:ok, value}, _context), do: {:ok, value}

  defp annotate_error({:error, reason}, {context_type, context_value}),
    do: {:error, {context_type, context_value, reason}}
end
