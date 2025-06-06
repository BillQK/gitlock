defmodule GitlockCore.Domain.Values.FileHistoryTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Domain.Values.{FileChange, FileHistory}

  describe "FileHistory value object" do
    test "creates immutable file history" do
      rename_map = %{"old.ex" => "new.ex"}

      canonical_changes = %{
        "new.ex" => [
          %FileChange{entity: "new.ex", loc_added: "10", loc_deleted: "5"}
        ]
      }

      history = FileHistory.new(rename_map, canonical_changes)

      assert history.total_files == 1
      assert history.total_renames == 1
      assert FileHistory.get_canonical_name(history, "old.ex") == "new.ex"
      assert FileHistory.get_canonical_name(history, "new.ex") == "new.ex"
    end

    test "handles files without renames" do
      history =
        FileHistory.new(%{}, %{
          "stable.ex" => [%FileChange{entity: "stable.ex", loc_added: "20", loc_deleted: "10"}]
        })

      assert FileHistory.get_canonical_name(history, "stable.ex") == "stable.ex"
      assert FileHistory.was_renamed?(history, "stable.ex") == false
    end

    test "tracks revision count correctly" do
      history =
        FileHistory.new(
          %{"auth.ex" => "authentication.ex"},
          %{
            "authentication.ex" => [
              %FileChange{entity: "auth.ex", loc_added: "10", loc_deleted: "5"},
              %FileChange{entity: "auth.ex", loc_added: "20", loc_deleted: "10"},
              %FileChange{entity: "authentication.ex", loc_added: "5", loc_deleted: "2"}
            ]
          }
        )

      # Should count all changes under both old and new names
      assert FileHistory.get_revision_count(history, "authentication.ex") == 3
      # Maps to same file
      assert FileHistory.get_revision_count(history, "auth.ex") == 3
    end

    test "provides statistics" do
      history =
        FileHistory.new(
          %{"a.ex" => "b.ex", "c.ex" => "d.ex"},
          %{
            "b.ex" => [
              %FileChange{entity: "b.ex", loc_added: "10", loc_deleted: "5"},
              %FileChange{entity: "b.ex", loc_added: "20", loc_deleted: "10"}
            ],
            "d.ex" => [
              %FileChange{entity: "d.ex", loc_added: "15", loc_deleted: "7"}
            ]
          }
        )

      stats = FileHistory.stats(history)

      assert stats.total_files == 2
      assert stats.total_renames == 2
      assert stats.total_changes == 3
      assert stats.avg_changes_per_file == 1.5
    end

    test "finds canonical name for metrics lookup" do
      history =
        FileHistory.new(
          %{"lib/auth.ex" => "lib/authentication.ex"},
          %{
            "lib/authentication.ex" => [
              %FileChange{entity: "lib/authentication.ex", loc_added: "100", loc_deleted: "0"}
            ]
          }
        )

      # Metrics might be stored under old name
      assert FileHistory.find_canonical_for_any_name(history, "lib/auth.ex") ==
               "lib/authentication.ex"

      assert FileHistory.find_canonical_for_any_name(history, "lib/authentication.ex") ==
               "lib/authentication.ex"

      assert FileHistory.find_canonical_for_any_name(history, "lib/unknown.ex") == nil
    end
  end
end
