defmodule GitlockHolmesCore do
  @moduledoc """
  GitlockHolmes is a forensic code analysis tool inspired by Adam Tornhill's
  "Your Code as Crime Scene" methodology.
  This module provides the main entry points for using the library programmatically.
  """

  alias GitlockHolmesCore.Application.UseCaseFactory

  @spec investigate(atom(), String.t(), map()) :: {:ok, String.t()} | {:error, String.t()}
  def investigate(investigation_type, repo_path, opts \\ %{}) do
    with {:ok, use_case} <- UseCaseFactory.create_use_case(investigation_type) do
      use_case.execute(repo_path, opts)
    end
  end

  @spec available_investigations() :: [atom()]
  def available_investigations, do: UseCaseFactory.available_investigations()
end
