defmodule GitlockWorkflows.Runtime.Nodes.Analysis.Hotspot do
  @moduledoc """
  Analysis node for detecting code hotspots in a repository.

  This node identifies files that are:
  - Frequently changed (high revision count)  
  - Complex (high cyclomatic complexity)
  - Large (high lines of code)
  - High risk (combination of above factors)

  When a `complexity_map` input is connected, it uses that directly.
  Otherwise, if `repo_path` is available, it automatically runs complexity
  analysis so users don't have to wire up a separate Complexity node.
  """
  use GitlockWorkflows.Runtime.Node
  require Logger

  alias GitlockCore.Domain.Services.HotspotDetection
  alias GitlockCore.Adapters.Complexity.DispatchAnalyzer
  alias GitlockWorkflows.Executor

  @impl true
  def metadata do
    %{
      id: "gitlock.analysis.hotspot",
      displayName: "Hotspot Analysis",
      group: "analysis",
      version: 1,
      description: "Analyzes code hotspots by examining change frequency and complexity",
      inputs: [
        %{
          name: "commits",
          type: {:list, :map},
          required: true,
          description: "Git commits data from trigger"
        },
        %{
          name: "repo_path",
          type: :string,
          required: false,
          description: "Repository path (used to auto-compute complexity if complexity_map is not provided)"
        },
        %{
          name: "complexity_map",
          type: :map,
          required: false,
          description: "Pre-computed complexity map (if not provided, will be computed automatically from repo_path)"
        }
      ],
      outputs: [
        %{
          name: "hotspots",
          type: {:list, :map},
          description: "List of hotspot analysis results"
        }
      ],
      parameters: []
    }
  end

  @impl true
  def execute(input_data, _parameters, context) do
    commits = input_data[:commits]
    repo_path = input_data[:repo_path] || resolve_repo_path(context[:repo_path])
    explicit_complexity_map = input_data[:complexity_map]

    if is_nil(commits) do
      {:error, "commits input is required"}
    else
      complexity_map = resolve_complexity_map(explicit_complexity_map, repo_path, context)

      Executor.report_status(context, "Analyzing #{length(commits)} commits...")
      hotspots = HotspotDetection.detect_hotspots(commits, complexity_map)
      Executor.report_status(context, "Found #{length(hotspots)} hotspots")

      {:ok, %{hotspots: hotspots}}
    end
  end

  # Use explicit complexity_map if provided
  defp resolve_complexity_map(map, _repo_path, _context) when is_map(map) and map_size(map) > 0 do
    map
  end

  # Otherwise, auto-compute from repo_path
  defp resolve_complexity_map(_nil_or_empty, repo_path, context)
       when is_binary(repo_path) and repo_path != "" do
    Executor.report_status(context, "Computing complexity metrics...")
    compute_complexity_from_git(repo_path, context)
  end

  # No complexity data available at all
  defp resolve_complexity_map(_, _, _), do: %{}

  defp compute_complexity_from_git(repo_path, context) do
    supported_ext =
      DispatchAnalyzer.supported_extensions()
      |> Enum.reject(&(&1 == "*"))

    case list_tracked_files(repo_path) do
      {:ok, all_files} ->
        files = Enum.filter(all_files, fn path -> Path.extname(path) in supported_ext end)
        Executor.report_status(context, "Analyzing complexity of #{length(files)} files...")

        files
        |> Task.async_stream(
          fn file_path ->
            with {:ok, content} <- read_file_from_git(repo_path, file_path),
                 {:ok, metrics} <- DispatchAnalyzer.analyze_content(content, file_path) do
              {file_path, metrics}
            else
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

      {:error, reason} ->
        Logger.warning("Could not list repo files for complexity: #{reason}")
        %{}
    end
  end

  defp list_tracked_files(repo_path) do
    case System.cmd("git", ["ls-tree", "-r", "--name-only", "HEAD"],
           cd: repo_path,
           stderr_to_stdout: true
         ) do
      {output, 0} -> {:ok, String.split(output, "\n", trim: true)}
      {error, code} -> {:error, "git ls-tree failed (#{code}): #{String.trim(error)}"}
    end
  end

  defp read_file_from_git(repo_path, file_path) do
    case System.cmd("git", ["show", "HEAD:#{file_path}"],
           cd: repo_path,
           stderr_to_stdout: true
         ) do
      {content, 0} -> {:ok, content}
      {error, _code} -> {:error, String.trim(error)}
    end
  end

  # Resolve a repo source to a local path where git commands can run.
  # For remote URLs, this is the cached clone directory.
  # For local paths, return as-is.
  defp resolve_repo_path(nil), do: nil
  defp resolve_repo_path(""), do: nil

  defp resolve_repo_path(source) do
    if String.starts_with?(source, "https://") or
         String.starts_with?(source, "http://") or
         String.starts_with?(source, "git@") or
         String.starts_with?(source, "ssh://") do
      hash =
        :crypto.hash(:sha256, source)
        |> Base.url_encode64(padding: false)
        |> String.slice(0..11)

      repo_name =
        source
        |> String.split("/")
        |> List.last()
        |> String.replace(~r/\.git$/, "")

      Path.join([System.tmp_dir!(), "gitlock", "clones", "#{repo_name}_#{hash}"])
    else
      source
    end
  end

  @impl true
  def validate_parameters(_parameters) do
    :ok
  end
end
