defmodule GitlockWorkflows.Runtime.Nodes.Analysis.Coupling do
  @moduledoc "Detects files that change together (temporal coupling)."
  use GitlockWorkflows.Runtime.Node
  require Logger

  alias GitlockCore.Domain.Services.{CouplingDetection, FileHistoryService}
  alias GitlockWorkflows.Executor

  @impl true
  def metadata do
    %{
      id: "gitlock.analysis.coupling",
      displayName: "Coupling Detection",
      group: "analysis",
      version: 1,
      description: "Detects files that change together (temporal coupling)",
      inputs: [%{name: "commits", type: {:list, :map}, required: true}],
      outputs: [%{name: "couplings", type: {:list, :map}}],
      parameters: [
        %{
          name: "min_coupling",
          displayName: "Min coupling score",
          type: "number",
          default: 1.0,
          required: false
        },
        %{
          name: "min_windows",
          displayName: "Min time windows",
          type: "number",
          default: 5,
          required: false
        }
      ]
    }
  end

  @impl true
  def execute(input_data, parameters, context) do
    commits = input_data[:commits]
    if is_nil(commits), do: throw({:error, "commits input is required"})

    min_coupling = Map.get(parameters, "min_coupling", 1.0)
    min_windows = Map.get(parameters, "min_windows", 5)

    Executor.report_status(context, "Building file history...")
    history = FileHistoryService.build_history(commits)
    normalized = FileHistoryService.normalize_commits(commits, history)

    Executor.report_status(context, "Detecting temporal couplings...")
    results = CouplingDetection.detect_couplings(normalized, min_coupling, min_windows)

    Executor.report_status(context, "Found #{length(results)} couplings")
    {:ok, %{couplings: results}}
  catch
    {:error, reason} -> {:error, reason}
  end

  @impl true
  def validate_parameters(_parameters), do: :ok
end
