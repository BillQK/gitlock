defmodule GitlockCore.Infrastructure.GitRepository do
  @moduledoc """
  Infrastructure for executing git commands and fetching logs.
  This module handles the HOW of getting git logs from various sources,
  but doesn't know anything about parsing them.
  """
  require Logger
  alias GitlockCore.Infrastructure.Workspace

  @default_log_options [
    "log",
    "--no-merges",
    "--numstat",
    "--date=short",
    "--pretty=format:commit %H%nAuthor: %an <%ae>%nDate: %ad"
  ]

  @doc """
  Fetch raw git log output from various sources.
  Sources can be:
  - File paths (reads the file)
  - Local repository paths (runs git log)
  - Remote URLs (uses workspace to clone first)
  """
  def fetch_log(source, options \\ %{}) do
    case determine_source_type(source) do
      :log_file ->
        fetch_from_file(source)

      :local_repo ->
        fetch_from_local_repo(source, options)

      :url ->
        fetch_from_remote_url(source, options)

      :unknown ->
        # Return error that can be transformed by Git adapter
        {:error, :enoent}
    end
  end

  @doc """
  Determine what type of source we're dealing with.
  Returns :log_file, :local_repo, :url, or :unknown
  """
  def determine_source_type(source) do
    cond do
      # Check if it's a remote URL
      String.match?(source, ~r/^(https?|git|ssh):\/\//) or String.ends_with?(source, ".git") ->
        :url

      # Check if it's a git repository
      File.dir?(source) && git_repo?(source) ->
        :local_repo

      # Check if it's a regular file
      File.regular?(source) ->
        :log_file

      # Check if path suggests it's a log file
      String.ends_with?(source, ".txt") or String.ends_with?(source, ".log") ->
        :log_file

      # Default for non-existent paths - assume they're files for backward compatibility
      true ->
        :unknown
    end
  end

  # Private Functions

  defp fetch_from_file(path) do
    Logger.debug("Reading git log from file: #{path}")
    File.read(path)
  end

  defp fetch_from_local_repo(repo_path, options) do
    Logger.debug("Generating git log from local repo: #{repo_path}")
    cmd_args = build_log_command(options)

    case System.cmd("git", cmd_args, cd: repo_path, stderr_to_stdout: true) do
      {output, 0} ->
        {:ok, output}

      {error, code} ->
        {:error, "Git log failed (#{code}): #{error}"}
    end
  end

  defp fetch_from_remote_url(url, options) do
    Logger.debug("Fetching git log from remote URL: #{url}")

    # Use workspace to handle cloning
    Workspace.with(url, options, fn workspace ->
      # Once we have the workspace, treat it as a local repo
      fetch_from_local_repo(workspace.path, options)
    end)
  end

  defp git_repo?(path) do
    git_dir = Path.join(path, ".git")
    File.dir?(git_dir) || File.regular?(git_dir)
  end

  defp build_log_command(options) do
    @default_log_options ++
      Enum.flat_map(options, fn
        {:since, date} -> ["--since=#{date}"]
        {:until, date} -> ["--until=#{date}"]
        {:after, date} -> ["--after=#{date}"]
        {:before, date} -> ["--before=#{date}"]
        {:max_count, n} -> ["-n", to_string(n)]
        {:author, name} -> ["--author=#{name}"]
        {:grep, pattern} -> ["--grep=#{pattern}"]
        {:path, path} -> ["--", path]
        _ -> []
      end)
  end
end
