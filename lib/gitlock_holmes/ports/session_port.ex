defmodule GitlockHolmes.Ports.SessionPort do
  @moduledoc """
  Interface for managing analysis sessions/process.
  """

  @doc "Creates a new analysis session"
  @callback create_session(repo_path :: String.t(), options :: map()) ::
              {:ok, session_id :: String.t()} | {:error, reason :: term()}

  @doc "Retrieves a session by ID"
  @callback get_session(session_id :: String.t()) ::
              {:ok, session :: map()} | {:error, reason :: term()}

  @doc "Stores an investigation result in a session"
  @callback store_investigation_result(
              session_id :: String.t(),
              investigation_id :: String.t(),
              result :: term()
            ) :: :ok | {:error, reason :: term()}

  @doc "Retrieves an investigation result from a session"
  @callback get_investigation_result(
              session_id :: String.t(),
              investigation_id :: String.t()
            ) :: {:ok, result :: term()} | {:error, reason :: term()}

  @doc "Lists all investigations in a session"
  @callback list_investigations(session_id :: String.t()) ::
              {:ok, [investigation_id :: String.t()]} | {:error, reason :: term()}
end
