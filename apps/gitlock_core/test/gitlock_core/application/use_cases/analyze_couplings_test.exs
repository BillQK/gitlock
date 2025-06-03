defmodule GitlockCore.Application.UseCases.AnalyzeCouplingsTest do
  use ExUnit.Case, async: true

  import GitlockCore.TestSupport.AdaptersSetup, only: [setup_unique_adapters: 0]

  alias GitlockCore.Mocks.{VersionControlMock, ReporterMock}
  alias GitlockCore.Application.UseCases.AnalyzeCouplings
  alias GitlockCore.Domain.Entities.{Commit, Author}
  alias GitlockCore.Domain.Values.{FileChange, CouplingMetrics}

  # Set up unique adapters for each test
  setup_unique_adapters()

  describe "execute/2" do
    test "successfully analyzes couplings", %{adapter_keys: keys} do
      # Create test commits with strong coupling pattern
      commits = [
        # Files that frequently change together
        create_test_commit("c1", "2023-01-01", [
          {"lib/module_a.ex", 10, 5},
          {"lib/module_b.ex", 8, 3}
        ]),
        create_test_commit("c2", "2023-01-02", [
          {"lib/module_a.ex", 6, 2},
          {"lib/module_b.ex", 7, 4}
        ]),
        create_test_commit("c3", "2023-01-03", [
          {"lib/module_a.ex", 12, 8},
          {"lib/module_b.ex", 5, 3}
        ]),
        create_test_commit("c4", "2023-01-04", [
          {"lib/module_a.ex", 9, 4},
          {"lib/module_b.ex", 6, 2}
        ]),
        create_test_commit("c5", "2023-01-05", [
          {"lib/module_a.ex", 7, 3},
          {"lib/module_b.ex", 11, 6}
        ]),

        # Some unrelated changes for good measure
        create_test_commit("c6", "2023-01-06", [{"lib/module_c.ex", 15, 10}]),
        create_test_commit("c7", "2023-01-07", [{"lib/module_d.ex", 20, 5}])
      ]

      # Setup mocks
      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts ->
        {:ok, commits}
      end)

      ReporterMock
      |> expect(:report, fn results, _opts ->
        # Verify the results structure
        assert is_list(results)
        assert length(results) > 0

        # First result should be a coupling between module_a and module_b
        coupling = hd(results)
        assert %CouplingMetrics{} = coupling
        assert coupling.entity in ["lib/module_a.ex", "lib/module_b.ex"]
        assert coupling.coupled in ["lib/module_a.ex", "lib/module_b.ex"]
        assert coupling.entity != coupling.coupled

        # Should have strong coupling
        # Very strong coupling
        assert coupling.degree > 90.0
        # Changed together 5 times
        assert coupling.windows >= 5

        {:ok, "Coupling analysis report"}
      end)

      # Execute the use case
      options = %{
        vcs: keys.vcs,
        format: keys.csv_reporter,
        # Set minimum coupling threshold
        min_coupling: 50.0,
        # Set minimum co-change count
        min_windows: 5
      }

      result = AnalyzeCouplings.execute("/repo/path", options)

      assert result == {:ok, "Coupling analysis report"}
    end

    test "handles VCS error", %{adapter_keys: keys} do
      # Setup VCS mock to return an error
      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts ->
        {:error, "Failed to read commit history"}
      end)

      # Execute the use case
      result =
        AnalyzeCouplings.execute("/repo/path", %{
          vcs: keys.vcs,
          format: keys.csv_reporter
        })

      # Should propagate the error
      assert result == {:error, "Failed to read commit history"}
    end

    test "passes custom thresholds to coupling detection", %{adapter_keys: keys} do
      # Create minimal commits
      commits = [
        create_test_commit("c1", "2023-01-01", [
          {"file_a.ex", 1, 0},
          {"file_b.ex", 1, 0}
        ]),
        create_test_commit("c2", "2023-01-02", [
          {"file_a.ex", 1, 0},
          {"file_b.ex", 1, 0}
        ])
      ]

      # Setup mocks
      VersionControlMock
      |> expect(:get_commit_history, fn _path, opts ->
        # Verify threshold options are passed down
        assert opts[:min_coupling] == 25.0
        assert opts[:min_windows] == 2
        {:ok, commits}
      end)

      ReporterMock
      |> expect(:report, fn _results, _opts ->
        {:ok, "Report with custom thresholds"}
      end)

      # Execute with custom thresholds
      options = %{
        vcs: keys.vcs,
        format: keys.csv_reporter,
        min_coupling: 25.0,
        min_windows: 2
      }

      result = AnalyzeCouplings.execute("/repo/path", options)

      assert result == {:ok, "Report with custom thresholds"}
    end
  end

  describe "resolve_dependencies/1" do
    test "resolves required dependencies", %{adapter_keys: keys} do
      options = %{
        vcs: keys.vcs,
        format: keys.csv_reporter
      }

      {:ok, deps} = AnalyzeCouplings.resolve_dependencies(options)

      assert deps.vcs == VersionControlMock
      assert deps.reporter == ReporterMock
    end

    test "returns error when VCS adapter not found", %{adapter_keys: keys} do
      options = %{
        vcs: "nonexistent_adapter",
        format: keys.csv_reporter
      }

      result = AnalyzeCouplings.resolve_dependencies(options)

      assert {:error, "Adapter not found: vcs/nonexistent_adapter"} = result
    end

    test "returns error when reporter not found", %{adapter_keys: keys} do
      options = %{
        vcs: keys.vcs,
        format: "nonexistent_format"
      }

      result = AnalyzeCouplings.resolve_dependencies(options)

      assert {:error, "Adapter not found: reporter/nonexistent_format"} = result
    end
  end

  # Helper function to create test commits
  defp create_test_commit(id, date, file_changes) do
    changes =
      Enum.map(file_changes, fn {path, added, deleted} ->
        FileChange.new(path, to_string(added), to_string(deleted))
      end)

    Commit.new(
      id,
      Author.new("Test Author"),
      date,
      "Test commit",
      changes
    )
  end
end
