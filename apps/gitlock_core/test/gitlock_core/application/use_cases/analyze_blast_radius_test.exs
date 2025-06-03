defmodule GitlockCore.Application.UseCases.AnalyzeBlastRadiusTest do
  use ExUnit.Case, async: true

  import GitlockCore.TestSupport.AdaptersSetup, only: [setup_unique_adapters: 0]

  alias GitlockCore.Mocks.{
    VersionControlMock,
    ReporterMock,
    ComplexityAnalyzerMock,
    FileSystemMock
  }

  alias GitlockCore.Application.UseCases.AnalyzeBlastRadius
  alias GitlockCore.Domain.Entities.{Commit, Author}
  alias GitlockCore.Domain.Values.{FileChange, ComplexityMetrics, ChangeImpact}

  # Set up unique adapters for each test
  setup_unique_adapters()

  # Helper function to create test commits
  defp create_test_commits do
    author = Author.new("Test Author")

    # Create commits with patterns that establish coupling between files
    [
      # Files that change together frequently
      Commit.new(
        "commit1",
        author,
        "2023-01-01",
        "Initial commit",
        [
          FileChange.new("lib/core/session.ex", "100", "0"),
          FileChange.new("lib/core/auth.ex", "80", "0"),
          FileChange.new("lib/core/user.ex", "120", "0")
        ]
      ),
      Commit.new(
        "commit2",
        author,
        "2023-01-02",
        "Update core",
        [
          FileChange.new("lib/core/session.ex", "20", "10"),
          FileChange.new("lib/core/auth.ex", "15", "5")
        ]
      ),
      Commit.new(
        "commit3",
        author,
        "2023-01-03",
        "Update session logic",
        [
          FileChange.new("lib/core/session.ex", "30", "15"),
          FileChange.new("lib/core/user.ex", "10", "5")
        ]
      ),
      # Some isolated changes
      Commit.new(
        "commit4",
        author,
        "2023-01-04",
        "Add utils",
        [
          FileChange.new("lib/utils/helper.ex", "50", "0")
        ]
      ),
      # More co-changes to establish coupling patterns
      Commit.new(
        "commit5",
        author,
        "2023-01-05",
        "Update auth and session",
        [
          FileChange.new("lib/core/session.ex", "15", "5"),
          FileChange.new("lib/core/auth.ex", "10", "10")
        ]
      )
    ]
  end

  # Helper to create test complexity metrics
  defp create_test_complexity_map do
    %{
      "lib/core/session.ex" => ComplexityMetrics.new("lib/core/session.ex", 200, 25, :elixir),
      "lib/core/auth.ex" => ComplexityMetrics.new("lib/core/auth.ex", 150, 15, :elixir),
      "lib/core/user.ex" => ComplexityMetrics.new("lib/core/user.ex", 180, 20, :elixir),
      "lib/utils/helper.ex" => ComplexityMetrics.new("lib/utils/helper.ex", 50, 5, :elixir)
    }
  end

  describe "execute/2 - full workflow" do
    test "successfully analyzes blast radius with valid options", %{adapter_keys: keys} do
      commits = create_test_commits()
      complexity_map = create_test_complexity_map()

      # Setup mock expectations
      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts ->
        {:ok, commits}
      end)

      ComplexityAnalyzerMock
      |> expect(:analyze_directory, fn _dir, _opts ->
        complexity_map
      end)

      FileSystemMock
      |> expect(:list_all_files, fn _base_path ->
        Map.keys(complexity_map)
      end)

      ReporterMock
      |> expect(:report, fn results, _opts ->
        # Verify results structure
        assert is_list(results)
        assert length(results) > 0

        # First result should have expected fields
        first_result = hd(results)
        assert Map.has_key?(first_result, :entity)
        assert Map.has_key?(first_result, :risk_score)
        assert Map.has_key?(first_result, :impact_severity)
        assert Map.has_key?(first_result, :affected_files_count)

        {:ok, "Report generated"}
      end)

      # Execute the use case with valid options
      result =
        AnalyzeBlastRadius.execute("repo_path", %{
          vcs: keys.vcs,
          format: keys.csv_reporter,
          dir: "/test/dir",
          complexity_analyzer: keys.complexity,
          file_system: keys.file_system,
          target_files: ["lib/core/session.ex"]
        })

      assert result == {:ok, "Report generated"}
    end

    test "fails when target_files not specified", %{adapter_keys: keys} do
      # Execute without target_files
      result =
        AnalyzeBlastRadius.execute("repo_path", %{
          vcs: keys.vcs,
          format: keys.csv_reporter,
          dir: "/test/dir",
          complexity_analyzer: keys.complexity
        })

      assert {:error, "No target_files specified. Use --target-files option"} = result
    end

    test "fails when directory not provided", %{adapter_keys: keys} do
      # When missing the dir option, should return an error
      result =
        AnalyzeBlastRadius.execute("repo_path", %{
          vcs: keys.vcs,
          format: keys.csv_reporter,
          target_files: ["lib/file.ex"]
        })

      assert {:error, "Directory path required for blast radius analysis"} = result
    end
  end

  describe "resolve_dependencies/1" do
    test "resolves dependencies correctly", %{adapter_keys: keys} do
      options = %{
        vcs: keys.vcs,
        format: keys.csv_reporter,
        dir: "/test/dir",
        complexity_analyzer: keys.complexity,
        file_system: keys.file_system
      }

      {:ok, deps} = AnalyzeBlastRadius.resolve_dependencies(options)

      assert deps.vcs == VersionControlMock
      assert deps.reporter == ReporterMock
      assert deps.analyzer == ComplexityAnalyzerMock
      assert deps.file_system == FileSystemMock
    end
  end

  describe "run_domain_logic/3" do
    test "processes commits and generates impact analysis", %{adapter_keys: _keys} do
      commits = create_test_commits()
      complexity_map = create_test_complexity_map()
      target_files = ["lib/core/session.ex"]

      VersionControlMock
      |> expect(:get_commit_history, fn "repo_path", _opts ->
        {:ok, commits}
      end)

      ComplexityAnalyzerMock
      |> expect(:analyze_directory, fn "/test/dir", _opts ->
        complexity_map
      end)

      FileSystemMock
      |> expect(:list_all_files, fn "/test/dir" ->
        Map.keys(complexity_map)
      end)

      deps = %{
        vcs: VersionControlMock,
        reporter: ReporterMock,
        analyzer: ComplexityAnalyzerMock,
        file_system: FileSystemMock
      }

      options = %{
        dir: "/test/dir",
        target_files: target_files
      }

      {:ok, results} = AnalyzeBlastRadius.run_domain_logic("repo_path", deps, options)

      # Verify results structure
      assert is_list(results)
      assert length(results) == length(target_files)

      # Check that results contain ChangeImpact objects
      impact = hd(results)
      assert %ChangeImpact{} = impact
      assert impact.entity == "lib/core/session.ex"
      assert is_float(impact.risk_score)
      assert impact.impact_severity in [:high, :medium, :low]
      assert is_list(impact.affected_files)
      assert is_map(impact.affected_components)
      assert is_list(impact.suggested_reviewers)
    end

    test "returns error when no target files specified" do
      deps = %{vcs: VersionControlMock, reporter: ReporterMock}
      options = %{dir: "/test/dir", target_files: []}

      result = AnalyzeBlastRadius.run_domain_logic("repo_path", deps, options)

      assert {:error, "No target_files specified. Use --target-files option"} = result
    end
  end

  describe "format_result/3" do
    test "formats results as summary by default", %{adapter_keys: _keys} do
      # Create a simple ChangeImpact
      impact = %ChangeImpact{
        entity: "lib/test.ex",
        risk_score: 6.5,
        impact_severity: :medium,
        affected_files: [
          %{file: "lib/other.ex", impact: 0.5, distance: 1, component: "core"}
        ],
        affected_components: %{"core" => 0.5},
        suggested_reviewers: ["Alice"],
        risk_factors: ["Medium complexity"]
      }

      ReporterMock
      |> expect(:report, fn results, _opts ->
        # Verify summary format
        assert length(results) == 1
        result = hd(results)

        assert result.entity == "lib/test.ex"
        assert result.risk_score == 6.5
        assert result.impact_severity == :medium
        assert result.affected_files_count == 1
        assert result.affected_components_count == 1
        assert result.suggested_reviewers == ["Alice"]

        {:ok, "Summary formatted"}
      end)

      deps = %{reporter: ReporterMock}
      options = %{}

      result = AnalyzeBlastRadius.format_result([impact], deps, options)

      assert {:ok, "Summary formatted"} = result
    end

    test "formats results as JSON when specified", %{adapter_keys: _keys} do
      # Create a simple ChangeImpact
      impact = %ChangeImpact{
        entity: "lib/test.ex",
        risk_score: 6.5,
        impact_severity: :medium,
        affected_files: [
          %{file: "lib/other.ex", impact: 0.5, distance: 1, component: "core"}
        ],
        affected_components: %{"core" => 0.5},
        suggested_reviewers: ["Alice"],
        risk_factors: ["Medium complexity"]
      }

      ReporterMock
      |> expect(:report, fn results, _opts ->
        # Verify results are full maps
        assert length(results) == 1
        result = hd(results)

        # Should be the direct map representation with all fields
        assert result == ChangeImpact.to_map(impact)

        {:ok, "JSON formatted"}
      end)

      deps = %{reporter: ReporterMock}
      options = %{format: "json"}

      result = AnalyzeBlastRadius.format_result([impact], deps, options)

      assert {:ok, "JSON formatted"} = result
    end
  end
end
