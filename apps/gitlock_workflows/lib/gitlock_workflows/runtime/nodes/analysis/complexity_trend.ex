defmodule GitlockWorkflows.Runtime.Nodes.Analysis.ComplexityTrend do
  @moduledoc """
  Analysis node for detecting complexity trends in hotspot files.

  This is the "X-Ray" analysis — it reveals whether hotspot files are
  getting more complex over time, stable, or improving. It samples
  historical file content at monthly intervals and runs complexity
  analysis on each snapshot.

  Requires `repo_path` as a parameter (injected by the compiler) since
  it needs to run `git show` to retrieve historical file content.
  """
  use GitlockWorkflows.Runtime.Node
  require Logger

  alias GitlockCore.Domain.Services.ComplexityTrendAnalysis
  alias GitlockWorkflows.Executor

  @impl true
  def metadata do
    %{
      id: "gitlock.analysis.complexity_trend",
      displayName: "Complexity Trends",
      group: "analysis",
      version: 1,
      description: "X-ray hotspot files to reveal complexity trajectories over time",
      inputs: [
        %{
          name: "commits",
          type: {:list, :map},
          required: true,
          description: "Git commits data from trigger"
        }
      ],
      outputs: [
        %{
          name: "complexity_trends",
          type: {:list, :map},
          description: "Complexity trend for each hotspot file"
        }
      ],
      parameters: [
        %{
          name: "repo_path",
          displayName: "Repository Path",
          type: "string",
          default: "",
          required: true,
          description: "Path to git repository (injected automatically)"
        },
        %{
          name: "max_files",
          displayName: "Max Files",
          type: "number",
          default: "15",
          required: false,
          description: "Number of top hotspot files to analyze"
        },
        %{
          name: "interval_days",
          displayName: "Sample Interval (days)",
          type: "number",
          default: "30",
          required: false,
          description: "Days between complexity sample points"
        }
      ]
    }
  end

  @impl true
  def execute(input_data, parameters, context) do
    commits = input_data[:commits]

    repo_path =
      Map.get(parameters, "repo_path") || Map.get(parameters, :repo_path) || ""

    if is_nil(commits) or commits == [] do
      {:error, "commits input is required"}
    else
      if repo_path == "" do
        {:error, "repo_path parameter is required for complexity trend analysis"}
      else
        max_files = parse_int(parameters, "max_files", 15)
        interval_days = parse_int(parameters, "interval_days", 30)

        progress_fn = fn message ->
          Executor.report_status(context, message)
        end

        Executor.report_status(context, "Starting complexity trend analysis...")

        trends =
          ComplexityTrendAnalysis.analyze(commits, repo_path,
            max_files: max_files,
            interval_days: interval_days,
            progress_fn: progress_fn
          )

        rising = Enum.count(trends, &(&1.direction == :rising))
        declining = Enum.count(trends, &(&1.direction == :declining))

        Executor.report_status(
          context,
          "Found #{length(trends)} trends: #{rising} rising, #{declining} declining"
        )

        {:ok, %{complexity_trends: trends}}
      end
    end
  end

  @impl true
  def validate_parameters(_parameters), do: :ok

  defp parse_int(params, key, default) do
    val = Map.get(params, key) || Map.get(params, String.to_atom(key))

    case val do
      nil ->
        default

      v when is_integer(v) ->
        v

      v when is_binary(v) ->
        case Integer.parse(v) do
          {n, _} -> n
          :error -> default
        end

      _ ->
        default
    end
  end
end
