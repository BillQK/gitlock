# DEPRECATED: This module has moved to GitlockWorkflows.Executor
# Delete this file and the pipeline/ directory.
#
# All references have been updated:
#   - WorkflowLive uses GitlockWorkflows.Executor
#   - AnalyzeLive uses GitlockWorkflows.Executor
defmodule GitlockPhx.Pipeline.Executor do
  @moduledoc false
  @deprecated "Use GitlockWorkflows.Executor instead"

  defdelegate run(pipeline, repo_path, caller \\ self(), options \\ %{}),
    to: GitlockWorkflows.Executor

  defdelegate run_sync(pipeline, repo_path, options \\ %{}),
    to: GitlockWorkflows.Executor
end
