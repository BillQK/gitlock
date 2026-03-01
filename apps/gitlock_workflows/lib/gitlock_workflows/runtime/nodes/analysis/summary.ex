defmodule GitlockWorkflows.Runtime.Nodes.Analysis.Summary do
  @moduledoc "Generates a summary of repository activity."
  use GitlockWorkflows.Runtime.Node
  require Logger

  alias GitlockCore.Domain.Services.{Summary, FileHistoryService}
  alias GitlockWorkflows.Executor

  @impl true
  def metadata do
    %{
      id: "gitlock.analysis.summary",
      displayName: "Summary",
      group: "analysis",
      version: 1,
      description: "Generates a summary of repository activity",
      inputs: [%{name: "commits", type: {:list, :map}, required: true}],
      outputs: [%{name: "summary", type: :map}],
      parameters: []
    }
  end

  @impl true
  def execute(input_data, _parameters, context) do
    commits = input_data[:commits]
    if is_nil(commits), do: throw({:error, "commits input is required"})

    Executor.report_status(context, "Summarizing #{length(commits)} commits...")
    history = FileHistoryService.build_history(commits)
    normalized = FileHistoryService.normalize_commits(commits, history)
    results = Summary.summarize(normalized)

    Executor.report_status(context, "Summary complete")
    {:ok, %{summary: results}}
  catch
    {:error, reason} -> {:error, reason}
  end

  @impl true
  def validate_parameters(_parameters), do: :ok
end
