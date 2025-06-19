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
  """
  def fetch_log(repo_path, options \\ %{}) do
    # Check if this repo is managed by a workspace (and thus cacheable)
    workspace =
      Store.list()
      |> Enum.find(fn ws -> ws[:path] == repo_path end)

    case workspace do
      %{id: workspace_id} ->
        # Get fresh workspace data from store to ensure we have latest cache
        workspace_data = Store.get(workspace_id)
        cache = workspace_data[:git_log_cache] || %{}
        fetch_with_cache(workspace_id, repo_path, options, cache)

      _ ->
        # No workspace, generate without caching
        generate_git_log(repo_path, options)
    end
  end

  # Private Functions

  defp fetch_with_cache(workspace_id, repo_path, options, cache_map) do
    options_hash = hash_options(options)
    cache_path = Map.get(cache_map, options_hash)

    with {:cached, path} when is_binary(path) <- {:cached, cache_path},
         {:ok, log} <- File.read(path) do
      Logger.info("Using cached git log from #{path}")
      {:ok, log}
    else
      _ ->
        # Generate and cache
        with {:ok, log} <- generate_git_log(repo_path, options) do
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

  defp generate_git_log(repo_path, options) do
    cond do
      not File.exists?(repo_path) ->
        {:error, "Git log failed (2): No such file or directory"}

      not File.dir?(repo_path) ->
        {:error, "Git log failed (20): Not a directory"}

      true ->
        Logger.debug("Generating git log from repo: #{repo_path}")
        cmd_args = build_log_command(options)

        case System.cmd("git", cmd_args, cd: repo_path, stderr_to_stdout: true) do
          {output, 0} -> {:ok, output}
          {error, code} -> {:error, "Git log failed (#{code}): #{error}"}
        end
    end
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
