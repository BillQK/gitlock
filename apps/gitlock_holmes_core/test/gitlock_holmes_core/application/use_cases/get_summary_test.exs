defmodule GitlockHolmesCore.Application.UseCases.GetSummaryTest do
  use ExUnit.Case, async: true

  import Mox

  alias GitlockHolmesCore.Application.UseCases.GetSummary
  alias GitlockHolmesCore.Infrastructure.AdapterRegistry
  alias GitlockHolmesCore.Domain.Entities.{Commit, Author}
  alias GitlockHolmesCore.Domain.Values.FileChange

  # Use the same mock module names as defined in mocks.ex
  alias GitlockHolmesCore.Mocks.VersionControlMock
  alias GitlockHolmesCore.Mocks.ReporterMock

  # Verify all expectations are met after each test
  setup :verify_on_exit!

  setup do
    # Register mocks for each test
    :ok = AdapterRegistry.register_adapter(:vcs, "test_git", VersionControlMock)
    :ok = AdapterRegistry.register_adapter(:reporter, "test_csv", ReporterMock)
    :ok = AdapterRegistry.register_adapter(:reporter, "test_json", ReporterMock)

    # Also register with the default names
    :ok = AdapterRegistry.register_adapter(:vcs, "git", VersionControlMock)
    :ok = AdapterRegistry.register_adapter(:reporter, "csv", ReporterMock)

    :ok
  end

  # Helper to create test commits - fixed to always use count parameter
  defp create_test_commits(count) do
    Enum.map(1..count, fn i ->
      author = Author.new("Author #{i}", "author#{i}@example.com")

      file_changes = [
        FileChange.new("lib/file#{i}.ex", "10", "5"),
        FileChange.new("test/file#{i}_test.exs", "20", "3")
      ]

      Commit.new(
        "commit#{i}",
        author,
        "2023-01-#{String.pad_leading("#{i}", 2, "0")}",
        "Commit #{i}",
        file_changes
      )
    end)
  end

  describe "execute/2 - full workflow" do
    test "successfully generates summary with default adapters" do
      commits = create_test_commits(5)

      # Setup mocks
      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts ->
        {:ok, commits}
      end)

      ReporterMock
      |> expect(:report, fn summary_stats, _opts ->
        # Verify the summary structure
        assert length(summary_stats) == 3
        assert Enum.find(summary_stats, &(&1.statistic == "number-of-commits"))
        assert Enum.find(summary_stats, &(&1.statistic == "number-of-authors"))
        assert Enum.find(summary_stats, &(&1.statistic == "number-of-entities"))

        {:ok, "Summary report generated"}
      end)

      result = GetSummary.execute("/path/to/repo.log", %{vcs: "test_git", format: "test_csv"})

      assert {:ok, "Summary report generated"} = result
    end

    test "successfully generates summary with custom options" do
      commits = create_test_commits(2)

      VersionControlMock
      |> expect(:get_commit_history, fn _path, opts ->
        # Verify options are passed through
        assert opts[:custom_option] == "value"
        {:ok, commits}
      end)

      ReporterMock
      |> expect(:report, fn _stats, opts ->
        # Verify options are passed to reporter
        assert opts[:custom_option] == "value"
        {:ok, "Custom summary"}
      end)

      options = %{
        vcs: "test_git",
        format: "test_csv",
        custom_option: "value"
      }

      result = GetSummary.execute("/repo.log", options)

      assert {:ok, "Custom summary"} = result
    end
  end

  describe "resolve_dependencies/1" do
    test "resolves default dependencies when no options provided" do
      # Register default adapters

      assert {:ok, deps} = GetSummary.resolve_dependencies(%{})

      assert deps.vcs == VersionControlMock
      assert deps.reporter == ReporterMock
    end

    test "resolves custom VCS adapter" do
      assert {:ok, deps} = GetSummary.resolve_dependencies(%{vcs: "test_git"})

      assert deps.vcs == VersionControlMock
    end

    test "resolves custom reporter based on format" do
      assert {:ok, deps} = GetSummary.resolve_dependencies(%{format: "test_json"})

      assert deps.reporter == ReporterMock
    end

    test "returns error when VCS adapter not found" do
      result = GetSummary.resolve_dependencies(%{vcs: "non_existent"})

      assert {:error, "Adapter not found: vcs/non_existent"} = result
    end

    test "returns error when reporter adapter not found" do
      result = GetSummary.resolve_dependencies(%{format: "non_existent"})

      assert {:error, "Adapter not found: reporter/non_existent"} = result
    end
  end

  describe "run_domain_logic/3" do
    test "successfully summarizes commits" do
      commits = create_test_commits(4)

      VersionControlMock
      |> expect(:get_commit_history, fn path, opts ->
        assert path == "/test/repo.log"
        assert opts == %{test: true}
        {:ok, commits}
      end)

      deps = %{vcs: VersionControlMock}

      assert {:ok, summary_stats} =
               GetSummary.run_domain_logic("/test/repo.log", deps, %{test: true})

      # Verify summary structure
      assert length(summary_stats) == 3

      commits_stat = Enum.find(summary_stats, &(&1.statistic == "number-of-commits"))
      assert commits_stat.value == 4

      authors_stat = Enum.find(summary_stats, &(&1.statistic == "number-of-authors"))
      # Each commit has a different author
      assert authors_stat.value == 4

      entities_stat = Enum.find(summary_stats, &(&1.statistic == "number-of-entities"))
      # 4 commits * 2 files each
      assert entities_stat.value == 8
    end

    test "handles empty commit history" do
      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts ->
        {:ok, []}
      end)

      deps = %{vcs: VersionControlMock}

      assert {:ok, summary_stats} = GetSummary.run_domain_logic("/empty.log", deps, %{})

      # All counts should be 0
      assert Enum.all?(summary_stats, &(&1.value == 0))
    end

    test "propagates VCS errors" do
      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts ->
        {:error, "Could not read log file"}
      end)

      deps = %{vcs: VersionControlMock}

      assert {:error, "Could not read log file"} =
               GetSummary.run_domain_logic("/bad/path", deps, %{})
    end
  end

  describe "format_result/3" do
    test "formats summary stats using reporter" do
      summary_stats = [
        %{statistic: "number-of-commits", value: 10},
        %{statistic: "number-of-authors", value: 3},
        %{statistic: "number-of-entities", value: 25}
      ]

      ReporterMock
      |> expect(:report, fn stats, opts ->
        assert stats == summary_stats
        assert opts == %{format: "csv"}
        {:ok, "statistic,value\nnumber-of-commits,10\n..."}
      end)

      deps = %{reporter: ReporterMock}

      assert {:ok, "statistic,value\nnumber-of-commits,10\n..."} =
               GetSummary.format_result(summary_stats, deps, %{format: "csv"})
    end

    test "propagates reporter errors" do
      summary_stats = [%{statistic: "test", value: 1}]

      ReporterMock
      |> expect(:report, fn _stats, _opts ->
        {:error, "Reporter failed"}
      end)

      deps = %{reporter: ReporterMock}

      assert {:error, "Reporter failed"} =
               GetSummary.format_result(summary_stats, deps, %{})
    end
  end

  describe "edge cases" do
    test "handles commits with duplicate authors" do
      # Create commits with same author
      author = Author.new("Alice", "alice@example.com")

      commits =
        Enum.map(1..3, fn i ->
          file_changes = [FileChange.new("file#{i}.ex", "10", "5")]
          Commit.new("commit#{i}", author, "2023-01-0#{i}", "Commit #{i}", file_changes)
        end)

      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts ->
        {:ok, commits}
      end)

      ReporterMock
      |> expect(:report, fn stats, _opts ->
        authors_stat = Enum.find(stats, &(&1.statistic == "number-of-authors"))
        # Should count unique authors
        assert authors_stat.value == 1
        {:ok, "Summary"}
      end)

      result = GetSummary.execute("/repo.log", %{vcs: "test_git", format: "test_csv"})
      assert {:ok, "Summary"} = result
    end

    test "handles commits with no file changes" do
      author = Author.new("Bob", "bob@example.com")

      commits = [
        Commit.new("empty1", author, "2023-01-01", "Empty commit", [])
      ]

      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts ->
        {:ok, commits}
      end)

      ReporterMock
      |> expect(:report, fn stats, _opts ->
        entities_stat = Enum.find(stats, &(&1.statistic == "number-of-entities"))
        assert entities_stat.value == 0
        {:ok, "Summary"}
      end)

      result = GetSummary.execute("/repo.log", %{vcs: "test_git", format: "test_csv"})
      assert {:ok, "Summary"} = result
    end
  end
end
