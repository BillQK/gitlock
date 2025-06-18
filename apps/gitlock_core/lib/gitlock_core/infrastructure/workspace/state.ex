defmodule GitlockCore.Infrastructure.Workspace.States do
  @moduledoc """
  Defines the workspace lifecycle states and their interactions.

  ## State Flow

      acquire()          clone_success()
      ┌─────────┐       ┌─────────────┐       ┌───────────┐
      │ Manager │──────▶│ :acquiring  │──────▶│  :ready   │
      └─────────┘       └─────────────┘       └───────────┘
                               │                     │
                               │ clone_failure()     │ release()
                               ▼                     ▼
                        ┌─────────────┐       ┌───────────┐
                        │   :failed   │       │:released  │
                        └─────────────┘       └───────────┘
                               │                     │
                               └─────────────────────┘
                                       │
                                cleanup() (removed from store)

  ## States

  - **:acquiring** - Currently being cloned/downloaded
  - **:ready**     - Successfully acquired, available for use  
  - **:failed**    - Acquisition failed (network, auth, etc.)
  - **:released**  - User finished with it, eligible for cleanup

  ## System Interactions

  ### Manager
  - Creates workspaces in `:acquiring` state
  - Transitions to `:ready` on success, `:failed` on error
  - Handles `release()` by changing `:ready` → `:released`
  - Can retry `:failed` workspaces

  ### Cleaner  
  - Cleans up `:ready`, `:released`, and `:failed` workspaces based on age
  - Never touches `:acquiring` workspaces (protects active operations)
  - Handles stuck `:acquiring` workspaces after timeout

  ### Store
  - Validates state transitions
  - Provides queries by state
  """

  @type workspace_state :: :acquiring | :ready | :failed | :released

  def all_states, do: [:acquiring, :ready, :failed, :released]

  def active_states, do: [:acquiring]
  def usable_states, do: [:ready]
  def error_states, do: [:failed]
  def cleanup_eligible_states, do: [:ready, :released, :failed]

  @doc "Valid state transitions"
  def can_transition?(from_state, to_state) do
    case {from_state, to_state} do
      # Initial creation (from nil when creating workspace)
      {nil, :acquiring} -> true
      # Normal acquisition flow
      {:acquiring, :ready} -> true
      {:acquiring, :failed} -> true
      # User actions
      {:ready, :released} -> true
      # Recovery/retry
      # Retry failed acquisition
      {:failed, :acquiring} -> true
      # Reactivate released workspace
      {:released, :ready} -> true
      _ -> false
    end
  end

  @doc "Human readable state descriptions"
  def describe(:acquiring), do: "Downloading repository"
  def describe(:ready), do: "Available for use"
  def describe(:failed), do: "Acquisition failed"
  def describe(:released), do: "Released by user"
end
