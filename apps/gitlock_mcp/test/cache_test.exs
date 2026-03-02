defmodule GitlockMCP.CacheTest do
  use ExUnit.Case, async: false

  alias GitlockMCP.Cache

  describe "Cache on a real git repo" do
    test "indexes the current repo and answers queries" do
      # Use the Gitlock repo itself
      repo_path = Path.expand("../../../", __DIR__)

      # Should be a git repo
      assert File.dir?(Path.join(repo_path, ".git"))

      # Index it
      assert :ok = Cache.ensure_indexed(repo_path)

      # Hotspots should return data
      assert {:ok, %{hotspots: hotspots}} = Cache.hotspots(%{limit: 5})
      assert length(hotspots) > 0
      assert hd(hotspots).risk_score > 0

      # Assess a file that likely exists
      first_hotspot = hd(hotspots)
      assert {:ok, assessment} = Cache.assess_file(first_hotspot.file)
      assert assessment.risk_score > 0

      # Repo summary should work
      assert {:ok, summary} = Cache.repo_summary()
      assert summary.total_commits > 0
      assert summary.total_files > 0
    end

    test "returns data for unknown file without crashing" do
      repo_path = Path.expand("../../../", __DIR__)
      :ok = Cache.ensure_indexed(repo_path)

      assert {:ok, assessment} = Cache.assess_file("nonexistent/file.ex")
      assert assessment.risk_score == 0
      assert assessment.risk_level == "low"
    end
  end
end
