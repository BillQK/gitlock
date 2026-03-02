defmodule GitlockCore.Infrastructure.GitRepository do
  @moduledoc """
  Infrastructure for executing git commands and fetching logs.
  This module handles the HOW of getting git logs from repositories,
  but doesn't know anything about parsing them.

  Includes transparent caching of git logs to disk for performance.
  """
  require Logger
  alias GitlockCore.Infrastructure.Workspace.Store

  @default_log_options [
    "log",
    "--no-merges",
    "--numstat",
    "--date=short",
    "--pretty=format:commit %H%nAuthor: %an <%ae>%nDate: %ad"
  ]

  @doc """
  Fetch raw git log output from a git repository.

  Automatically caches git logs for workspace-managed repositories.

  ## Options

    * `:progress_fn` - Optional `fn(message :: String.t()) -> :ok` for status updates
  """
  def fetch_log(repo_path, options \\ %{}) do
    progress_fn = Map.get(options, :progress_fn, fn _ -> :ok end)
    git_options = Map.delete(options, :progress_fn)

    # Check if this repo is managed by a workspace (and thus cacheable)
    workspace =
      Store.list()
      |> Enum.find(fn ws -> ws[:path] == repo_path end)

    case workspace do
      %{id: workspace_id} ->
        # Get fresh workspace data from store to ensure we have latest cache
        workspace_data = Store.get(workspace_id)
        cache = workspace_data[:git_log_cache] || %{}
        fetch_with_cache(workspace_id, repo_path, git_options, cache, progress_fn)

      _ ->
        # No workspace, generate without caching
        generate_git_log(repo_path, git_options, progress_fn)
    end
  end

  # Private Functions

  defp fetch_with_cache(workspace_id, repo_path, options, cache_map, progress_fn) do
    options_hash = hash_options(options)
    cache_path = Map.get(cache_map, options_hash)

    with {:cached, path} when is_binary(path) <- {:cached, cache_path},
         {:ok, log} <- File.read(path) do
      Logger.info("Using cached git log from #{path}")
      progress_fn.("Using cached git log")
      {:ok, log}
    else
      _ ->
        # Generate and cache
        with {:ok, log} <- generate_git_log(repo_path, options, progress_fn) do
          cache_path = build_cache_path(workspace_id, options_hash)

          case save_log_to_cache(cache_path, log) do
            :ok ->
              add_cache_path(workspace_id, options_hash, cache_path)
              Logger.info("Successfully cached git log for workspace #{workspace_id}")

            {:error, reason} ->
              Logger.warning("Failed to cache git log: #{inspect(reason)}")
          end

          {:ok, log}
        end
    end
  end

  defp generate_git_log(repo_path, options, progress_fn) do
    cond do
      remote_url?(repo_path) ->
        generate_from_remote(repo_path, options, progress_fn)

      not File.exists?(repo_path) ->
        {:error, "Git log failed (2): No such file or directory"}

      not File.dir?(repo_path) ->
        {:error, "Git log failed (20): Not a directory"}

      true ->
        progress_fn.("Reading git log...")
        run_git_log(repo_path, options)
    end
  end

  defp run_git_log(local_path, options) do
    Logger.debug("Generating git log from repo: #{local_path}")
    cmd_args = build_log_command(options)

    case System.cmd("git", cmd_args, cd: local_path, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {error, code} -> {:error, "Git log failed (#{code}): #{error}"}
    end
  end

  defp remote_url?(path) do
    String.starts_with?(path, "https://") or
      String.starts_with?(path, "http://") or
      String.starts_with?(path, "git@") or
      String.starts_with?(path, "ssh://")
  end

  defp generate_from_remote(url, options, progress_fn) do
    clone_dir = clone_path_for(url)
    repo_name = url |> String.split("/") |> Enum.take(-2) |> Enum.join("/")

    if File.dir?(Path.join(clone_dir, ".git")) do
      progress_fn.("Fetching updates for #{repo_name}...")
      Logger.info("Using existing clone at #{clone_dir}, fetching updates...")

      case System.cmd("git", ["fetch", "--all"], cd: clone_dir, stderr_to_stdout: true) do
        {_, 0} -> :ok
        {err, _} -> Logger.warning("git fetch failed (non-fatal): #{err}")
      end

      progress_fn.("Reading git log...")
      run_git_log(clone_dir, options)
    else
      progress_fn.("Cloning #{repo_name}...")
      Logger.info("Cloning #{url} into #{clone_dir}...")
      File.mkdir_p!(Path.dirname(clone_dir))

      case System.cmd("git", ["clone", "--no-checkout", url, clone_dir],
             stderr_to_stdout: true,
             env: [{"GIT_TERMINAL_PROMPT", "0"}]
           ) do
        {_, 0} ->
          progress_fn.("Clone complete, reading git log...")
          Logger.info("Clone complete")
          run_git_log(clone_dir, options)

        {error, code} ->
          {:error, "Git clone failed (#{code}): #{String.trim(error)}"}
      end
    end
  end

  defp clone_path_for(url) do
    hash =
      :crypto.hash(:sha256, url)
      |> Base.url_encode64(padding: false)
      |> String.slice(0..11)

    repo_name =
      url
      |> String.split("/")
      |> List.last()
      |> String.replace(~r/\.git$/, "")

    Path.join([System.tmp_dir!(), "gitlock", "clones", "#{repo_name}_#{hash}"])
  end

  defp add_cache_path(workspace_id, options_hash, cache_path) do
    workspace = Store.get(workspace_id)
    cache = workspace[:git_log_cache] || %{}
    updated_cache = Map.put(cache, options_hash, cache_path)

    Store.update(workspace_id, %{git_log_cache: updated_cache})
  end

  defp hash_options(options) do
    # Create a deterministic hash of the options
    options
    |> Enum.sort()
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.url_encode64(padding: false)
    |> String.slice(0..7)
  end

  defp build_cache_path(workspace_id, options_hash) do
    workspace = Store.get(workspace_id)

    case workspace do
      %{path: workspace_path} when is_binary(workspace_path) ->
        # Store cache inside the workspace directory
        Path.join([workspace_path, ".gitlock_cache", "log_#{options_hash}.txt"])

      _ ->
        # Fallback to temp directory
        Path.join([
          System.tmp_dir!(),
          "gitlock",
          "cache",
          workspace_id,
          "log_#{options_hash}.txt"
        ])
    end
  end

  defp save_log_to_cache(cache_path, log_content) do
    cache_dir = Path.dirname(cache_path)

    with :ok <- File.mkdir_p(cache_dir),
         :ok <- File.write(cache_path, log_content) do
      Logger.debug("Cached git log to #{cache_path}")
      :ok
    else
      error ->
        Logger.warning("Failed to cache git log: #{inspect(error)}")
        error
    end
  end

  @doc """
  Get the content of a file at a specific revision.

  Uses `git show <revision>:<path>` to retrieve historical file content.

  ## Parameters
    * `repo_path` - Path to the git repository
    * `revision` - Git revision (SHA, tag, branch)
    * `file_path` - Path to the file relative to repo root

  ## Returns
    * `{:ok, content}` - File content as string
    * `{:error, reason}` - If the file doesn't exist at that revision
  """
  def file_at_revision(repo_path, revision, file_path) do
    repo_dir = resolve_repo_dir(repo_path)

    case System.cmd("git", ["show", "#{revision}:#{file_path}"],
           cd: repo_dir,
           stderr_to_stdout: true
         ) do
      {content, 0} -> {:ok, content}
      {error, _code} -> {:error, String.trim(error)}
    end
  end

  @doc """
  Find the nearest commit SHA to a given date.

  Returns the SHA of the last commit on or before `date`.
  """
  def commit_at_date(repo_path, date) do
    repo_dir = resolve_repo_dir(repo_path)
    date_str = Date.to_iso8601(date)

    case System.cmd("git", ["log", "--before=#{date_str}T23:59:59", "--format=%H", "-1"],
           cd: repo_dir,
           stderr_to_stdout: true
         ) do
      {"", 0} -> {:error, :no_commit}
      {"\n", 0} -> {:error, :no_commit}
      {sha, 0} -> {:ok, String.trim(sha)}
      {error, _} -> {:error, String.trim(error)}
    end
  end

  @doc """
  Get the date range of the repository (earliest and latest commit dates).
  """
  def date_range(repo_path) do
    repo_dir = resolve_repo_dir(repo_path)

    with {:ok, earliest} <- earliest_commit_date(repo_dir),
         {:ok, latest} <- latest_commit_date(repo_dir) do
      {:ok, earliest, latest}
    end
  end

  defp earliest_commit_date(repo_dir) do
    case System.cmd("git", ["log", "--reverse", "--format=%ad", "--date=short", "-1"],
           cd: repo_dir,
           stderr_to_stdout: true
         ) do
      {date_str, 0} ->
        date_str |> String.trim() |> Date.from_iso8601()

      {error, _} ->
        {:error, String.trim(error)}
    end
  end

  defp latest_commit_date(repo_dir) do
    case System.cmd("git", ["log", "--format=%ad", "--date=short", "-1"],
           cd: repo_dir,
           stderr_to_stdout: true
         ) do
      {date_str, 0} ->
        date_str |> String.trim() |> Date.from_iso8601()

      {error, _} ->
        {:error, String.trim(error)}
    end
  end

  defp resolve_repo_dir(repo_path) do
    if remote_url?(repo_path), do: clone_path_for(repo_path), else: repo_path
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
