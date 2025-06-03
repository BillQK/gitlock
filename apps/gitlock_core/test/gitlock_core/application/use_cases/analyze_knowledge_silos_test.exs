defmodule GitlockCore.Application.UseCases.AnalyzeKnowledgeSilosTest do
  use ExUnit.Case, async: true

  import GitlockCore.TestSupport.AdaptersSetup, only: [setup_unique_adapters: 0]

  alias GitlockCore.Adapters.Reporters.CsvReporter
  alias GitlockCore.Adapters.VCS.Git
  alias GitlockCore.Mocks.{VersionControlMock, ReporterMock}
  alias GitlockCore.Application.UseCases.AnalyzeKnowledgeSilos
  alias GitlockCore.Domain.Entities.{Commit, Author}
  alias GitlockCore.Domain.Values.{FileChange, KnowledgeSilo}

  # Set up unique adapters for each test
  setup_unique_adapters()

  # Helper function to create test commits with knowledge silo patterns
  defp create_test_commits do
    # Create author entities
    alice = Author.new("Alice", "alice@example.com")
    bob = Author.new("Bob", "bob@example.com")
    carol = Author.new("Carol", "carol@example.com")
    dave = Author.new("Dave", "dave@example.com")

    # Create a knowledge silo - many commits to the same file by the same author
    silo_commits =
      Enum.map(1..12, fn i ->
        Commit.new(
          "silo_commit_#{i}",
          # Same author for all commits
          alice,
          "2023-01-#{String.pad_leading("#{i}", 2, "0")}",
          "Silo commit #{i}",
          [FileChange.new("lib/silo_file.ex", "10", "5")]
        )
      end)

    # Create a file with balanced ownership
    balanced_commits =
      [
        Commit.new(
          "balanced_1",
          alice,
          "2023-02-01",
          "Balanced commit 1",
          [FileChange.new("lib/balanced_file.ex", "10", "5")]
        ),
        Commit.new(
          "balanced_2",
          bob,
          "2023-02-02",
          "Balanced commit 2",
          [FileChange.new("lib/balanced_file.ex", "8", "3")]
        ),
        Commit.new(
          "balanced_3",
          carol,
          "2023-02-03",
          "Balanced commit 3",
          [FileChange.new("lib/balanced_file.ex", "12", "6")]
        )
      ]

    # Create a partial silo - moderate ownership concentration
    partial_silo_commits =
      [
        # Dave has 4 out of 6 commits (67%)
        Commit.new(
          "partial_1",
          dave,
          "2023-03-01",
          "Partial silo commit 1",
          [FileChange.new("lib/partial_silo.ex", "10", "5")]
        ),
        Commit.new(
          "partial_2",
          dave,
          "2023-03-02",
          "Partial silo commit 2",
          [FileChange.new("lib/partial_silo.ex", "8", "3")]
        ),
        Commit.new(
          "partial_3",
          dave,
          "2023-03-03",
          "Partial silo commit 3",
          [FileChange.new("lib/partial_silo.ex", "12", "6")]
        ),
        Commit.new(
          "partial_4",
          dave,
          "2023-03-04",
          "Partial silo commit 4",
          [FileChange.new("lib/partial_silo.ex", "9", "4")]
        ),
        # Other authors have 1 commit each
        Commit.new(
          "partial_5",
          alice,
          "2023-03-05",
          "Partial silo commit 5",
          [FileChange.new("lib/partial_silo.ex", "7", "2")]
        ),
        Commit.new(
          "partial_6",
          bob,
          "2023-03-06",
          "Partial silo commit 6",
          [FileChange.new("lib/partial_silo.ex", "11", "5")]
        )
      ]

    # Combine all the commits
    silo_commits ++ balanced_commits ++ partial_silo_commits
  end

  describe "execute/2 - full workflow" do
    test "successfully analyzes knowledge silos", %{adapter_keys: keys} do
      commits = create_test_commits()

      # Setup mock expectations
      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts ->
        {:ok, commits}
      end)

      ReporterMock
      |> expect(:report, fn results, _opts ->
        # Verify results structure
        assert length(results) > 0

        # First result should be a KnowledgeSilo with highest ownership
        first_result = hd(results)
        assert %KnowledgeSilo{} = first_result

        # Should be the file with 100% ownership by Alice
        assert first_result.entity == "lib/silo_file.ex"
        assert first_result.main_author == "Alice <alice@example.com>"
        assert first_result.ownership_ratio == 100.0
        assert first_result.risk_level == :high

        # Verify other results
        partial_silo = Enum.find(results, &(&1.entity == "lib/partial_silo.ex"))
        assert partial_silo != nil
        assert partial_silo.main_author == "Dave <dave@example.com>"
        # Dave has 4 out of 6 commits (66.7%)
        assert_in_delta partial_silo.ownership_ratio, 66.7, 0.1

        # Balanced file should be there too
        balanced = Enum.find(results, &(&1.entity == "lib/balanced_file.ex"))
        assert balanced != nil
        # One author has 1 out of 3 commits (33.3%)
        assert_in_delta balanced.ownership_ratio, 33.3, 0.1

        {:ok, "Report generated"}
      end)

      # Execute the use case
      result =
        AnalyzeKnowledgeSilos.execute("repo_path", %{
          vcs: keys.vcs,
          format: keys.csv_reporter
        })

      assert result == {:ok, "Report generated"}
    end
  end

  describe "resolve_dependencies/1" do
    test "resolves dependencies correctly", %{adapter_keys: keys} do
      options = %{
        vcs: keys.vcs,
        format: keys.csv_reporter
      }

      {:ok, deps} = AnalyzeKnowledgeSilos.resolve_dependencies(options)

      assert deps.vcs == VersionControlMock
      assert deps.reporter == ReporterMock
    end

    test "uses default values when not specified", %{adapter_keys: _keys} do
      {:ok, deps} = AnalyzeKnowledgeSilos.resolve_dependencies(%{})

      assert deps.vcs == Git
      assert deps.reporter == CsvReporter
    end

    test "returns error when VCS adapter not found", %{adapter_keys: _keys} do
      options = %{
        vcs: "non_existent",
        format: "csv"
      }

      result = AnalyzeKnowledgeSilos.resolve_dependencies(options)
      assert {:error, "Adapter not found: vcs/non_existent"} = result
    end

    test "returns error when reporter adapter not found", %{adapter_keys: keys} do
      options = %{
        vcs: keys.vcs,
        format: "non_existent"
      }

      result = AnalyzeKnowledgeSilos.resolve_dependencies(options)
      assert {:error, "Adapter not found: reporter/non_existent"} = result
    end
  end

  describe "run_domain_logic/3" do
    test "processes commits and produces knowledge silo results" do
      commits = create_test_commits()

      VersionControlMock
      |> expect(:get_commit_history, fn "repo_path", _opts ->
        {:ok, commits}
      end)

      deps = %{
        vcs: VersionControlMock,
        reporter: ReporterMock
      }

      options = %{}

      {:ok, results} = AnalyzeKnowledgeSilos.run_domain_logic("repo_path", deps, options)

      # Verify results
      assert is_list(results)
      # Three unique files in our test data
      assert length(results) == 3

      # Results should be sorted by ownership ratio (descending)
      [silo, partial, balanced] = results

      # Full silo (100% Alice)
      assert silo.entity == "lib/silo_file.ex"
      assert silo.ownership_ratio == 100.0
      assert silo.risk_level == :high

      # Partial silo (66.7% Dave)
      assert partial.entity == "lib/partial_silo.ex"
      assert_in_delta partial.ownership_ratio, 66.7, 0.1

      # Balanced file (33.3% ownership)
      assert balanced.entity == "lib/balanced_file.ex"
      assert_in_delta balanced.ownership_ratio, 33.3, 0.1
      assert balanced.risk_level == :low
    end

    test "handles VCS errors" do
      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts ->
        {:error, "VCS error"}
      end)

      deps = %{
        vcs: VersionControlMock,
        reporter: ReporterMock
      }

      options = %{}

      assert {:error, "VCS error"} =
               AnalyzeKnowledgeSilos.run_domain_logic("repo_path", deps, options)
    end

    test "handles empty commit list" do
      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts ->
        {:ok, []}
      end)

      deps = %{
        vcs: VersionControlMock,
        reporter: ReporterMock
      }

      options = %{}

      {:ok, results} = AnalyzeKnowledgeSilos.run_domain_logic("repo_path", deps, options)

      # Should return an empty list, not an error
      assert results == []
    end
  end

  describe "format_result/3" do
    test "formats knowledge silo results using reporter" do
      knowledge_silos = [
        %KnowledgeSilo{
          entity: "lib/silo_file.ex",
          main_author: "Alice <alice@example.com>",
          ownership_ratio: 100.0,
          num_authors: 1,
          num_commits: 12,
          risk_level: :high
        }
      ]

      ReporterMock
      |> expect(:report, fn silos, opts ->
        # Verify silos passed through
        assert silos == knowledge_silos
        # Verify options passed through
        assert opts == %{format: "json"}
        {:ok, "JSON report"}
      end)

      deps = %{reporter: ReporterMock}
      options = %{format: "json"}

      assert {:ok, "JSON report"} =
               AnalyzeKnowledgeSilos.format_result(knowledge_silos, deps, options)
    end
  end
end
