defmodule GitlockCore.Domain.Services.FileHistoryServiceTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Domain.Services.FileHistoryService
  alias GitlockCore.Domain.Entities.{Commit, Author}
  alias GitlockCore.Domain.Values.{FileChange, FileHistory}

  describe "parse_rename/1" do
    test "parses simple rename pattern {old => new}" do
      assert {"old.ex", "new.ex"} = FileHistoryService.parse_rename("{old.ex => new.ex}")
    end

    test "parses rename with path prefix" do
      assert {"lib/old.ex", "lib/new.ex"} =
               FileHistoryService.parse_rename("lib/{old.ex => new.ex}")
    end

    test "parses rename with path suffix" do
      assert {"lib/old/file.ex", "lib/new/file.ex"} =
               FileHistoryService.parse_rename("lib/{old => new}/file.ex")
    end

    test "parses complex path renames" do
      assert {"apps/gitlock_holmes_core/lib/file.ex", "apps/gitlock_core/lib/file.ex"} =
               FileHistoryService.parse_rename(
                 "apps/{gitlock_holmes_core => gitlock_core}/lib/file.ex"
               )
    end

    test "handles spaces in rename pattern" do
      assert {"old file.ex", "new file.ex"} =
               FileHistoryService.parse_rename("{old file.ex => new file.ex}")
    end

    test "returns nil for non-rename paths" do
      assert nil == FileHistoryService.parse_rename("lib/normal_file.ex")
      assert nil == FileHistoryService.parse_rename("README.md")
    end
  end

  describe "rename_pattern?/1" do
    test "detects various rename patterns" do
      assert FileHistoryService.rename_pattern?("{old => new}")
      assert FileHistoryService.rename_pattern?("lib/{old.ex => new.ex}")
      assert FileHistoryService.rename_pattern?("path/{a => b}/rest")

      refute FileHistoryService.rename_pattern?("lib/normal.ex")
      refute FileHistoryService.rename_pattern?("=> not a rename")
    end
  end

  describe "build_history/1" do
    test "builds empty history for no commits" do
      history = FileHistoryService.build_history([])

      assert history.total_files == 0
      assert history.total_renames == 0
      assert FileHistory.get_all_files(history) == []
    end

    test "builds history for commits without renames" do
      commits = [
        create_commit("commit1", [
          {"lib/file1.ex", "10", "5"},
          {"lib/file2.ex", "20", "0"}
        ]),
        create_commit("commit2", [
          {"lib/file1.ex", "5", "10"}
        ])
      ]

      history = FileHistoryService.build_history(commits)

      assert history.total_files == 2
      assert history.total_renames == 0

      # Check file1.ex has 2 changes
      assert length(FileHistory.get_file_changes(history, "lib/file1.ex")) == 2
      # Check file2.ex has 1 change
      assert length(FileHistory.get_file_changes(history, "lib/file2.ex")) == 1
    end

    test "handles simple rename" do
      commits = [
        create_commit("commit1", [
          {"auth.ex", "100", "0"}
        ]),
        create_commit("commit2", [
          {"{auth.ex => authentication.ex}", "0", "0"}
        ]),
        create_commit("commit3", [
          {"authentication.ex", "20", "10"}
        ])
      ]

      history = FileHistoryService.build_history(commits)

      # Only one canonical file
      assert history.total_files == 1
      assert history.total_renames == 1

      # Both names should resolve to the same canonical file
      assert FileHistory.get_canonical_name(history, "auth.ex") == "authentication.ex"
      assert FileHistory.get_canonical_name(history, "authentication.ex") == "authentication.ex"

      # Should have 2 changes (original + modification, rename is filtered)
      changes = FileHistory.get_file_changes(history, "authentication.ex")
      assert length(changes) == 2
    end

    test "handles transitive renames (a -> b -> c)" do
      commits = [
        create_commit("commit1", [
          {"a.ex", "50", "0"}
        ]),
        create_commit("commit2", [
          {"{a.ex => b.ex}", "0", "0"}
        ]),
        create_commit("commit3", [
          {"b.ex", "10", "5"}
        ]),
        create_commit("commit4", [
          {"{b.ex => c.ex}", "0", "0"}
        ]),
        create_commit("commit5", [
          {"c.ex", "20", "15"}
        ])
      ]

      history = FileHistoryService.build_history(commits)

      assert history.total_files == 1
      assert history.total_renames == 2

      # All names should resolve to the final name
      assert FileHistory.get_canonical_name(history, "a.ex") == "c.ex"
      assert FileHistory.get_canonical_name(history, "b.ex") == "c.ex"
      assert FileHistory.get_canonical_name(history, "c.ex") == "c.ex"

      # Should have 3 actual code changes (excluding pure renames)
      changes = FileHistory.get_file_changes(history, "c.ex")
      assert length(changes) == 3
    end

    test "handles multiple independent renames" do
      commits = [
        create_commit("commit1", [
          {"user.ex", "100", "0"},
          {"auth.ex", "80", "0"}
        ]),
        create_commit("commit2", [
          {"{user.ex => account.ex}", "0", "0"},
          {"{auth.ex => authentication.ex}", "0", "0"}
        ])
      ]

      history = FileHistoryService.build_history(commits)

      assert history.total_files == 2
      assert history.total_renames == 2

      assert FileHistory.get_canonical_name(history, "user.ex") == "account.ex"
      assert FileHistory.get_canonical_name(history, "auth.ex") == "authentication.ex"
    end

    test "handles rename with path changes" do
      commits = [
        create_commit("commit1", [
          {"lib/old_app/auth.ex", "100", "0"}
        ]),
        create_commit("commit2", [
          {"lib/{old_app => new_app}/auth.ex", "0", "0"}
        ]),
        create_commit("commit3", [
          {"lib/new_app/auth.ex", "20", "10"}
        ])
      ]

      history = FileHistoryService.build_history(commits)

      assert FileHistory.get_canonical_name(history, "lib/old_app/auth.ex") ==
               "lib/new_app/auth.ex"

      # Should have 2 changes (excluding the pure rename)
      changes = FileHistory.get_file_changes(history, "lib/new_app/auth.ex")
      assert length(changes) == 2
    end

    test "filters out pure renames from changes" do
      commits = [
        create_commit("commit1", [
          {"file.ex", "100", "0"}
        ]),
        create_commit("commit2", [
          # Pure rename - should be tracked but not counted as a change
          {"{file.ex => renamed.ex}", "0", "0"}
        ]),
        create_commit("commit3", [
          # Rename with modifications - should be counted
          {"{other.ex => modified.ex}", "50", "25"}
        ])
      ]

      history = FileHistoryService.build_history(commits)

      # renamed.ex should have 1 change (the original creation)
      assert length(FileHistory.get_file_changes(history, "renamed.ex")) == 1

      # modified.ex should have 1 change (the rename with modifications)
      assert length(FileHistory.get_file_changes(history, "modified.ex")) == 1
    end

    test "handles binary files" do
      commits = [
        create_commit("commit1", [
          {"image.png", "-", "-"},
          {"document.pdf", "-", "-"}
        ]),
        create_commit("commit2", [
          {"{image.png => logo.png}", "0", "0"}
        ])
      ]

      history = FileHistoryService.build_history(commits)

      assert FileHistory.get_canonical_name(history, "image.png") == "logo.png"
      # Binary file change should be preserved
      changes = FileHistory.get_file_changes(history, "logo.png")
      assert length(changes) == 1
      assert hd(changes).loc_added == "-"
      assert hd(changes).loc_deleted == "-"
    end

    test "handles complex refactoring scenario" do
      # Simulate the gitlock_holmes -> gitlock refactoring
      commits = [
        create_commit("commit1", [
          {"apps/gitlock_holmes_core/lib/auth.ex", "100", "0"},
          {"apps/gitlock_holmes_core/test/auth_test.exs", "50", "0"}
        ]),
        create_commit("commit2", [
          {"apps/{gitlock_holmes_core => gitlock_core}/lib/auth.ex", "10", "5"},
          {"apps/{gitlock_holmes_core => gitlock_core}/test/auth_test.exs", "0", "0"}
        ])
      ]

      history = FileHistoryService.build_history(commits)

      # Old paths should map to new paths
      assert FileHistory.get_canonical_name(history, "apps/gitlock_holmes_core/lib/auth.ex") ==
               "apps/gitlock_core/lib/auth.ex"

      assert FileHistory.get_canonical_name(
               history,
               "apps/gitlock_holmes_core/test/auth_test.exs"
             ) ==
               "apps/gitlock_core/test/auth_test.exs"

      # The lib file should have 2 changes (creation + rename with modifications)
      lib_changes = FileHistory.get_file_changes(history, "apps/gitlock_core/lib/auth.ex")
      assert length(lib_changes) == 2

      # The test file should have 1 change (pure rename is filtered)
      test_changes = FileHistory.get_file_changes(history, "apps/gitlock_core/test/auth_test.exs")
      assert length(test_changes) == 1
    end
  end

  # Helper functions

  defp create_commit(id, file_specs) do
    author = Author.new("Test Author")

    file_changes =
      Enum.map(file_specs, fn {entity, added, deleted} ->
        FileChange.new(entity, added, deleted)
      end)

    Commit.new(id, author, "2024-01-01", "Test commit", file_changes)
  end
end
