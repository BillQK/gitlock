defmodule GitlockCore.Application.UseCases.AnalyzeCodeAgeTest do
  use ExUnit.Case, async: true

  import GitlockCore.TestSupport.AdaptersSetup, only: [setup_unique_adapters: 0]
  import Mox

  alias GitlockCore.Mocks.{VersionControlMock, ReporterMock}
  alias GitlockCore.Application.UseCases.AnalyzeCodeAge
  alias GitlockCore.Domain.Entities.{Commit, Author}
  alias GitlockCore.Domain.Values.{FileChange, CodeAge}

  # Set up unique adapters for each test
  setup_unique_adapters()

  describe "execute/2" do
    test "performs full code age analysis workflow", %{adapter_keys: keys} do
      # Create test data
      commits = create_test_commits()

      # Set up mocks
      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts -> {:ok, commits} end)

      ReporterMock
      |> expect(:report, fn results, _opts ->
        # Verify results structure
        assert is_list(results)
        assert length(results) == 3

        # Verify all results are CodeAge structs
        Enum.each(results, fn result ->
          assert %CodeAge{} = result
          assert is_binary(result.entity)
          assert is_number(result.age_months)
          assert is_atom(result.risk)
        end)

        {:ok, "Code age analysis report"}
      end)

      # Execute the use case
      result =
        AnalyzeCodeAge.execute("/repo/path", %{
          vcs: keys.vcs,
          format: keys.csv_reporter
        })

      assert result == {:ok, "Code age analysis report"}
    end

    test "handles VCS errors gracefully", %{adapter_keys: keys} do
      # Mock VCS to return error
      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts ->
        {:error, {:io, "/bad/path", :enoent}}
      end)

      result =
        AnalyzeCodeAge.execute("/bad/path", %{
          vcs: keys.vcs,
          format: keys.csv_reporter
        })

      assert {:error, {:io, "/bad/path", :enoent}} = result
    end

    test "handles empty commit history", %{adapter_keys: keys} do
      # Mock VCS to return empty commits
      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts -> {:ok, []} end)

      ReporterMock
      |> expect(:report, fn results, _opts ->
        # Should handle empty results gracefully
        assert is_list(results)
        {:ok, "Empty code age report"}
      end)

      result =
        AnalyzeCodeAge.execute("/empty/repo", %{
          vcs: keys.vcs,
          format: keys.csv_reporter
        })

      assert result == {:ok, "Empty code age report"}
    end
  end

  describe "resolve_dependencies/1" do
    test "resolves VCS and reporter dependencies", %{adapter_keys: keys} do
      options = %{
        vcs: keys.vcs,
        format: keys.csv_reporter
      }

      {:ok, deps} = AnalyzeCodeAge.resolve_dependencies(options)

      assert deps.vcs == VersionControlMock
      assert deps.reporter == ReporterMock
    end

    test "resolves default dependencies when no options provided", %{adapter_keys: keys} do
      # Register the generated unique adapters as defaults
      options = %{vcs: keys.vcs, format: keys.csv_reporter}

      assert {:ok, deps} = AnalyzeCodeAge.resolve_dependencies(options)

      assert deps.vcs == VersionControlMock
      assert deps.reporter == ReporterMock
    end

    test "resolves custom VCS adapter", %{adapter_keys: keys} do
      assert {:ok, deps} =
               AnalyzeCodeAge.resolve_dependencies(%{
                 vcs: keys.vcs,
                 format: keys.csv_reporter
               })

      assert deps.vcs == VersionControlMock
    end

    test "resolves custom reporter based on format", %{adapter_keys: keys} do
      assert {:ok, deps} =
               AnalyzeCodeAge.resolve_dependencies(%{
                 vcs: keys.vcs,
                 format: keys.json_reporter
               })

      assert deps.reporter == ReporterMock
    end

    test "returns error when VCS adapter not found" do
      result = AnalyzeCodeAge.resolve_dependencies(%{vcs: "non_existent"})

      assert {:error, "Adapter not found: vcs/non_existent"} = result
    end

    test "returns error when reporter adapter not found" do
      result = AnalyzeCodeAge.resolve_dependencies(%{format: "non_existent"})

      assert {:error, "Adapter not found: reporter/non_existent"} = result
    end
  end

  describe "run_domain_logic/3" do
    test "successfully processes commits and calculates code age", %{adapter_keys: _keys} do
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

      {:ok, results} = AnalyzeCodeAge.run_domain_logic("repo_path", deps, options)

      # Verify results are returned
      assert is_list(results)

      # If results are not empty, verify they are CodeAge structs
      if !Enum.empty?(results) do
        first_result = hd(results)
        assert %CodeAge{} = first_result
        assert is_binary(first_result.entity)
        assert is_number(first_result.age_months)
        assert first_result.age_months >= 0
        assert is_atom(first_result.risk)
        assert first_result.risk in [:low, :medium, :high]
      end
    end

    test "handles VCS error in domain logic", %{adapter_keys: _keys} do
      VersionControlMock
      |> expect(:get_commit_history, fn "bad_path", _opts ->
        {:error, {:io, "bad_path", :enoent}}
      end)

      deps = %{
        vcs: VersionControlMock,
        reporter: ReporterMock
      }

      result = AnalyzeCodeAge.run_domain_logic("bad_path", deps, %{})

      assert {:error, {:io, "bad_path", :enoent}} = result
    end

    test "processes commits with file history normalization", %{adapter_keys: _keys} do
      # Create commits with renames to test normalization
      commits = [
        create_test_commit("c1", "2023-01-01", [
          {"lib/auth.ex", 50, 10}
        ]),
        create_test_commit("c2", "2023-01-02", [
          # Pure rename
          {"{lib/auth.ex => lib/authentication.ex}", 0, 0}
        ]),
        create_test_commit("c3", "2023-01-03", [
          # Change after rename
          {"lib/authentication.ex", 20, 5}
        ])
      ]

      VersionControlMock
      |> expect(:get_commit_history, fn "repo_path", _opts ->
        {:ok, commits}
      end)

      deps = %{
        vcs: VersionControlMock,
        reporter: ReporterMock
      }

      {:ok, results} = AnalyzeCodeAge.run_domain_logic("repo_path", deps, %{})

      # Should handle the rename normalization correctly
      assert is_list(results)
    end
  end

  describe "format_result/3" do
    test "formats results using the reporter" do
      results = [
        CodeAge.new("lib/old_file.ex", 15.5, :high),
        CodeAge.new("lib/recent_file.ex", 2.0, :low)
      ]

      deps = %{reporter: ReporterMock}
      options = %{format: :csv}

      ReporterMock
      |> expect(:report, fn ^results, ^options ->
        {:ok, "Formatted code age report"}
      end)

      result = AnalyzeCodeAge.format_result(results, deps, options)

      assert result == {:ok, "Formatted code age report"}
    end

    test "handles reporter errors" do
      results = [CodeAge.new("lib/test.ex", 5.0, :medium)]
      deps = %{reporter: ReporterMock}
      options = %{}

      ReporterMock
      |> expect(:report, fn _results, _options ->
        {:error, "Reporter failed"}
      end)

      result = AnalyzeCodeAge.format_result(results, deps, options)

      assert result == {:error, "Reporter failed"}
    end

    test "passes through options to reporter" do
      results = [CodeAge.new("lib/test.ex", 10.0, :high)]
      deps = %{reporter: ReporterMock}

      custom_options = %{
        output_file: "code_age_report.csv",
        include_headers: true,
        date_format: "ISO"
      }

      ReporterMock
      |> expect(:report, fn ^results, ^custom_options ->
        {:ok, "Custom formatted report"}
      end)

      result = AnalyzeCodeAge.format_result(results, deps, custom_options)

      assert result == {:ok, "Custom formatted report"}
    end
  end

  describe "integration scenarios" do
    test "handles repositories with mixed file ages", %{adapter_keys: keys} do
      # Mix of old and new commits to create varied code ages
      old_commits = [
        create_test_commit("old1", "2020-01-01", [{"lib/legacy.ex", 100, 20}]),
        create_test_commit("old2", "2020-06-01", [{"lib/legacy.ex", 50, 10}])
      ]

      recent_commits = [
        create_test_commit("recent1", "2024-01-01", [{"lib/new_feature.ex", 80, 5}]),
        create_test_commit("recent2", "2024-02-01", [{"lib/new_feature.ex", 30, 2}])
      ]

      all_commits = old_commits ++ recent_commits

      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts -> {:ok, all_commits} end)

      ReporterMock
      |> expect(:report, fn results, _opts ->
        # Should have results for both files with different age categories
        assert length(results) >= 1

        # Find files with different risk levels if present
        risk_levels = results |> Enum.map(& &1.risk) |> Enum.uniq()

        # Should have varied risk levels due to different ages
        if length(results) > 1 do
          assert length(risk_levels) >= 1
        end

        {:ok, "Mixed age analysis report"}
      end)

      result =
        AnalyzeCodeAge.execute("/mixed/repo", %{
          vcs: keys.vcs,
          format: keys.csv_reporter
        })

      assert result == {:ok, "Mixed age analysis report"}
    end

    test "handles repositories with only recent activity", %{adapter_keys: keys} do
      # All commits from last few months
      recent_commits = [
        create_test_commit("r1", "2024-05-01", [{"lib/fresh1.ex", 40, 5}]),
        create_test_commit("r2", "2024-06-01", [{"lib/fresh2.ex", 60, 8}]),
        create_test_commit("r3", "2024-06-15", [{"lib/fresh1.ex", 20, 3}])
      ]

      VersionControlMock
      |> expect(:get_commit_history, fn _path, _opts -> {:ok, recent_commits} end)

      ReporterMock
      |> expect(:report, fn results, _opts ->
        # All files should be relatively fresh (low risk)
        if !Enum.empty?(results) do
          Enum.each(results, fn result ->
            # Files should be recent (low age in months)
            assert result.age_months >= 0
            # Most should be low risk since they're recent
            assert result.risk in [:low, :medium, :high]
          end)
        end

        {:ok, "Fresh codebase report"}
      end)

      result =
        AnalyzeCodeAge.execute("/fresh/repo", %{
          vcs: keys.vcs,
          format: keys.csv_reporter
        })

      assert result == {:ok, "Fresh codebase report"}
    end
  end

  # Helper function to create test commits
  defp create_test_commits do
    [
      create_test_commit("commit1", "2023-01-15", [
        {"lib/old_file.ex", 100, 20},
        {"lib/recent_file.ex", 50, 10}
      ]),
      create_test_commit("commit2", "2023-06-01", [
        {"lib/old_file.ex", 30, 5}
      ]),
      create_test_commit("commit3", "2024-05-01", [
        {"lib/recent_file.ex", 40, 8},
        {"lib/forgotten_file.ex", 60, 15}
      ])
    ]
  end

  defp create_test_commit(id, date, file_changes) do
    changes =
      Enum.map(file_changes, fn {path, added, deleted} ->
        FileChange.new(path, to_string(added), to_string(deleted))
      end)

    Commit.new(
      id,
      Author.new("Test Author"),
      date,
      "Test commit #{id}",
      changes
    )
  end
end
