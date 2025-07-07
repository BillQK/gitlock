defmodule GitlockCore.Domain.Services.CodeAgeAnalysisTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias GitlockCore.Domain.Services.CodeAgeAnalysis
  alias GitlockCore.Domain.Values.{CodeAge, FileChange}
  alias GitlockCore.Domain.Entities.{Commit, Author}

  describe "calculate_code_age/1" do
    test "analyzes single commit with single file" do
      commits = [
        build_commit(~D[2024-01-15], [
          build_file_change("src/user.ex")
        ])
      ]

      result = CodeAgeAnalysis.calculate_code_age(commits)

      assert length(result) == 1
      code_age = List.first(result)
      assert code_age.entity == "src/user.ex"
      assert is_float(code_age.age_months)
      assert code_age.age_months > 0
    end

    test "analyzes single commit with multiple files" do
      commits = [
        build_commit(~D[2024-01-15], [
          build_file_change("src/user.ex"),
          build_file_change("src/auth.ex"),
          build_file_change("lib/utils.ex")
        ])
      ]

      result = CodeAgeAnalysis.calculate_code_age(commits)

      assert length(result) == 3
      entities = Enum.map(result, & &1.entity)
      assert "src/user.ex" in entities
      assert "src/auth.ex" in entities
      assert "lib/utils.ex" in entities
    end

    test "handles multiple commits for the same file - uses latest date" do
      commits = [
        build_commit(~D[2024-01-15], [
          build_file_change("src/user.ex")
        ]),
        # More recent
        build_commit(~D[2024-02-01], [
          build_file_change("src/user.ex")
        ]),
        # Middle date
        build_commit(~D[2024-01-20], [
          build_file_change("src/user.ex")
        ])
      ]

      result = CodeAgeAnalysis.calculate_code_age(commits)

      assert length(result) == 1
      code_age = List.first(result)

      # Should use the latest date (2024-02-01)
      expected_age = CodeAge.calculate_age_months(~D[2024-02-01])
      assert code_age.age_months == expected_age
    end

    test "analyzes multiple commits with different files" do
      commits = [
        build_commit(~D[2024-01-15], [
          build_file_change("src/user.ex"),
          build_file_change("src/auth.ex")
        ]),
        build_commit(~D[2024-02-01], [
          build_file_change("lib/utils.ex"),
          build_file_change("test/user_test.exs")
        ]),
        build_commit(~D[2024-01-20], [
          # Update existing file
          build_file_change("src/user.ex")
        ])
      ]

      result = CodeAgeAnalysis.calculate_code_age(commits)

      assert length(result) == 4
      entities = Enum.map(result, & &1.entity) |> Enum.sort()
      expected = ["lib/utils.ex", "src/auth.ex", "src/user.ex", "test/user_test.exs"]
      assert entities == expected

      # Check that src/user.ex uses the later date (2024-01-20, not 2024-01-15)
      user_ex = Enum.find(result, &(&1.entity == "src/user.ex"))
      expected_age = CodeAge.calculate_age_months(~D[2024-01-20])
      assert user_ex.age_months == expected_age
    end

    test "handles empty commits list" do
      result = CodeAgeAnalysis.calculate_code_age([])
      assert result == []
    end

    test "handles commits with no file changes" do
      commits = [
        # No file changes
        build_commit(~D[2024-01-15], [])
      ]

      result = CodeAgeAnalysis.calculate_code_age(commits)
      assert result == []
    end

    test "filters out duplicate file paths within same commit" do
      # Edge case: same file appears twice in one commit
      commits = [
        build_commit(~D[2024-01-15], [
          build_file_change("src/user.ex"),
          # Duplicate
          build_file_change("src/user.ex")
        ])
      ]

      result = CodeAgeAnalysis.calculate_code_age(commits)

      assert length(result) == 1
      assert List.first(result).entity == "src/user.ex"
    end

    test "age calculations are correct" do
      # Use a known date for predictable testing
      test_date = ~D[2024-01-01]

      commits = [
        build_commit(test_date, [
          build_file_change("src/test.ex")
        ])
      ]

      result = CodeAgeAnalysis.calculate_code_age(commits)
      code_age = List.first(result)

      expected_age = CodeAge.calculate_age_months(test_date)
      assert code_age.age_months == expected_age
      assert code_age.risk == :medium
    end

    test "handles files with special characters in names" do
      commits = [
        build_commit(~D[2024-01-15], [
          build_file_change("src/user-service.ex"),
          build_file_change("lib/utils_v2.ex"),
          build_file_change("test/integration test.exs"),
          build_file_change("assets/app.css")
        ])
      ]

      result = CodeAgeAnalysis.calculate_code_age(commits)

      assert length(result) == 4
      entities = Enum.map(result, & &1.entity) |> Enum.sort()

      expected = [
        "assets/app.css",
        "lib/utils_v2.ex",
        "src/user-service.ex",
        "test/integration test.exs"
      ]

      assert entities == expected
    end

    test "handles large number of files" do
      # Test with many files to ensure performance
      file_changes =
        Enum.map(1..100, fn i ->
          build_file_change("src/file_#{i}.ex")
        end)

      commits = [
        build_commit(~D[2024-01-15], file_changes)
      ]

      result = CodeAgeAnalysis.calculate_code_age(commits)

      assert length(result) == 100

      assert Enum.all?(result, fn code_age ->
               String.starts_with?(code_age.entity, "src/file_") and
                 code_age.age_months > 0
             end)
    end

    test "mixed commit and file scenarios" do
      commits = [
        # Initial commit
        build_commit(~D[2024-01-01], [
          build_file_change("README.md"),
          build_file_change("mix.exs")
        ]),
        # Add new features
        build_commit(~D[2024-01-15], [
          build_file_change("src/user.ex"),
          build_file_change("src/auth.ex")
        ]),
        # Update existing + add test
        build_commit(~D[2024-02-01], [
          # Updated
          build_file_change("src/user.ex"),
          # New
          build_file_change("test/user_test.exs")
        ]),
        # Documentation update
        build_commit(~D[2024-02-15], [
          # Updated
          build_file_change("README.md")
        ])
      ]

      result = CodeAgeAnalysis.calculate_code_age(commits)

      assert length(result) == 5

      # Check specific files use correct dates
      readme = Enum.find(result, &(&1.entity == "README.md"))
      user_ex = Enum.find(result, &(&1.entity == "src/user.ex"))
      mix_exs = Enum.find(result, &(&1.entity == "mix.exs"))

      # Latest
      assert readme.age_months == CodeAge.calculate_age_months(~D[2024-02-15])
      # Latest
      assert user_ex.age_months == CodeAge.calculate_age_months(~D[2024-02-01])
      # Only date
      assert mix_exs.age_months == CodeAge.calculate_age_months(~D[2024-01-01])
    end
  end

  describe "property-based tests" do
    property "always returns same number or fewer results than unique files" do
      check all(commits <- list_of(commit_generator(), min_length: 1, max_length: 50)) do
        result = CodeAgeAnalysis.calculate_code_age(commits)

        unique_files =
          commits
          |> Enum.flat_map(& &1.file_changes)
          |> Enum.map(& &1.entity)
          |> Enum.uniq()
          |> length()

        assert length(result) <= unique_files
      end
    end

    property "all returned CodeAge objects have positive or zero age" do
      check all(commits <- list_of(commit_generator(), min_length: 1, max_length: 20)) do
        result = CodeAgeAnalysis.calculate_code_age(commits)

        assert Enum.all?(result, fn code_age ->
                 code_age.age_months >= 0
               end)
      end
    end

    property "entity names are preserved correctly" do
      check all(commits <- list_of(commit_generator(), min_length: 1, max_length: 10)) do
        result = CodeAgeAnalysis.calculate_code_age(commits)

        result_entities = Enum.map(result, & &1.entity) |> MapSet.new()

        expected_entities =
          commits
          |> Enum.flat_map(& &1.file_changes)
          |> Enum.map(& &1.entity)
          |> MapSet.new()

        # All result entities should be in the expected set
        assert MapSet.subset?(result_entities, expected_entities)
      end
    end

    property "uses latest date for files with multiple commits" do
      check all(
              {entity, dates} <-
                {binary(), list_of(date_generator(), min_length: 2, max_length: 5)}
            ) do
        # Create commits with the same entity but different dates
        commits =
          Enum.map(dates, fn date ->
            build_test_commit(date, [build_test_file_change(entity)])
          end)

        result = CodeAgeAnalysis.calculate_code_age(commits)

        assert length(result) == 1
        code_age = List.first(result)

        latest_date = Enum.max(dates, Date)
        expected_age = CodeAge.calculate_age_months(latest_date)

        assert code_age.entity == entity
        assert code_age.age_months == expected_age
      end
    end
  end

  defp commit_generator do
    gen all(
          date <- date_generator(),
          file_changes <- list_of(file_change_generator(), min_length: 0, max_length: 10)
        ) do
      build_test_commit(date, file_changes)
    end
  end

  defp file_change_generator do
    gen all(entity <- binary(min_length: 1, max_length: 50)) do
      build_test_file_change(entity)
    end
  end

  defp date_generator do
    # Generate dates within a reasonable range
    # Up to 3 years ago
    gen all(days_offset <- integer(-1095..0)) do
      Date.add(Date.utc_today(), days_offset)
    end
  end

  defp build_file_change(entity) do
    %FileChange{
      entity: entity,
      loc_added: "10",
      loc_deleted: "5"
    }
  end

  defp build_commit(date, file_changes) do
    %Commit{
      id: "test-#{:rand.uniform(1000)}",
      author: %Author{name: "Test Developer", email: "test@example.com"},
      date: date,
      message: "Test commit",
      file_changes: file_changes
    }
  end

  defp build_test_file_change(entity) do
    %FileChange{
      entity: entity,
      loc_added: "1",
      loc_deleted: "0"
    }
  end

  defp build_test_commit(date, file_changes) do
    %Commit{
      id: "prop-test-#{:rand.uniform(10000)}",
      author: %Author{name: "Property Test", email: "test@prop.com"},
      date: date,
      message: "Property test commit",
      file_changes: file_changes
    }
  end
end
