defmodule GitlockHolmesCore do
  @moduledoc """
  GitlockHolmes is a forensic code analysis tool inspired by Adam Tornhill's
  "Your Code as Crime Scene" methodology.
  This module provides the main entry points for using the library programmatically.
  """

  @doc "Delegates to the core investigation flow"
  @spec investigate(atom(), String.t(), map()) :: {:ok, any()} | {:error, String.t()}
  defdelegate investigate(investigation_type, repo_path, opts \\ %{}),
    to: GitlockHolmesCore.Core.Coordinator,
    as: :investigate
end
