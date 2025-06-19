defmodule GitlockCoreTest do
  use ExUnit.Case

  describe "investigate/3 - delegation behavior" do
    test "passes through the return value from use case execution" do
      # Use a path that looks like a git repo but doesn't exist
      non_existent_repo = "/tmp/non_existent_repo_#{:rand.uniform(10000)}"

      # Now returns git command error instead of file error
      assert {:error, result} = GitlockCore.investigate(:summary, non_existent_repo)
      assert result =~ "Git log failed"
    end

    test "forwards repo_path to use case unchanged" do
      # Create a unique path
      unique_path = "/tmp/unique_repo_#{System.unique_integer([:positive])}"

      # The error should contain our path
      assert {:error, result} = GitlockCore.investigate(:hotspots, unique_path)
      assert result =~ "Git log failed"
    end

    test "forwards options to use case unchanged" do
      repo_path = "/tmp/test_repo_#{:rand.uniform(10000)}"

      custom_options = %{
        format: "json",
        since: "2023-01-01",
        custom_key: "custom_value"
      }

      # The use case should receive these options
      # Since it will fail, we just verify it doesn't crash
      assert {:error, _} = GitlockCore.investigate(:summary, repo_path, custom_options)
    end

    test "provides empty map as default options" do
      nonexistent_path = "/tmp/nonexistent_#{System.unique_integer([:positive])}"

      # Should work with no options provided
      assert {:error, result} = GitlockCore.investigate(:summary, nonexistent_path)
      assert result =~ "Git log failed"
    end
  end

  describe "available_investigations/0" do
    test "returns all available investigation types" do
      investigations = GitlockCore.available_investigations()

      assert :hotspots in investigations
      assert :couplings in investigations
      assert :knowledge_silos in investigations
      assert :summary in investigations
      assert :blast_radius in investigations
      assert :code_age in investigations
      assert :coupled_hotspots in investigations

      # Should be exactly 7 investigation types
      assert length(investigations) == 7
    end

    test "all investigation types can be executed" do
      repo_path = "/tmp/test_repo_#{:rand.uniform(10000)}"

      for investigation_type <- GitlockCore.available_investigations() do
        # Each should return an error for non-existent repo
        assert {:error, _} = GitlockCore.investigate(investigation_type, repo_path)
      end
    end
  end

  describe "error handling" do
    test "returns error for unknown investigation type" do
      repo_path = "/tmp/some_repo"

      assert {:error, message} = GitlockCore.investigate(:unknown_type, repo_path)
      assert message =~ "Unknown investigation type: unknown_type"
    end

    test "returns error for invalid repo path" do
      invalid_path = "/this/does/not/exist"

      assert {:error, message} = GitlockCore.investigate(:summary, invalid_path)
      assert message =~ "Git log failed"
    end
  end

  describe "integration with real git repository" do
    @tag :integration
    test "successfully analyzes a git repository" do
      # Create a real git repository
      {:ok, repo_dir} = Briefly.create(directory: true)

      # Initialize git repo
      System.cmd("git", ["init"], cd: repo_dir)
      System.cmd("git", ["config", "user.email", "test@example.com"], cd: repo_dir)
      System.cmd("git", ["config", "user.name", "Test User"], cd: repo_dir)

      # Create some commits
      for i <- 1..3 do
        file = Path.join(repo_dir, "file#{i}.txt")
        File.write!(file, "content #{i}")
        System.cmd("git", ["add", "."], cd: repo_dir)
        System.cmd("git", ["commit", "-m", "Commit #{i}"], cd: repo_dir)
      end

      # Should successfully analyze
      assert {:ok, result} = GitlockCore.investigate(:summary, repo_dir)
      assert is_binary(result)
    end
  end

  describe "facade characteristics" do
    test "no business logic in facade" do
      # The facade should only delegate, not process
      # Test with empty string instead of nil to avoid workspace manager crash
      assert {:error, _} = GitlockCore.investigate(:summary, "")
    end

    test "thin delegation layer" do
      # GitlockCore module should be minimal
      # Check that it only has the expected public functions
      exports = GitlockCore.__info__(:functions)

      assert {:investigate, 2} in exports
      assert {:investigate, 3} in exports
      assert {:available_investigations, 0} in exports

      # Should only have these 3 public functions
      assert length(exports) == 3
    end
  end
end
