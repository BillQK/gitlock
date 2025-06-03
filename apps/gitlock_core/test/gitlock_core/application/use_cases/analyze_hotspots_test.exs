defmodule GitlockCore.Application.UseCases.AnalyzeHotspotsTest do
  use ExUnit.Case, async: true

  import GitlockCore.TestSupport.AdaptersSetup, only: [setup_unique_adapters: 0]

  alias GitlockCore.Mocks.{VersionControlMock, ReporterMock, ComplexityAnalyzerMock}
  alias GitlockCore.Application.UseCases.AnalyzeHotspots
  alias GitlockCore.Domain.Entities.{Commit, Author}
  alias GitlockCore.Domain.Values.{FileChange, ComplexityMetrics}

  # Set up unique adapters for each test
  setup_unique_adapters()

  describe "execute/2" do
    test "performs full hotspot analysis workflow", %{adapter_keys: keys} do
      # Create test data
      commits = [
        create_test_commit("c1", "2023-01-01", [
          {"lib/hotspot.ex", 10, 5},
          {"lib/normal.ex", 5, 2}
        ]),
        create_test_commit("c2", "2023-01-02", [
          {"lib/hotspot.ex", 20, 10}
        ])
      ]

      complexity_metrics = %{
        "lib/hotspot.ex" => ComplexityMetrics.new("lib/hotspot.ex", 200, 25, :elixir),
        "lib/normal.ex" => ComplexityMetrics.new("lib/normal.ex", 50, 5, :elixir)
      }

      # Set up mocks
      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts -> {:ok, commits} end)

      ComplexityAnalyzerMock
      |> expect(:analyze_directory, fn _dir, _opts -> complexity_metrics end)

      ReporterMock
      |> expect(:report, fn results, _opts ->
        # Verify results
        assert length(results) == 2

        # First result should be the hotspot
        hotspot = hd(results)
        assert hotspot.entity == "lib/hotspot.ex"
        assert hotspot.revisions == 2
        assert hotspot.complexity == 25
        assert hotspot.risk_score > 0

        {:ok, "Hotspot analysis report"}
      end)

      # Execute the use case
      result =
        AnalyzeHotspots.execute("/repo/path", %{
          vcs: keys.vcs,
          format: keys.csv_reporter,
          dir: "/test/dir",
          complexity_analyzer: keys.complexity
        })

      assert result == {:ok, "Hotspot analysis report"}
    end

    test "fails when directory not provided", %{adapter_keys: keys} do
      result =
        AnalyzeHotspots.execute("/repo/path", %{
          vcs: keys.vcs,
          format: keys.csv_reporter
        })

      assert {:error, "Directory path required for hotspot analysis"} = result
    end
  end

  describe "resolve_dependencies/1" do
    test "resolves all required dependencies", %{adapter_keys: keys} do
      options = %{
        vcs: keys.vcs,
        format: keys.csv_reporter,
        dir: "/test/dir",
        complexity_analyzer: keys.complexity
      }

      {:ok, deps} = AnalyzeHotspots.resolve_dependencies(options)

      assert deps.vcs == VersionControlMock
      assert deps.reporter == ReporterMock
      assert deps.analyzer == ComplexityAnalyzerMock
    end
  end

  # Helper function
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
