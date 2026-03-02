defmodule GitlockWorkflows.Runtime.Nodes.Analysis.KnowledgeSilo do
  @moduledoc "Identifies concentrated code ownership patterns."
  use GitlockWorkflows.Runtime.Node
  require Logger

  alias GitlockCore.Domain.Services.{KnowledgeSiloDetection, FileHistoryService}
  alias GitlockWorkflows.Executor

  @impl true
  def metadata do
    %{
      id: "gitlock.analysis.knowledge_silo",
      displayName: "Knowledge Silos",
      group: "analysis",
      version: 1,
      description: "Identifies concentrated code ownership patterns",
      inputs: [%{name: "commits", type: {:list, :map}, required: true}],
      outputs: [%{name: "knowledge_silos", type: {:list, :map}}],
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

    Executor.report_status(context, "Detecting knowledge silos...")
    results = KnowledgeSiloDetection.detect_knowledge_silos(normalized)

    Executor.report_status(context, "Found #{length(results)} silos")
    {:ok, %{knowledge_silos: results}}
  catch
    {:error, reason} -> {:error, reason}
  end

  @impl true
  def validate_parameters(_parameters), do: :ok
end
