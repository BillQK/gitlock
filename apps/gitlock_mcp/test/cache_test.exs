defmodule GitlockMCP.CacheTest do
  use ExUnit.Case, async: false

  alias GitlockMCP.Cache

  # All cache tests use the Gitlock repo itself as the test subject.
  # This is intentional — dogfooding the analysis tool on its own codebase.

  setup_all do
    repo_path = Path.expand("../../../", __DIR__)
    git_path = Path.join(repo_path, ".git")

    assert File.exists?(git_path),
           "Test must run inside a git repo (no .git at #{repo_path})"

    :ok = Cache.ensure_indexed(repo_path)
    %{repo_path: repo_path}
  end

  # ── ensure_indexed ───────────────────────────────────────────

  describe "ensure_indexed/1" do
    test "indexes the current repo successfully", %{repo_path: repo_path} do
      assert :ok = Cache.ensure_indexed(repo_path)
    end

    test "re-indexing with same path returns :ok without re-running" do
      assert :ok = Cache.ensure_indexed()
    end

    test "returns error for invalid repo path" do
      assert {:error, _reason} = Cache.ensure_indexed("/nonexistent/path/to/repo")
    end
  end

  # ── repo_summary ─────────────────────────────────────────────

  describe "repo_summary/0" do
    test "returns summary with expected keys" do
      assert {:ok, summary} = Cache.repo_summary()

      assert is_integer(summary.total_commits)
      assert summary.total_commits > 0
      assert is_integer(summary.total_files)
      assert summary.total_files > 0
      assert is_map(summary.hotspot_count)
      assert is_integer(summary.knowledge_silos)
      assert is_integer(summary.high_coupling_pairs)
      assert is_list(summary.riskiest_areas)
      assert is_binary(summary.summary)
    end

    test "riskiest areas have expected shape" do
      {:ok, summary} = Cache.repo_summary()

      Enum.each(summary.riskiest_areas, fn area ->
        assert is_binary(area.directory)
        assert is_number(area.avg_risk)
        assert is_integer(area.hotspot_files)
      end)
    end
  end

  # ── hotspots ─────────────────────────────────────────────────

  describe "hotspots/1" do
    test "returns hotspots with default limit" do
      assert {:ok, %{hotspots: hotspots, summary: summary}} = Cache.hotspots()

      assert is_list(hotspots)
      assert length(hotspots) <= 10
      assert is_binary(summary)
    end

    test "respects limit option" do
      assert {:ok, %{hotspots: hotspots}} = Cache.hotspots(%{limit: 3})
      assert length(hotspots) <= 3
    end

    test "hotspot entries have expected shape" do
      {:ok, %{hotspots: [h | _]}} = Cache.hotspots(%{limit: 1})

      assert is_binary(h.file)
      assert is_number(h.risk_score)
      assert is_binary(h.risk_level)
      assert is_integer(h.revisions)
      assert is_number(h.complexity)
      assert is_integer(h.loc)
    end

    test "filters by directory" do
      {:ok, %{hotspots: hotspots}} = Cache.hotspots(%{directory: "apps/gitlock_mcp"})

      Enum.each(hotspots, fn h ->
        assert String.starts_with?(h.file, "apps/gitlock_mcp")
      end)
    end

    test "returns empty list for nonexistent directory" do
      {:ok, %{hotspots: hotspots}} = Cache.hotspots(%{directory: "nonexistent/dir"})
      assert hotspots == []
    end

    test "summary reflects directory filter" do
      {:ok, %{summary: summary}} = Cache.hotspots(%{directory: "apps/gitlock_core"})
      assert summary =~ "apps/gitlock_core"
    end

    test "accepts string keys for options" do
      assert {:ok, %{hotspots: hotspots}} = Cache.hotspots(%{"limit" => 2})
      assert length(hotspots) <= 2
    end
  end

  # ── assess_file ──────────────────────────────────────────────

  describe "assess_file/1" do
    test "returns assessment for a known file" do
      {:ok, %{hotspots: [h | _]}} = Cache.hotspots(%{limit: 1})
      {:ok, assessment} = Cache.assess_file(h.file)

      assert assessment.file == h.file
      assert is_integer(assessment.risk_score)
      assert assessment.risk_level in ["low", "medium", "high", "critical"]
      assert is_integer(assessment.revisions)
      assert is_number(assessment.complexity)
      assert is_integer(assessment.loc)
      assert is_binary(assessment.recommendation)
      assert is_list(assessment.coupled_files)
    end

    test "returns zero-risk assessment for unknown file" do
      {:ok, assessment} = Cache.assess_file("does/not/exist.ex")

      assert assessment.file == "does/not/exist.ex"
      assert assessment.risk_score == 0
      assert assessment.risk_level == "low"
      assert assessment.revisions == 0
      assert assessment.complexity == 0
      assert assessment.loc == 0
    end

    test "ownership is nil for unknown file" do
      {:ok, assessment} = Cache.assess_file("does/not/exist.ex")
      assert is_nil(assessment.ownership)
    end

    test "risk_level maps correctly to risk_score" do
      {:ok, %{hotspots: hotspots}} = Cache.hotspots()

      Enum.each(hotspots, fn h ->
        {:ok, a} = Cache.assess_file(h.file)

        expected_level =
          cond do
            a.risk_score > 70 -> "critical"
            a.risk_score > 40 -> "high"
            a.risk_score > 20 -> "medium"
            true -> "low"
          end

        assert a.risk_level == expected_level,
               "#{a.file}: score #{a.risk_score} should be #{expected_level}, got #{a.risk_level}"
      end)
    end
  end

  # ── file_ownership ───────────────────────────────────────────

  describe "file_ownership/1" do
    test "returns ownership data for a known file" do
      {:ok, %{hotspots: [h | _]}} = Cache.hotspots(%{limit: 1})
      {:ok, ownership} = Cache.file_ownership(h.file)

      assert ownership.file == h.file
      assert is_binary(ownership.main_author)
      assert is_number(ownership.ownership_pct)
      assert is_integer(ownership.total_authors)
      assert is_integer(ownership.total_commits)
      assert is_binary(ownership.risk_level)
      assert is_binary(ownership.recommendation)
    end

    test "returns no_data status for unknown file" do
      {:ok, ownership} = Cache.file_ownership("nonexistent/unknown.ex")

      assert ownership.status == "no_data"
      assert is_binary(ownership.message)
    end
  end

  # ── find_coupling ────────────────────────────────────────────

  describe "find_coupling/2" do
    test "returns coupling data with recommendation" do
      {:ok, %{hotspots: [h | _]}} = Cache.hotspots(%{limit: 1})
      {:ok, result} = Cache.find_coupling(h.file)

      assert result.file == h.file
      assert is_list(result.coupled_files)
      assert is_binary(result.recommendation)
    end

    test "returns empty coupled_files for isolated file" do
      {:ok, result} = Cache.find_coupling("nonexistent/isolated.ex")

      assert result.coupled_files == []
      assert result.recommendation =~ "No strong temporal coupling"
    end

    test "respects min_coupling threshold" do
      {:ok, %{hotspots: [h | _]}} = Cache.hotspots(%{limit: 1})

      {:ok, high_threshold} = Cache.find_coupling(h.file, 99)
      {:ok, low_threshold} = Cache.find_coupling(h.file, 1)

      assert length(high_threshold.coupled_files) <= length(low_threshold.coupled_files)
    end
  end

  # ── review_pr ────────────────────────────────────────────────

  describe "review_pr/1" do
    test "returns PR review for known files" do
      {:ok, %{hotspots: hotspots}} = Cache.hotspots(%{limit: 3})
      files = Enum.map(hotspots, & &1.file)

      {:ok, review} = Cache.review_pr(files)

      assert review.overall_risk in ["low", "medium", "high", "critical"]
      assert is_list(review.file_assessments)
      assert length(review.file_assessments) == length(files)
      assert is_list(review.missing_coupled_files)
      assert is_list(review.suggested_reviewers)
      assert is_binary(review.recommendation)
    end

    test "file assessments have expected shape" do
      {:ok, %{hotspots: [h | _]}} = Cache.hotspots(%{limit: 1})
      {:ok, review} = Cache.review_pr([h.file])

      [assessment | _] = review.file_assessments

      assert assessment.file == h.file
      assert is_integer(assessment.risk_score)
      assert is_binary(assessment.risk_level)
    end

    test "returns low risk for unknown files" do
      {:ok, review} = Cache.review_pr(["nonexistent/a.ex", "nonexistent/b.ex"])

      assert review.overall_risk == "low"

      Enum.each(review.file_assessments, fn a ->
        assert a.risk_score == 0
      end)
    end

    test "handles empty file list" do
      {:ok, review} = Cache.review_pr([])

      assert review.overall_risk == "low"
      assert review.file_assessments == []
      assert review.missing_coupled_files == []
      assert review.suggested_reviewers == []
    end

    test "handles single file PR" do
      {:ok, %{hotspots: [h | _]}} = Cache.hotspots(%{limit: 1})
      {:ok, review} = Cache.review_pr([h.file])

      assert length(review.file_assessments) == 1
    end

    test "suggested reviewers are strings" do
      {:ok, %{hotspots: hotspots}} = Cache.hotspots(%{limit: 5})
      files = Enum.map(hotspots, & &1.file)
      {:ok, review} = Cache.review_pr(files)

      Enum.each(review.suggested_reviewers, fn reviewer ->
        assert is_binary(reviewer)
      end)
    end
  end
end
