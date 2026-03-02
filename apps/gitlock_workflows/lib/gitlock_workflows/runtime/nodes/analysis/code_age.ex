defmodule GitlockWorkflows.Runtime.Nodes.Analysis.CodeAge do
  @moduledoc "Analyzes how recently code was modified."
  use GitlockWorkflows.Runtime.Node
  require Logger

  alias GitlockCore.Domain.Services.{CodeAgeAnalysis, FileHistoryService}
  alias GitlockWorkflows.Executor

  @impl true
  def metadata do
    %{
      id: "gitlock.analysis.code_age",
      displayName: "Code Age",
      group: "analysis",
      version: 1,
      description: "Analyzes how recently code was modified",
      inputs: [%{name: "commits", type: {:list, :map}, required: true}],
      outputs: [%{name: "code_age", type: {:list, :map}}],
      parameters: []
    }
  end

  @impl true
  def execute(input_data, _parameters, context) do
    commits = input_data[:commits]
    if is_nil(commits), do: throw({:error, "commits input is required"})

    Executor.report_status(context, "Building file history...")
    history = FileHistoryService.build_history(commits)
    normalized = FileHistoryService.normalize_commits(commits, history)

    Executor.report_status(context, "Calculating code age...")
    results = CodeAgeAnalysis.calculate_code_age(normalized)

    Executor.report_status(context, "Analyzed #{length(results)} files")
    {:ok, %{code_age: results}}
  catch
    {:error, reason} -> {:error, reason}
  end

  @impl true
  def validate_parameters(_parameters), do: :ok
end
