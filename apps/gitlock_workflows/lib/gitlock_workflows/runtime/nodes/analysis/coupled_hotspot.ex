defmodule GitlockWorkflows.Runtime.Nodes.Analysis.CoupledHotspot do
  @moduledoc "Finds hotspots that are temporally coupled."
  use GitlockWorkflows.Runtime.Node
  require Logger

  alias GitlockCore.Domain.Services.{CoupledHotspotAnalysis, FileHistoryService}
  alias GitlockCore.Adapters.Complexity.DispatchAnalyzer
  alias GitlockWorkflows.Executor

  @impl true
  def metadata do
    %{
      id: "gitlock.analysis.coupled_hotspot",
      displayName: "Coupled Hotspots",
      group: "analysis",
      version: 1,
      description: "Finds hotspots that are temporally coupled",
      inputs: [
        %{name: "commits", type: {:list, :map}, required: true},
        %{name: "repo_path", type: :string, required: false,
          description: "Repository path (used to auto-compute complexity if complexity_map is not provided)"},
        %{name: "complexity_map", type: {:list, :map}, required: false}
      ],
      outputs: [%{name: "coupled_hotspots", type: {:list, :map}}],
      parameters: []
    }
  end

  @impl true
  def execute(input_data, _parameters, context) do
    commits = input_data[:commits]
    repo_path = input_data[:repo_path] || resolve_repo_path(context[:repo_path])
    explicit_complexity_map = input_data[:complexity_map]

    if is_nil(commits), do: throw({:error, "commits input is required"})

    complexity_map = resolve_complexity_map(explicit_complexity_map, repo_path, context)

    Executor.report_status(context, "Building file history...")
    history = FileHistoryService.build_history(commits)
    normalized = FileHistoryService.normalize_commits(commits, history)

    Executor.report_status(context, "Detecting coupled hotspots...")
    results = CoupledHotspotAnalysis.detect_combined(normalized, complexity_map)

    Executor.report_status(context, "Found #{length(results)} coupled hotspots")
    {:ok, %{coupled_hotspots: results}}
  catch
    {:error, reason} -> {:error, reason}
  end

  defp resolve_complexity_map(map, _repo_path, _context)
       when is_map(map) and map_size(map) > 0,
       do: map

  defp resolve_complexity_map(_nil_or_empty, repo_path, context)
       when is_binary(repo_path) and repo_path != "" do
    Executor.report_status(context, "Computing complexity metrics...")
    compute_complexity_from_git(repo_path, context)
  end

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
           cd: repo_path, stderr_to_stdout: true) do
      {output, 0} -> {:ok, String.split(output, "\n", trim: true)}
      {error, code} -> {:error, "git ls-tree failed (#{code}): #{String.trim(error)}"}
    end
  end

  defp read_file_from_git(repo_path, file_path) do
    case System.cmd("git", ["show", "HEAD:#{file_path}"],
           cd: repo_path, stderr_to_stdout: true) do
      {content, 0} -> {:ok, content}
      {error, _code} -> {:error, String.trim(error)}
    end
  end

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
  def validate_parameters(_parameters), do: :ok
end
