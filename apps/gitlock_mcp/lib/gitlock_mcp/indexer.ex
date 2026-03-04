defmodule GitlockMCP.Indexer do
  @moduledoc """
  Orchestrates the full analysis pipeline for a repository.

  Calls into gitlock_core services to parse git history, detect hotspots,
  coupling, knowledge silos, and complexity. Returns a structured map
  that the Cache stores for instant tool queries.
  """
  require Logger

  alias GitlockCore.Adapters.VCS.Git
  alias GitlockCore.Domain.Services.HotspotDetection
  alias GitlockCore.Domain.Services.CouplingDetection
  alias GitlockCore.Domain.Services.KnowledgeSiloDetection
  alias GitlockCore.Domain.Services.CodeAgeAnalysis
  alias GitlockCore.Domain.Services.Summary
  alias GitlockCore.Adapters.Complexity.DispatchAnalyzer
  alias GitlockCore.Infrastructure.Workspace

  @type index_result :: %{
          commits: list(),
          hotspots: list(),
          couplings: list(),
          knowledge_silos: list(),
          complexity_map: map(),
          code_age: list(),
          summary: map()
        }

  @doc """
  Indexes a repository by running all analyses.

  Returns `{:ok, data}` with pre-computed analysis results, or
  `{:error, reason}` if git history can't be loaded.
  """
  @spec index(String.t()) :: {:ok, index_result()} | {:error, term()}
  def index(repo_path) do
    Logger.info("Indexing repository: #{repo_path}")
    start = System.monotonic_time(:millisecond)

    with {:ok, workspace} <- resolve_workspace(repo_path),
         {:ok, commits} <- load_commits(workspace.path) do
      path = workspace.path
      Logger.info("Loaded #{length(commits)} commits from #{path}")

      # Run analyses concurrently
      tasks = %{
        hotspots: Task.async(fn -> run_hotspots(commits, path) end),
        couplings: Task.async(fn -> run_couplings(commits) end),
        silos: Task.async(fn -> run_knowledge_silos(commits) end),
        code_age: Task.async(fn -> run_code_age(commits) end),
        summary: Task.async(fn -> run_summary(commits) end),
        complexity: Task.async(fn -> run_complexity(path) end)
      }

      # Await all with generous timeout
      results =
        Map.new(tasks, fn {key, task} ->
          {key, Task.await(task, 120_000)}
        end)

      elapsed = System.monotonic_time(:millisecond) - start
      Logger.info("Indexing complete in #{elapsed}ms")

      {:ok,
       %{
         commits: commits,
         hotspots: results.hotspots,
         couplings: results.couplings,
         knowledge_silos: results.silos,
         complexity_map: results.complexity,
         code_age: results.code_age,
         summary: results.summary
       }}
    end
  end

  # ── Private ──────────────────────────────────────────────────

  defp resolve_workspace(repo_path) do
    cond do
      File.dir?(Path.join(repo_path, ".git")) ->
        # Local repo — use directly
        {:ok, %{path: repo_path}}

      String.starts_with?(repo_path, "http") or String.starts_with?(repo_path, "git@") ->
        # Remote URL — clone via workspace manager
        Workspace.acquire(repo_path)

      File.dir?(repo_path) ->
        # Directory without .git — try anyway
        {:ok, %{path: repo_path}}

      true ->
        {:error, "Cannot resolve repository: #{repo_path}"}
    end
  end

  defp load_commits(path) do
    Git.get_commit_history(path, %{})
  end

  defp run_hotspots(commits, repo_path) do
    complexity_map = build_complexity_map(repo_path)
    HotspotDetection.detect_hotspots(commits, complexity_map)
  end

  defp run_couplings(commits) do
    CouplingDetection.detect_couplings(commits)
  rescue
    _ -> []
  end

  defp run_knowledge_silos(commits) do
    KnowledgeSiloDetection.detect_knowledge_silos(commits)
  rescue
    _ -> []
  end

  defp run_code_age(commits) do
    CodeAgeAnalysis.calculate_code_age(commits)
  rescue
    _ -> []
  end

  defp run_summary(commits) do
    Summary.summarize(commits)
  rescue
    _ -> %{}
  end

  defp run_complexity(repo_path) do
    build_complexity_map(repo_path)
  end

  defp build_complexity_map(repo_path) do
    supported_ext = DispatchAnalyzer.supported_extensions() |> Enum.reject(&(&1 == "*"))

    case list_tracked_files(repo_path) do
      {:ok, files} ->
        source_files = Enum.filter(files, fn path -> Path.extname(path) in supported_ext end)

        # Write files to a temp dir so DispatchAnalyzer.analyze_file/1 can read them
        tmp_dir = Path.join(System.tmp_dir!(), "gitlock_complexity_#{:rand.uniform(100_000)}")
        File.mkdir_p!(tmp_dir)

        try do
          # Extract files from git into temp dir
          source_files
          |> Task.async_stream(
            fn file_path ->
              tmp_path = Path.join(tmp_dir, file_path)
              File.mkdir_p!(Path.dirname(tmp_path))

              case read_file_from_git(repo_path, file_path) do
                {:ok, content} -> File.write!(tmp_path, content); file_path
                _ -> nil
              end
            end,
            max_concurrency: System.schedulers_online() * 2,
            on_timeout: :kill_task
          )
          |> Enum.reduce([], fn
            {:ok, nil}, acc -> acc
            {:ok, path}, acc -> [path | acc]
            _, acc -> acc
          end)

          # Now analyze from the temp dir
          source_files
          |> Task.async_stream(
            fn file_path ->
              tmp_path = Path.join(tmp_dir, file_path)

              case DispatchAnalyzer.analyze_file(tmp_path) do
                {:ok, metrics} -> {file_path, metrics}
                _ -> nil
              end
            end,
            max_concurrency: System.schedulers_online() * 2,
            on_timeout: :kill_task
          )
          |> Enum.reduce(%{}, fn
            {:ok, {path, metrics}}, acc -> Map.put(acc, path, metrics)
            _, acc -> acc
          end)
        after
          File.rm_rf(tmp_dir)
        end

      {:error, _} ->
        %{}
    end
  rescue
    _ -> %{}
  end

  defp list_tracked_files(repo_path) do
    case System.cmd("git", ["ls-tree", "-r", "--name-only", "HEAD"],
           cd: repo_path,
           stderr_to_stdout: true
         ) do
      {output, 0} -> {:ok, String.split(output, "\n", trim: true)}
      {error, _} -> {:error, error}
    end
  end

  defp read_file_from_git(repo_path, file_path) do
    case System.cmd("git", ["show", "HEAD:#{file_path}"],
           cd: repo_path,
           stderr_to_stdout: true
         ) do
      {content, 0} -> {:ok, content}
      {error, _} -> {:error, error}
    end
  end
end
