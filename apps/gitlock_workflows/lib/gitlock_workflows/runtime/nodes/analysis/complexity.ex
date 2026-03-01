defmodule GitlockWorkflows.Runtime.Nodes.Analysis.Complexity do
  @moduledoc """
  Analysis node for computing cyclomatic complexity of repository files.

  Uses `git ls-tree` to list files and `git show HEAD:<path>` to read content
  from the git database. This works with both full clones and `--no-checkout`
  clones (which only have the `.git` directory).

  Accepts `repo_path` from the upstream Git Commits node so it analyzes the
  same repository without requiring a separate parameter.
  """
  use GitlockWorkflows.Runtime.Node
  require Logger

  alias GitlockCore.Adapters.Complexity.DispatchAnalyzer
  alias GitlockWorkflows.Executor

  @impl true
  def metadata do
    %{
      id: "gitlock.analysis.complexity",
      displayName: "Complexity Analysis",
      group: "analysis",
      version: 1,
      description: "Analyzes code complexity using the git database (works without checkout)",
      inputs: [
        %{
          name: "repo_path",
          type: :string,
          required: true,
          description: "Local path to the git repository (from Git Commits node)"
        }
      ],
      outputs: [
        %{
          name: "complexity_map",
          type: :map,
          description: "Map of file paths to complexity metrics"
        }
      ],
      parameters: []
    }
  end

  @impl true
  def execute(input_data, _parameters, context) do
    repo_path = input_data[:repo_path]

    if is_nil(repo_path) or repo_path == "" do
      {:error, "repo_path input is required — connect to a Git Commits node"}
    else
      analyze_from_git(repo_path, context)
    end
  end

  defp analyze_from_git(repo_path, context) do
    Executor.report_status(context, "Listing repository files...")

    supported_ext = DispatchAnalyzer.supported_extensions()

    case list_tracked_files(repo_path) do
      {:ok, all_files} ->
        # Filter to files with supported extensions (skip "*" wildcard from MockAnalyzer)
        real_ext = Enum.reject(supported_ext, &(&1 == "*"))

        files =
          Enum.filter(all_files, fn path ->
            Path.extname(path) in real_ext
          end)

        Executor.report_status(context, "Analyzing #{length(files)} source files...")

        complexity_map =
          files
          |> Task.async_stream(
            fn file_path ->
              case read_file_from_git(repo_path, file_path) do
                {:ok, content} ->
                  case DispatchAnalyzer.analyze_content(content, file_path) do
                    {:ok, metrics} -> {file_path, metrics}
                    {:error, _} -> nil
                  end

                {:error, _} ->
                  nil
              end
            end,
            max_concurrency: System.schedulers_online() * 2,
            on_timeout: :kill_task
          )
          |> Enum.reduce(%{}, fn
            {:ok, {path, metrics}}, acc -> Map.put(acc, path, metrics)
            {:ok, nil}, acc -> acc
            {:exit, _}, acc -> acc
          end)

        Executor.report_status(context, "Analyzed #{map_size(complexity_map)} files")
        {:ok, %{complexity_map: complexity_map}}

      {:error, reason} ->
        {:error, "Failed to list files: #{reason}"}
    end
  end

  # List all tracked files at HEAD using `git ls-tree`
  defp list_tracked_files(repo_path) do
    case System.cmd("git", ["ls-tree", "-r", "--name-only", "HEAD"],
           cd: repo_path,
           stderr_to_stdout: true
         ) do
      {output, 0} ->
        files =
          output
          |> String.split("\n", trim: true)

        {:ok, files}

      {error, code} ->
        {:error, "git ls-tree failed (#{code}): #{String.trim(error)}"}
    end
  end

  # Read a file's content at HEAD from the git database
  defp read_file_from_git(repo_path, file_path) do
    case System.cmd("git", ["show", "HEAD:#{file_path}"],
           cd: repo_path,
           stderr_to_stdout: true
         ) do
      {content, 0} -> {:ok, content}
      {error, _code} -> {:error, String.trim(error)}
    end
  end

  @impl true
  def validate_parameters(_parameters), do: :ok
end
