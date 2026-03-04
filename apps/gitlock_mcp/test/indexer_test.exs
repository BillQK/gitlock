defmodule GitlockMCP.IndexerTest do
  use ExUnit.Case, async: false

  alias GitlockMCP.Indexer

  @repo_path Path.expand("../../../", __DIR__)

  describe "index/1" do
    test "successfully indexes the current repo" do
      assert {:ok, data} = Indexer.index(@repo_path)

      assert is_list(data.commits)
      assert length(data.commits) > 0

      assert is_list(data.hotspots)
      assert length(data.hotspots) > 0

      assert is_list(data.couplings)
      assert is_list(data.knowledge_silos)
      assert is_map(data.complexity_map)
      assert is_list(data.code_age)
      assert is_list(data.summary)
    end

    test "returns error for nonexistent path" do
      assert {:error, _} = Indexer.index("/tmp/nonexistent_repo_#{:rand.uniform(999_999)}")
    end

    test "summary is a list of statistics" do
      {:ok, data} = Indexer.index(@repo_path)

      assert is_list(data.summary)
      assert length(data.summary) > 0

      Enum.each(data.summary, fn stat ->
        assert Map.has_key?(stat, :statistic) or Map.has_key?(stat, "statistic")
        assert Map.has_key?(stat, :value) or Map.has_key?(stat, "value")
      end)
    end

    test "hotspots include expected fields" do
      {:ok, data} = Indexer.index(@repo_path)

      [h | _] = data.hotspots
      assert Map.has_key?(h, :entity)
      assert Map.has_key?(h, :revisions)
      assert Map.has_key?(h, :risk_score)
      assert Map.has_key?(h, :risk_factor)
      assert Map.has_key?(h, :complexity)
      assert Map.has_key?(h, :loc)
    end

    test "knowledge silos include author info" do
      {:ok, data} = Indexer.index(@repo_path)

      if length(data.knowledge_silos) > 0 do
        [silo | _] = data.knowledge_silos
        assert Map.has_key?(silo, :entity)
        assert Map.has_key?(silo, :main_author)
        assert Map.has_key?(silo, :ownership_ratio)
        assert Map.has_key?(silo, :risk_level)
        assert Map.has_key?(silo, :num_authors)
        assert Map.has_key?(silo, :num_commits)
      end
    end

    test "couplings include entity pairs and degree" do
      {:ok, data} = Indexer.index(@repo_path)

      if length(data.couplings) > 0 do
        [c | _] = data.couplings
        assert Map.has_key?(c, :entity)
        assert Map.has_key?(c, :coupled)
        assert Map.has_key?(c, :degree)
        assert Map.has_key?(c, :windows)
      end
    end

    test "complexity_map keys are file paths" do
      {:ok, data} = Indexer.index(@repo_path)

      if map_size(data.complexity_map) > 0 do
        {path, _metrics} = Enum.at(data.complexity_map, 0)
        assert is_binary(path)
        assert String.contains?(path, "/") or String.ends_with?(path, ".ex")
      end
    end


  end
end
