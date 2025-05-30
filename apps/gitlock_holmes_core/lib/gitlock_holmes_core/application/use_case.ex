defmodule GitlockHolmesCore.Application.UseCase do
  @moduledoc """
  Base module for application use cases - orchestrates domain logic
  """
  @callback resolve_dependencies(map()) :: {:ok, map()} | {:error, String.t()}
  @callback run_domain_logic(String.t(), map(), map()) :: {:ok, any()} | {:error, String.t()}
  @callback format_result(any(), map(), map()) :: {:ok, String.t()} | {:error, String.t()}

  defmacro __using__(_opts) do
    quote do
      @behaviour GitlockHolmesCore.Application.UseCase
      alias GitlockHolmesCore.Infrastructure.AdapterRegistry

      @spec execute(String.t(), map()) :: {:ok, String.t()} | {:error, String.t()}
      def execute(repo_path, options) do
        with {:ok, dependencies} <- resolve_dependencies(options),
             {:ok, domain_result} <- run_domain_logic(repo_path, dependencies, options),
             {:ok, formatted_result} <- format_result(domain_result, dependencies, options) do
          {:ok, formatted_result}
        end
      end

      defoverridable execute: 2
    end
  end
end
