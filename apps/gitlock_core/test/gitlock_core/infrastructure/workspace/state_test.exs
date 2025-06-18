defmodule GitlockCore.Infrastructure.Workspace.StatesTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Infrastructure.Workspace.States

  describe "all_states/0" do
    test "returns all workspace states" do
      states = States.all_states()

      assert length(states) == 4
      assert :acquiring in states
      assert :ready in states
      assert :failed in states
      assert :released in states
    end
  end

  describe "state categorization" do
    test "active_states/0 returns only acquiring state" do
      assert States.active_states() == [:acquiring]
    end

    test "usable_states/0 returns only ready state" do
      assert States.usable_states() == [:ready]
    end

    test "error_states/0 returns only failed state" do
      assert States.error_states() == [:failed]
    end

    test "cleanup_eligible_states/0 returns deletable states" do
      eligible = States.cleanup_eligible_states()

      assert length(eligible) == 3
      assert :ready in eligible
      assert :released in eligible
      assert :failed in eligible
      refute :acquiring in eligible
    end
  end

  describe "can_transition?/2" do
    test "allows initial workspace creation" do
      assert States.can_transition?(nil, :acquiring)
    end

    test "allows normal acquisition flow" do
      # Success path
      assert States.can_transition?(:acquiring, :ready)

      # Failure path
      assert States.can_transition?(:acquiring, :failed)
    end

    test "allows user release action" do
      assert States.can_transition?(:ready, :released)
    end

    test "allows retry of failed acquisitions" do
      assert States.can_transition?(:failed, :acquiring)
    end

    test "allows reactivation of released workspaces" do
      assert States.can_transition?(:released, :ready)
    end

    test "disallows invalid transitions" do
      invalid_transitions = [
        # Can't skip acquiring
        {nil, :ready},
        {nil, :failed},
        {nil, :released},

        # Can't go backwards in normal flow
        {:ready, :acquiring},
        {:released, :acquiring},

        # Can't transition between terminal states
        {:failed, :released},
        {:released, :failed},

        # Can't transition from acquiring to released
        {:acquiring, :released},

        # Can't self-transition (except through valid paths)
        {:acquiring, :acquiring},
        {:ready, :ready},
        {:failed, :failed},
        {:released, :released}
      ]

      for {from, to} <- invalid_transitions do
        refute States.can_transition?(from, to),
               "Should not allow transition from #{inspect(from)} to #{inspect(to)}"
      end
    end
  end

  describe "describe/1" do
    test "returns human-readable descriptions for all states" do
      assert States.describe(:acquiring) == "Downloading repository"
      assert States.describe(:ready) == "Available for use"
      assert States.describe(:failed) == "Acquisition failed"
      assert States.describe(:released) == "Released by user"
    end
  end

  describe "state flow integration" do
    test "normal successful acquisition flow" do
      # Create -> Acquire -> Ready -> Release
      assert States.can_transition?(nil, :acquiring)
      assert States.can_transition?(:acquiring, :ready)
      assert States.can_transition?(:ready, :released)
    end

    test "failed acquisition with retry flow" do
      # Create -> Acquire -> Fail -> Retry -> Success
      assert States.can_transition?(nil, :acquiring)
      assert States.can_transition?(:acquiring, :failed)
      assert States.can_transition?(:failed, :acquiring)
      assert States.can_transition?(:acquiring, :ready)
    end

    test "released workspace reactivation flow" do
      # ... -> Ready -> Release -> Reactivate
      assert States.can_transition?(:ready, :released)
      assert States.can_transition?(:released, :ready)
    end
  end

  describe "state properties" do
    test "acquiring is the only active state" do
      active = States.active_states()
      assert length(active) == 1
      assert hd(active) == :acquiring
    end

    test "only ready workspaces are usable" do
      usable = States.usable_states()
      assert length(usable) == 1
      assert hd(usable) == :ready
    end

    test "cleanup eligible states exclude acquiring" do
      eligible = States.cleanup_eligible_states()
      all = States.all_states()

      # All states except acquiring should be eligible
      assert length(eligible) == length(all) - 1
      refute :acquiring in eligible

      # Verify all other states are eligible
      for state <- all, state != :acquiring do
        assert state in eligible
      end
    end
  end

  describe "state machine completeness" do
    test "all states have descriptions" do
      for state <- States.all_states() do
        description = States.describe(state)
        assert is_binary(description)
        assert String.length(description) > 0
      end
    end

    test "every state has at least one valid outgoing transition" do
      # Except for terminal states that get cleaned up
      states_with_transitions = %{
        nil => [:acquiring],
        :acquiring => [:ready, :failed],
        :ready => [:released],
        :failed => [:acquiring],
        :released => [:ready]
      }

      for {from, valid_tos} <- states_with_transitions do
        assert Enum.any?(valid_tos, &States.can_transition?(from, &1)),
               "State #{inspect(from)} should have at least one valid transition"
      end
    end

    test "no orphaned states - all states can be reached" do
      # Start from nil (workspace creation)
      reachable = explore_states(nil, MapSet.new())
      all_states = MapSet.new(States.all_states())

      assert MapSet.equal?(reachable, all_states),
             "All states should be reachable. Missing: #{inspect(MapSet.difference(all_states, reachable))}"
    end
  end

  # Helper function to explore reachable states
  defp explore_states(current_state, visited) do
    # Get all possible next states from current state
    next_states =
      States.all_states()
      |> Enum.filter(&States.can_transition?(current_state, &1))
      |> Enum.reject(&MapSet.member?(visited, &1))

    # If no new states to explore, return visited
    if Enum.empty?(next_states) do
      visited
    else
      # Add new states to visited and explore each one
      new_visited = Enum.reduce(next_states, visited, &MapSet.put(&2, &1))

      Enum.reduce(next_states, new_visited, fn next_state, acc ->
        explore_states(next_state, acc)
      end)
    end
  end
end
