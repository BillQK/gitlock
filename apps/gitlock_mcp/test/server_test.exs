defmodule GitlockMCP.ServerTest do
  use ExUnit.Case, async: false

  # Tests that the Cache produces data shapes compatible with the Server's
  # formatters. Since the formatters are private, we verify the contract
  # by checking that Cache output has all required keys.

  setup_all do
    repo_path = Path.expand("../../../", __DIR__)
    :ok = GitlockMCP.Cache.ensure_indexed(repo_path)
    :ok
  end

  # ── repo_summary formatter contract ──────────────────────────

  describe "repo_summary formatter contract" do
    test "result has all keys needed by format_summary/1" do
      {:ok, r} = GitlockMCP.Cache.repo_summary()

      assert is_map(r.hotspot_count)
      assert is_list(r.riskiest_areas)
      assert is_binary(r.summary)
      assert is_integer(r.total_files)
      assert is_integer(r.total_commits)
      assert is_integer(r.knowledge_silos)
      assert is_integer(r.high_coupling_pairs)
    end

    test "hotspot_count values are integers" do
      {:ok, r} = GitlockMCP.Cache.repo_summary()

      Enum.each(r.hotspot_count, fn {key, count} ->
        assert is_binary(key), "hotspot_count key should be string, got: #{inspect(key)}"
        assert is_integer(count), "hotspot_count value should be integer, got: #{inspect(count)}"
      end)
    end

    test "riskiest_areas entries have directory, avg_risk, hotspot_files" do
      {:ok, r} = GitlockMCP.Cache.repo_summary()

      Enum.each(r.riskiest_areas, fn area ->
        assert is_binary(area.directory)
        assert is_number(area.avg_risk)
        assert is_integer(area.hotspot_files)
      end)
    end
  end

  # ── assess_file formatter contract ───────────────────────────

  describe "assess_file formatter contract" do
    test "result has all keys needed by format_assess_file/1" do
      {:ok, %{hotspots: [h | _]}} = GitlockMCP.Cache.hotspots(%{limit: 1})
      {:ok, a} = GitlockMCP.Cache.assess_file(h.file)

      assert is_binary(a.file)
      assert is_binary(a.risk_level)
      assert is_integer(a.risk_score)
      assert is_integer(a.revisions)
      assert is_number(a.complexity)
      assert is_integer(a.loc)
      assert is_list(a.coupled_files)
      assert is_binary(a.recommendation)
      # ownership can be nil or a map
      assert is_nil(a.ownership) or is_map(a.ownership)
    end

    test "ownership map has expected keys when present" do
      {:ok, %{hotspots: [h | _]}} = GitlockMCP.Cache.hotspots(%{limit: 1})
      {:ok, a} = GitlockMCP.Cache.assess_file(h.file)

      if a.ownership do
        assert is_binary(a.ownership.main_author)
        assert is_number(a.ownership.ownership_pct)
        assert is_integer(a.ownership.total_authors)
        assert is_binary(a.ownership.silo_risk)
      end
    end

    test "coupled_files entries have file, coupling_pct, co_changes" do
      {:ok, %{hotspots: hotspots}} = GitlockMCP.Cache.hotspots()

      # Find a file with couplings if any exist
      file_with_coupling =
        Enum.find(hotspots, fn h ->
          {:ok, a} = GitlockMCP.Cache.assess_file(h.file)
          length(a.coupled_files) > 0
        end)

      if file_with_coupling do
        {:ok, a} = GitlockMCP.Cache.assess_file(file_with_coupling.file)

        Enum.each(a.coupled_files, fn c ->
          assert is_binary(c.file)
          assert is_number(c.coupling_pct)
          assert is_integer(c.co_changes)
        end)
      end
    end
  end

  # ── hotspots formatter contract ──────────────────────────────

  describe "hotspots formatter contract" do
    test "result has hotspots list and summary string" do
      {:ok, result} = GitlockMCP.Cache.hotspots(%{limit: 3})

      assert is_list(result.hotspots)
      assert is_binary(result.summary)
    end

    test "hotspot entries have all keys needed by format_hotspots/1" do
      {:ok, %{hotspots: [h | _]}} = GitlockMCP.Cache.hotspots(%{limit: 1})

      assert is_binary(h.file)
      assert is_number(h.risk_score)
      assert is_binary(h.risk_level)
      assert is_integer(h.revisions)
      assert is_number(h.complexity)
    end
  end

  # ── ownership formatter contract ─────────────────────────────

  describe "ownership formatter contract" do
    test "known file has all keys needed by format_ownership/1" do
      {:ok, %{hotspots: [h | _]}} = GitlockMCP.Cache.hotspots(%{limit: 1})
      {:ok, r} = GitlockMCP.Cache.file_ownership(h.file)

      assert is_binary(r.file)
      assert is_binary(r.main_author)
      assert is_number(r.ownership_pct)
      assert is_integer(r.total_authors)
      assert is_integer(r.total_commits)
      assert is_binary(r.risk_level)
      assert is_binary(r.recommendation)
    end

    test "unknown file has status and message for no_data branch" do
      {:ok, r} = GitlockMCP.Cache.file_ownership("nonexistent.ex")

      assert r.status == "no_data"
      assert is_binary(r.message)
    end
  end

  # ── coupling formatter contract ──────────────────────────────

  describe "coupling formatter contract" do
    test "result has file, coupled_files, recommendation" do
      {:ok, %{hotspots: [h | _]}} = GitlockMCP.Cache.hotspots(%{limit: 1})
      {:ok, r} = GitlockMCP.Cache.find_coupling(h.file)

      assert is_binary(r.file)
      assert is_list(r.coupled_files)
      assert is_binary(r.recommendation)
    end

    test "empty coupling recommendation mentions 'No strong temporal coupling'" do
      {:ok, r} = GitlockMCP.Cache.find_coupling("nonexistent.ex")
      assert r.recommendation =~ "No strong temporal coupling"
    end
  end

  # ── review_pr formatter contract ─────────────────────────────

  describe "review_pr formatter contract" do
    test "result has all keys needed by format_review/1" do
      {:ok, %{hotspots: hotspots}} = GitlockMCP.Cache.hotspots(%{limit: 2})
      files = Enum.map(hotspots, & &1.file)
      {:ok, r} = GitlockMCP.Cache.review_pr(files)

      assert is_binary(r.overall_risk)
      assert is_list(r.file_assessments)
      assert is_list(r.missing_coupled_files)
      assert is_list(r.suggested_reviewers)
      assert is_binary(r.recommendation)
    end

    test "file_assessments have file, risk_score, risk_level" do
      {:ok, %{hotspots: [h | _]}} = GitlockMCP.Cache.hotspots(%{limit: 1})
      {:ok, r} = GitlockMCP.Cache.review_pr([h.file])

      [a | _] = r.file_assessments
      assert is_binary(a.file)
      assert is_integer(a.risk_score)
      assert is_binary(a.risk_level)
    end

    test "missing_coupled_files entries have file, coupling_pct, coupled_to" do
      {:ok, summary} = GitlockMCP.Cache.repo_summary()

      if summary.high_coupling_pairs > 0 do
        {:ok, %{hotspots: hotspots}} = GitlockMCP.Cache.hotspots()

        coupled_file =
          Enum.find(hotspots, fn h ->
            {:ok, r} = GitlockMCP.Cache.find_coupling(h.file, 30)
            length(r.coupled_files) > 0
          end)

        if coupled_file do
          {:ok, r} = GitlockMCP.Cache.review_pr([coupled_file.file])

          Enum.each(r.missing_coupled_files, fn m ->
            assert is_binary(m.file)
            assert is_number(m.coupling_pct)
            assert is_binary(m.coupled_to)
          end)
        end
      end
    end
  end
end
