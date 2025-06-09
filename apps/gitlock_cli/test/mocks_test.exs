defmodule MockGitlockCoreTest do
  use ExUnit.Case, async: true

  describe "available_investigations/0" do
    test "returns list of supported investigation types" do
      investigations = MockGitlockCore.available_investigations()

      assert is_list(investigations)
      assert :hotspots in investigations
      assert :knowledge_silos in investigations
      assert :couplings in investigations
      assert :coupled_hotspots in investigations
      assert :blast_radius in investigations
      assert :summary in investigations
    end
  end

  describe "investigate/3" do
    test "summary investigation always succeeds" do
      {:ok, result} = MockGitlockCore.investigate(:summary, "any_source", %{})

      assert result =~ "statistic,value"
      assert result =~ "number-of-commits,247"
      assert result =~ "number-of-authors,12"
    end

    test "hotspots investigation requires dir option" do
      # With dir option, should succeed
      {:ok, result} = MockGitlockCore.investigate(:hotspots, "any_source", %{dir: "/src"})

      assert result =~ "entity,revisions,complexity,loc,risk_score,risk_factor"
      assert result =~ "src/core/main.ex"

      # Without dir option, should fail
      {:error, {:validation, message}} = MockGitlockCore.investigate(:hotspots, "any_source", %{})
      assert message =~ "Directory option (--dir) is required"
    end

    test "knowledge_silos investigation returns ownership data" do
      {:ok, result} = MockGitlockCore.investigate(:knowledge_silos, "any_source", %{})

      assert result =~ "entity,main_author,ownership_ratio,num_authors,num_commits,risk_level"
      assert result =~ "john.doe,96.4"
    end

    test "couplings investigation returns coupling data" do
      {:ok, result} = MockGitlockCore.investigate(:couplings, "any_source", %{})

      assert result =~ "entity,coupled,degree,windows,trend"
      assert result =~ "src/main.ex,lib/core.ex,92,15,positive"
    end

    test "coupled_hotspots investigation requires dir option" do
      # With dir option, should succeed
      {:ok, result} = MockGitlockCore.investigate(:coupled_hotspots, "any_source", %{dir: "/src"})

      assert result =~ "entity,coupled,combined_risk_score,trend,individual_risks"

      # Without dir option, should fail
      {:error, {:validation, message}} =
        MockGitlockCore.investigate(:coupled_hotspots, "any_source", %{})

      assert message =~ "Directory option (--dir) is required"
    end

    test "blast_radius investigation requires dir and target_files options" do
      # With both options, should succeed
      {:ok, result} =
        MockGitlockCore.investigate(
          :blast_radius,
          "any_source",
          %{dir: "/src", target_files: "main.ex"}
        )

      assert result =~ "entity,impact_level,impact_reason"

      # Without dir option, should fail
      {:error, {:validation, message}} =
        MockGitlockCore.investigate(
          :blast_radius,
          "any_source",
          %{target_files: "main.ex"}
        )

      assert message =~ "Directory option (--dir) is required"

      # Without target_files option, should fail
      {:error, {:validation, message}} =
        MockGitlockCore.investigate(
          :blast_radius,
          "any_source",
          %{dir: "/src"}
        )

      assert message =~ "Target files (--target-files) are required"
    end
  end

  # The read_file tests have been removed as the function is not implemented in MockGitlockCore
end
