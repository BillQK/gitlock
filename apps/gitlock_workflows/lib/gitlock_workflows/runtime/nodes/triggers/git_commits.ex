defmodule GitlockWorkflows.Runtime.Nodes.Triggers.GitCommits do
  use GitlockWorkflows.Runtime.Node
  require Logger

  alias GitlockWorkflows.Executor

  @impl true
  def metadata do
    %{
      id: "gitlock.trigger.git_commits",
      displayName: "Git Commits Trigger",
      group: "trigger",
      version: 1,
      description: "Triggers workflow execution when analyzing git commit history",
      inputs: [],
      outputs: [
        %{
          name: "commits",
          type: {:list, :map},
          required: true,
          description: "Raw commits data"
        },
        %{
          name: "repo_path",
          type: :string,
          required: true,
          description: "Resolved local path to the git repository (for downstream nodes)"
        }
      ],
      parameters: [
        %{
          name: "repo_path",
          displayName: "Repository Path",
          type: "string",
          default: "",
          required: true,
          description: "Path to the git repository to analyze"
        }
      ]
    }
  end

  @impl true
  def execute(_input_data, parameters, context) do
    Logger.info("Git commits trigger started")

    repo_path = Map.get(parameters, "repo_path") || Map.get(parameters, :repo_path) || ""

    if repo_path == "" or is_nil(repo_path) do
      Logger.error("Repository path is empty or nil. Parameters: #{inspect(parameters)}")
      {:error, "Repository path is required"}
    else
      Logger.info("Fetching commits for repo: #{repo_path}")

      progress_fn = fn message ->
        Executor.report_status(context, message)
      end

      user_git_options = Map.get(parameters, "git_options", %{})

      git_options =
        user_git_options
        |> atomize_keys()
        |> Map.put(:progress_fn, progress_fn)

      filters = describe_filters(git_options)
      if filters != "", do: Executor.report_status(context, "Filters: #{filters}")

      case GitlockCore.Adapters.VCS.Git.get_commit_history(repo_path, git_options) do
        {:ok, commits} ->
          # Resolve the local path where git commands can run
          # (for remote URLs this is the clone directory)
          resolved_path = resolve_local_path(repo_path)

          Executor.report_status(context, "Parsed #{length(commits)} commits")
          Logger.info("Successfully fetched #{length(commits)} commits")
          {:ok, %{commits: commits, repo_path: resolved_path}}

        {:error, reason} ->
          Logger.error("Failed to fetch commits: #{inspect(reason)}")
          {:error, format_error(reason)}
      end
    end
  end

  # Resolve a repo source to a local path where git commands can be executed.
  # For remote URLs, this is the cached clone directory.
  # For local paths, it's the path itself.
  defp resolve_local_path(source) do
    if remote_url?(source) do
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

  defp remote_url?(path) do
    String.starts_with?(path, "https://") or
      String.starts_with?(path, "http://") or
      String.starts_with?(path, "git@") or
      String.starts_with?(path, "ssh://")
  end

  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {k, v} when is_binary(k) ->
        try do
          {String.to_existing_atom(k), v}
        rescue
          _ -> {String.to_atom(k), v}
        end

      {k, v} ->
        {k, v}
    end)
  end

  defp describe_filters(opts) do
    parts =
      []
      |> then(fn acc -> if opts[:since], do: ["since #{opts[:since]}" | acc], else: acc end)
      |> then(fn acc -> if opts[:until], do: ["until #{opts[:until]}" | acc], else: acc end)
      |> then(fn acc ->
        if opts[:max_count], do: ["last #{opts[:max_count]} commits" | acc], else: acc
      end)
      |> then(fn acc -> if opts[:path], do: ["path: #{opts[:path]}" | acc], else: acc end)
      |> Enum.reverse()

    Enum.join(parts, ", ")
  end

  defp format_error(reason) when is_binary(reason) do
    cond do
      String.contains?(reason, "clone failed") ->
        "Failed to clone repository. Check that the URL is correct and the repo is public."

      String.contains?(reason, "not a git repository") ->
        "The specified path is not a git repository."

      String.contains?(reason, "Could not resolve host") ->
        "Could not reach the repository host. Check your network connection."

      true ->
        reason
    end
  end

  defp format_error(reason), do: inspect(reason)

  @impl true
  def validate_parameters(parameters) do
    repo_path = Map.get(parameters, "repo_path") || Map.get(parameters, :repo_path) || ""

    case repo_path do
      "" -> {:error, "repo_path is required"}
      _ -> :ok
    end
  end
end
