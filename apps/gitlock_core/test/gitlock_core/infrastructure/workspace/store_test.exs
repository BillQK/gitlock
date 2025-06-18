defmodule GitlockCore.Infrastructure.Workspace.StoreTest do
  use ExUnit.Case, async: false

  alias GitlockCore.Infrastructure.Workspace.Store

  # Setup runs before EACH test
  setup do
    # Ensure the Agent is started
    case GenServer.whereis(Store) do
      nil ->
        {:ok, _} = Store.start_link([])

      pid ->
        if Process.alive?(pid) do
          {:ok, pid}
        else
          {:ok, _} = Store.start_link([])
        end
    end

    # Reset to clean state
    Store.reset()

    # Cleanup after test
    on_exit(fn ->
      try do
        Store.reset()
      catch
        # Ignore if Store is already dead
        :exit, _ -> :ok
      end
    end)

    :ok
  end

  describe "initialization and state" do
    test "start_link initializes an empty store" do
      state = Store.get_state()
      assert %Store{workspaces: %{}, by_source: %{}, monitors: %{}} = state
    end

    test "reset/0 clears all workspace data" do
      # Add test data
      workspace = create_workspace("reset-test")
      Store.put(workspace.id, workspace)

      # Verify data exists
      assert length(Store.list()) == 1
      assert Store.get(workspace.id) != nil

      # Reset and verify empty state
      assert :ok = Store.reset()
      assert Enum.empty?(Store.list())
      assert Store.get(workspace.id) == nil

      state = Store.get_state()
      assert %Store{workspaces: %{}, by_source: %{}, monitors: %{}} = state
    end
  end

  describe "put/2 and get/1" do
    test "stores and retrieves workspace by ID" do
      workspace = create_workspace("test-ws-1")

      assert :ok = Store.put(workspace.id, workspace)
      stored_workspace = Store.get(workspace.id)

      assert stored_workspace == workspace
      assert stored_workspace.id == workspace.id
      assert stored_workspace.source == workspace.source
    end

    test "overwrites existing workspace with same ID" do
      initial = create_workspace("test-ws-2", state: :acquiring)
      Store.put(initial.id, initial)

      updated = %{initial | state: :ready, owner: self()}
      assert :ok = Store.put(updated.id, updated)

      result = Store.get(updated.id)
      assert result == updated
      assert result.state == :ready
      assert result.owner == self()
    end

    test "updates source index when storing workspace" do
      workspace = create_workspace("test-ws-3")
      assert :ok = Store.put(workspace.id, workspace)

      # Verify both ID and source lookups work
      assert Store.get(workspace.id) == workspace
      assert Store.get_by_source(workspace.source) == workspace

      # Verify internal state consistency
      state = Store.get_state()
      assert Map.has_key?(state.workspaces, workspace.id)
      assert Map.has_key?(state.by_source, workspace.source)
      assert state.by_source[workspace.source] == workspace.id
    end

    test "returns nil for non-existent ID" do
      assert nil == Store.get("non-existent-id")
      assert nil == Store.get("another-fake-id-#{System.unique_integer()}")
    end
  end

  describe "get_by_source/1 and index consistency" do
    test "retrieves workspace by source URL" do
      workspace = create_workspace("test-ws-4", source: "https://github.com/test/repo.git")
      Store.put(workspace.id, workspace)

      result = Store.get_by_source(workspace.source)
      assert result == workspace
      assert result.source == workspace.source
    end

    test "maintains source index after update" do
      workspace = create_workspace("test-ws-5", source: "file:///local/project")
      Store.put(workspace.id, workspace)

      # Update workspace (not changing source)
      Store.update(workspace.id, %{state: :error})

      # Source lookup should still work
      updated = Store.get_by_source(workspace.source)
      assert updated != nil
      assert updated.state == :error
      assert updated.source == workspace.source
      assert updated.id == workspace.id
    end

    test "handles multiple workspaces with different sources" do
      ws1 = create_workspace("ws1", source: "https://github.com/user/repo1.git")
      ws2 = create_workspace("ws2", source: "https://github.com/user/repo2.git")

      Store.put(ws1.id, ws1)
      Store.put(ws2.id, ws2)

      assert Store.get_by_source(ws1.source) == ws1
      assert Store.get_by_source(ws2.source) == ws2
      assert Store.get_by_source("https://nonexistent.com") == nil
    end

    test "returns nil for non-existent source" do
      assert nil == Store.get_by_source("https://non-existent.com/repo.git")
      assert nil == Store.get_by_source("/fake/path")
    end
  end

  describe "update/2" do
    test "partially updates existing workspace" do
      initial =
        create_workspace("test-ws-6",
          state: :acquiring,
          opts: [branch: "main"]
        )

      Store.put(initial.id, initial)

      updates = %{state: :ready, path: "/new/path"}
      assert :ok = Store.update(initial.id, updates)

      result = Store.get(initial.id)

      # Updated fields
      assert result.state == :ready
      assert result.path == "/new/path"

      # Unchanged fields
      assert result.type == initial.type
      assert result.source == initial.source
      assert result.opts == initial.opts
      assert result.id == initial.id
    end

    test "updates multiple fields correctly" do
      initial = create_workspace("test-ws-7")
      Store.put(initial.id, initial)

      updates = %{
        state: :error,
        owner: nil,
        opts: [error: "disk full"]
      }

      Store.update(initial.id, updates)

      result = Store.get(initial.id)
      assert result.state == :error
      assert result.owner == nil
      assert result.opts == [error: "disk full"]

      # Verify unchanged fields
      assert result.id == initial.id
      assert result.source == initial.source
      assert result.type == initial.type
    end

    test "preserves source index after update" do
      workspace = create_workspace("test-ws-8")
      Store.put(workspace.id, workspace)

      # Update some fields
      Store.update(workspace.id, %{state: :error, path: "/new/path"})

      # Source lookup should still work
      updated = Store.get_by_source(workspace.source)
      assert updated != nil
      assert updated.id == workspace.id
      assert updated.state == :error
      assert updated.path == "/new/path"
    end

    test "does nothing for non-existent workspace" do
      initial_state = Store.get_state()

      assert :ok = Store.update("non-existent", %{state: :error})

      final_state = Store.get_state()
      assert initial_state == final_state
    end
  end

  describe "delete/1" do
    test "removes workspace from both indexes" do
      workspace =
        create_workspace("test-ws-9",
          source: "https://github.com/test/delete-me.git"
        )

      Store.put(workspace.id, workspace)

      # Verify it exists
      assert Store.get(workspace.id) != nil
      assert Store.get_by_source(workspace.source) != nil

      # Delete it
      assert :ok = Store.delete(workspace.id)

      # Verify it's gone from both indexes
      assert nil == Store.get(workspace.id)
      assert nil == Store.get_by_source(workspace.source)
    end

    test "removes workspace from internal state completely" do
      workspace = create_workspace("test-ws-10")
      Store.put(workspace.id, workspace)

      # Verify internal state has the workspace
      state_before = Store.get_state()
      assert Map.has_key?(state_before.workspaces, workspace.id)
      assert Map.has_key?(state_before.by_source, workspace.source)

      # Delete and verify internal state
      Store.delete(workspace.id)

      state_after = Store.get_state()
      refute Map.has_key?(state_after.workspaces, workspace.id)
      refute Map.has_key?(state_after.by_source, workspace.source)
    end

    test "handles non-existent workspace gracefully" do
      initial_count = length(Store.list())
      initial_state = Store.get_state()

      assert :ok = Store.delete("non-existent-id")

      # Nothing should change
      assert length(Store.list()) == initial_count
      assert Store.get_state() == initial_state
    end
  end

  describe "list/0" do
    test "returns empty list for empty store" do
      assert [] == Store.list()
    end

    test "returns all workspaces in store" do
      ws1 = create_workspace("w1", source: "s1")
      ws2 = create_workspace("w2", source: "s2", type: :local)

      Store.put(ws1.id, ws1)
      Store.put(ws2.id, ws2)

      all_workspaces = Store.list()
      assert length(all_workspaces) == 2
      assert ws1 in all_workspaces
      assert ws2 in all_workspaces
    end

    test "list reflects changes after operations" do
      workspace = create_workspace("list_test")

      # Initially empty
      assert Enum.empty?(Store.list())

      # Add workspace
      Store.put(workspace.id, workspace)
      assert length(Store.list()) == 1

      # Update workspace
      Store.update(workspace.id, %{state: :error})
      workspaces = Store.list()
      assert length(workspaces) == 1
      assert hd(workspaces).state == :error

      # Delete workspace
      Store.delete(workspace.id)
      assert Enum.empty?(Store.list())
    end
  end

  describe "list_by_owner/1" do
    test "returns workspaces owned by specific PID" do
      owner1 = self()
      owner2 = spawn_link(fn -> :timer.sleep(:infinity) end)

      ws1 = create_workspace("o1", owner: owner1)
      ws2 = create_workspace("o2", owner: owner2)
      ws3 = create_workspace("o3", owner: owner1)

      Store.put(ws1.id, ws1)
      Store.put(ws2.id, ws2)
      Store.put(ws3.id, ws3)

      owned_by_current = Store.list_by_owner(owner1)
      assert length(owned_by_current) == 2
      assert ws1 in owned_by_current
      assert ws3 in owned_by_current
      refute ws2 in owned_by_current

      owned_by_other = Store.list_by_owner(owner2)
      assert length(owned_by_other) == 1
      assert ws2 in owned_by_other

      Process.exit(owner2, :kill)
    end

    test "returns empty list if no workspaces match owner" do
      Store.put("w1", create_workspace("w1", owner: self()))

      other_pid = spawn_link(fn -> :timer.sleep(:infinity) end)
      assert [] == Store.list_by_owner(other_pid)
      Process.exit(other_pid, :kill)
    end

    test "correctly filters for nil owner" do
      ws1 = create_workspace("n1", owner: nil)
      ws2 = create_workspace("n2", owner: self())

      Store.put(ws1.id, ws1)
      Store.put(ws2.id, ws2)

      nil_owned = Store.list_by_owner(nil)
      assert length(nil_owned) == 1
      assert ws1 in nil_owned
      refute ws2 in nil_owned
    end

    test "returns empty list when store is empty" do
      assert [] == Store.list_by_owner(self())
    end
  end

  describe "touch/1" do
    test "updates last_accessed timestamp" do
      created_at = hours_ago(1)
      workspace = create_workspace("t1", created_at: created_at)

      # Remove last_accessed to test setting it
      workspace = Map.delete(workspace, :last_accessed)
      Store.put(workspace.id, workspace)

      # Touch and verify
      :ok = Store.touch(workspace.id)
      updated = Store.get(workspace.id)

      assert Map.has_key?(updated, :last_accessed)
      assert updated.last_accessed != nil
      assert DateTime.compare(updated.last_accessed, created_at) == :gt

      # Verify timestamp is recent
      now = DateTime.utc_now()
      diff_seconds = DateTime.diff(now, updated.last_accessed, :second)
      assert diff_seconds < 5
    end

    test "updates existing last_accessed timestamp" do
      old_access = hours_ago(2)
      workspace = create_workspace("t2", last_accessed: old_access)
      Store.put(workspace.id, workspace)

      :ok = Store.touch(workspace.id)
      updated = Store.get(workspace.id)

      assert DateTime.compare(updated.last_accessed, old_access) == :gt
    end

    test "does nothing for non-existent workspace" do
      initial_state = Store.get_state()

      assert :ok = Store.touch("non-existent-touch-id")

      final_state = Store.get_state()
      assert initial_state == final_state
    end

    test "preserves other workspace fields when touching" do
      workspace = create_workspace("t3")
      Store.put(workspace.id, workspace)

      :ok = Store.touch(workspace.id)
      updated = Store.get(workspace.id)

      # Should only change last_accessed
      assert updated.id == workspace.id
      assert updated.source == workspace.source
      assert updated.type == workspace.type
      assert updated.state == workspace.state
      assert updated.owner == workspace.owner
      assert Map.has_key?(updated, :last_accessed)
    end
  end

  describe "list_inactive_since/1" do
    test "identifies inactive workspaces correctly" do
      # Active: accessed 1 hour ago
      ws_active =
        create_workspace("active",
          created_at: days_ago(2),
          last_accessed: hours_ago(1)
        )

      # Inactive: accessed 3 days ago
      ws_inactive_accessed =
        create_workspace("inactive_accessed",
          created_at: days_ago(5),
          last_accessed: days_ago(3)
        )

      # Inactive: created 4 days ago (no last_accessed)
      ws_inactive_created =
        create_workspace("inactive_created",
          created_at: days_ago(4)
        )
        |> Map.delete(:last_accessed)

      # Active: created 1 day ago (no last_accessed)
      ws_active_created =
        create_workspace("active_created",
          created_at: days_ago(1)
        )
        |> Map.delete(:last_accessed)

      Store.put(ws_active.id, ws_active)
      Store.put(ws_inactive_accessed.id, ws_inactive_accessed)
      Store.put(ws_inactive_created.id, ws_inactive_created)
      Store.put(ws_active_created.id, ws_active_created)

      # Cutoff: 2 days ago
      cutoff_time = days_ago(2)

      inactive = Store.list_inactive_since(cutoff_time)

      assert length(inactive) == 2
      assert ws_inactive_accessed in inactive
      assert ws_inactive_created in inactive
      refute ws_active in inactive
      refute ws_active_created in inactive
    end

    test "uses created_at when last_accessed is missing" do
      # Old workspace without last_accessed
      old_workspace =
        create_workspace("old",
          created_at: days_ago(3)
        )
        |> Map.delete(:last_accessed)

      # Recent workspace without last_accessed
      recent_workspace =
        create_workspace("recent",
          created_at: hours_ago(1)
        )
        |> Map.delete(:last_accessed)

      Store.put(old_workspace.id, old_workspace)
      Store.put(recent_workspace.id, recent_workspace)

      cutoff = days_ago(1)
      inactive = Store.list_inactive_since(cutoff)

      assert length(inactive) == 1
      assert old_workspace in inactive
      refute recent_workspace in inactive
    end

    test "returns empty list if all workspaces are active" do
      Store.put("a1", create_workspace("a1", created_at: days_ago(1)))
      Store.put("a2", create_workspace("a2", last_accessed: hours_ago(1)))

      cutoff_time = days_ago(5)
      assert [] == Store.list_inactive_since(cutoff_time)
    end

    test "returns empty list when store is empty" do
      assert [] == Store.list_inactive_since(DateTime.utc_now())
    end
  end

  describe "get_state/0 for internal inspection" do
    test "returns current internal state structure" do
      workspace = create_workspace("gs1", source: "https://test.com/repo.git")
      Store.put(workspace.id, workspace)

      state = Store.get_state()

      assert %Store{} = state
      assert Map.has_key?(state.workspaces, workspace.id)
      assert Map.has_key?(state.by_source, workspace.source)
      assert state.workspaces[workspace.id] == workspace
      assert state.by_source[workspace.source] == workspace.id
    end

    test "reflects state changes accurately" do
      workspace = create_workspace("state_test")

      # Empty state
      empty_state = Store.get_state()
      assert map_size(empty_state.workspaces) == 0
      assert map_size(empty_state.by_source) == 0

      # After adding workspace
      Store.put(workspace.id, workspace)
      populated_state = Store.get_state()
      assert map_size(populated_state.workspaces) == 1
      assert map_size(populated_state.by_source) == 1

      # After deletion
      Store.delete(workspace.id)
      final_state = Store.get_state()
      assert map_size(final_state.workspaces) == 0
      assert map_size(final_state.by_source) == 0
    end
  end

  describe "data consistency and atomicity" do
    test "put operation is atomic" do
      workspace = create_workspace("atomic_test")

      :ok = Store.put(workspace.id, workspace)

      # Both lookups should work immediately
      assert Store.get(workspace.id) == workspace
      assert Store.get_by_source(workspace.source) == workspace
    end

    test "delete operation is atomic" do
      workspace = create_workspace("atomic_delete")
      Store.put(workspace.id, workspace)

      :ok = Store.delete(workspace.id)

      # Both lookups should fail immediately
      assert Store.get(workspace.id) == nil
      assert Store.get_by_source(workspace.source) == nil
    end

    test "source index consistency after multiple operations" do
      ws1 = create_workspace("consistency1", source: "source1")
      ws2 = create_workspace("consistency2", source: "source2")

      # Add both
      Store.put(ws1.id, ws1)
      Store.put(ws2.id, ws2)

      # Update one
      Store.update(ws1.id, %{state: :error})

      # Verify both source lookups still work
      assert Store.get_by_source("source1").state == :error
      assert Store.get_by_source("source2").state == ws2.state

      # Delete one
      Store.delete(ws1.id)

      # Verify correct source is removed
      assert Store.get_by_source("source1") == nil
      assert Store.get_by_source("source2") != nil
    end
  end

  # Helper functions
  defp create_workspace(id, opts \\ []) do
    %{
      id: id,
      source: Keyword.get(opts, :source, "https://github.com/test/#{id}.git"),
      type: Keyword.get(opts, :type, :remote),
      state: Keyword.get(opts, :state, :ready),
      owner: Keyword.get(opts, :owner, self()),
      path: Keyword.get(opts, :path, "/tmp/#{id}"),
      created_at: Keyword.get(opts, :created_at, DateTime.utc_now()),
      opts: Keyword.get(opts, :opts, [])
    }
    |> maybe_add_last_accessed(opts)
  end

  defp maybe_add_last_accessed(workspace, opts) do
    if Keyword.has_key?(opts, :last_accessed) do
      Map.put(workspace, :last_accessed, opts[:last_accessed])
    else
      workspace
    end
  end

  defp hours_ago(hours) do
    DateTime.utc_now() |> DateTime.add(-hours * 3600, :second)
  end

  defp days_ago(days) do
    DateTime.utc_now() |> DateTime.add(-days * 86_400, :second)
  end
end
