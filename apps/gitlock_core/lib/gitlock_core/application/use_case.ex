defmodule GitlockCore.Application.UseCase do
  @moduledoc """
  Base module for application use cases - orchestrates domain logic
  """
  @callback resolve_dependencies(map()) :: {:ok, map()} | {:error, String.t()}
  @callback run_domain_logic(String.t(), map(), map()) :: {:ok, any()} | {:error, String.t()}
  @callback format_result(any(), map(), map()) :: {:ok, String.t()} | {:error, String.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour GitlockCore.Application.UseCase
      alias GitlockCore.Infrastructure.AdapterRegistry
      alias GitlockCore.Infrastructure.Workspace

      @spec execute(String.t(), map()) :: {:ok, String.t()} | {:error, String.t()}
      def execute(repo_path, options) do
        workspace_opts = Map.to_list(options) |> Keyword.take([:depth, :branch, :timeout])

        Workspace.with(repo_path, workspace_opts, fn workspace ->
          with {:ok, dependencies} <- resolve_dependencies(options),
               {:ok, domain_result} <- run_domain_logic(workspace.path, dependencies, options) do
            {:ok, format_result} = format_result(domain_result, dependencies, options)
          end
        end)
      end

      defoverridable execute: 2
    end
  end
end
