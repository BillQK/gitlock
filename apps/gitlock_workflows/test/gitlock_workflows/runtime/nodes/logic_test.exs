defmodule GitlockWorkflows.Runtime.Nodes.LogicTest do
  use ExUnit.Case, async: true

  alias GitlockWorkflows.Runtime.Nodes.Logic.{
    Filter,
    Sort,
    Limit,
    If,
    Switch,
    Merge,
    Aggregate,
    RemoveDuplicates,
    GroupBy
  }

  @hotspots [
    %{entity: "lib/core.ex", revisions: 50, risk_factor: "high", risk_score: 8.5},
    %{entity: "lib/utils.ex", revisions: 10, risk_factor: "low", risk_score: 1.2},
    %{entity: "lib/api.ex", revisions: 30, risk_factor: "medium", risk_score: 5.0},
    %{entity: "lib/db.ex", revisions: 45, risk_factor: "high", risk_score: 7.8},
    %{entity: "lib/auth.ex", revisions: 20, risk_factor: "medium", risk_score: 4.1}
  ]

  # ── Filter ───────────────────────────────────────────────────

  describe "Filter" do
    test "keeps items matching eq condition" do
      {:ok, out} =
        Filter.execute(
          %{items: @hotspots},
          %{"field" => "risk_factor", "operator" => "eq", "value" => "high"},
          %{}
        )

      assert length(out.kept) == 2
      assert length(out.rejected) == 3
      assert Enum.all?(out.kept, &(&1.risk_factor == "high"))
    end

    test "numeric gt comparison" do
      {:ok, out} =
        Filter.execute(
          %{items: @hotspots},
          %{"field" => "revisions", "operator" => "gt", "value" => "25"},
          %{}
        )

      assert length(out.kept) == 3
      assert Enum.all?(out.kept, &(&1.revisions > 25))
    end

    test "contains string matching" do
      {:ok, out} =
        Filter.execute(
          %{items: @hotspots},
          %{"field" => "entity", "operator" => "contains", "value" => "core"},
          %{}
        )

      assert length(out.kept) == 1
      assert hd(out.kept).entity == "lib/core.ex"
    end

    test "empty field returns error" do
      assert {:error, _} =
               Filter.execute(
                 %{items: @hotspots},
                 %{"field" => "", "operator" => "eq", "value" => "x"},
                 %{}
               )
    end
  end

  # ── Sort ─────────────────────────────────────────────────────

  describe "Sort" do
    test "sorts ascending by numeric field" do
      {:ok, out} =
        Sort.execute(%{items: @hotspots}, %{"field" => "revisions", "direction" => "asc"}, %{})

      revisions = Enum.map(out.items, & &1.revisions)
      assert revisions == Enum.sort(revisions)
    end

    test "sorts descending" do
      {:ok, out} =
        Sort.execute(%{items: @hotspots}, %{"field" => "risk_score", "direction" => "desc"}, %{})

      scores = Enum.map(out.items, & &1.risk_score)
      assert scores == Enum.sort(scores, :desc)
    end
  end

  # ── Limit ────────────────────────────────────────────────────

  describe "Limit" do
    test "takes first N items" do
      {:ok, out} = Limit.execute(%{items: @hotspots}, %{"count" => 2, "from" => "start"}, %{})
      assert length(out.items) == 2
      assert out.items == Enum.take(@hotspots, 2)
    end

    test "takes last N items" do
      {:ok, out} = Limit.execute(%{items: @hotspots}, %{"count" => 2, "from" => "end"}, %{})
      assert length(out.items) == 2
      assert out.items == Enum.take(@hotspots, -2)
    end

    test "handles count larger than list" do
      {:ok, out} = Limit.execute(%{items: @hotspots}, %{"count" => 100}, %{})
      assert length(out.items) == 5
    end
  end

  # ── IF ───────────────────────────────────────────────────────

  describe "IF" do
    test "splits items into true/false branches" do
      {:ok, out} =
        If.execute(
          %{items: @hotspots},
          %{"field" => "risk_factor", "operator" => "eq", "value" => "high"},
          %{}
        )

      assert length(out.true) == 2
      assert length(out.false) == 3
    end

    test "numeric gte condition" do
      {:ok, out} =
        If.execute(
          %{items: @hotspots},
          %{"field" => "revisions", "operator" => "gte", "value" => "30"},
          %{}
        )

      assert length(out.true) == 3
      assert Enum.all?(out.true, &(&1.revisions >= 30))
    end

    test "is_empty check" do
      items = [%{name: "a", value: nil}, %{name: "b", value: "x"}, %{name: "c", value: ""}]

      {:ok, out} =
        If.execute(%{items: items}, %{"field" => "value", "operator" => "is_empty"}, %{})

      assert length(out.true) == 2
      assert length(out.false) == 1
    end
  end

  # ── Switch ───────────────────────────────────────────────────

  describe "Switch" do
    test "routes items to named cases" do
      {:ok, out} =
        Switch.execute(
          %{items: @hotspots},
          %{"field" => "risk_factor", "cases" => "high,medium,low"},
          %{}
        )

      # high
      assert length(out.case_0) == 2
      # medium
      assert length(out.case_1) == 2
      # low
      assert length(out.case_2) == 1
      assert out.default == []
    end

    test "unmatched items go to default" do
      {:ok, out} =
        Switch.execute(
          %{items: @hotspots},
          %{"field" => "risk_factor", "cases" => "critical"},
          %{}
        )

      assert out.case_0 == []
      assert length(out.default) == 5
    end
  end

  # ── Merge ────────────────────────────────────────────────────

  describe "Merge" do
    test "appends two lists" do
      a = [%{n: 1}, %{n: 2}]
      b = [%{n: 3}, %{n: 4}]
      {:ok, out} = Merge.execute(%{items_a: a, items_b: b}, %{"mode" => "append"}, %{})
      assert length(out.items) == 4
      assert Enum.map(out.items, & &1.n) == [1, 2, 3, 4]
    end

    test "interleaves two lists" do
      a = [%{n: 1}, %{n: 2}]
      b = [%{n: 3}, %{n: 4}]
      {:ok, out} = Merge.execute(%{items_a: a, items_b: b}, %{"mode" => "interleave"}, %{})
      assert Enum.map(out.items, & &1.n) == [1, 3, 2, 4]
    end

    test "handles nil items_b" do
      {:ok, out} = Merge.execute(%{items_a: [%{n: 1}]}, %{"mode" => "append"}, %{})
      assert length(out.items) == 1
    end
  end

  # ── Aggregate ────────────────────────────────────────────────

  describe "Aggregate" do
    test "computes count" do
      {:ok, out} = Aggregate.execute(%{items: @hotspots}, %{"operations" => "count"}, %{})
      assert out.result["count"] == 5
    end

    test "computes sum and avg" do
      {:ok, out} =
        Aggregate.execute(
          %{items: @hotspots},
          %{"operations" => "sum:revisions,avg:revisions"},
          %{}
        )

      assert out.result["sum_revisions"] == 155
      assert_in_delta out.result["avg_revisions"], 31.0, 0.01
    end

    test "computes min and max" do
      {:ok, out} =
        Aggregate.execute(
          %{items: @hotspots},
          %{"operations" => "min:risk_score,max:risk_score"},
          %{}
        )

      assert out.result["min_risk_score"] == 1.2
      assert out.result["max_risk_score"] == 8.5
    end

    test "multiple operations in one call" do
      {:ok, out} =
        Aggregate.execute(
          %{items: @hotspots},
          %{"operations" => "count,sum:revisions,max:risk_score"},
          %{}
        )

      assert out.result["count"] == 5
      assert out.result["sum_revisions"] == 155
      assert out.result["max_risk_score"] == 8.5
    end
  end

  # ── Remove Duplicates ───────────────────────────────────────

  describe "RemoveDuplicates" do
    test "removes duplicates by field" do
      items = [
        %{entity: "a.ex", author: "alice"},
        %{entity: "b.ex", author: "bob"},
        %{entity: "c.ex", author: "alice"},
        %{entity: "d.ex", author: "alice"}
      ]

      {:ok, out} = RemoveDuplicates.execute(%{items: items}, %{"field" => "author"}, %{})
      assert length(out.items) == 2
      authors = Enum.map(out.items, & &1.author)
      assert "alice" in authors
      assert "bob" in authors
    end
  end

  # ── Group By ─────────────────────────────────────────────────

  describe "GroupBy" do
    test "groups items by field" do
      {:ok, out} = GroupBy.execute(%{items: @hotspots}, %{"field" => "risk_factor"}, %{})

      assert map_size(out.groups) == 3
      assert length(out.groups["high"]) == 2
      assert length(out.groups["medium"]) == 2
      assert length(out.groups["low"]) == 1
    end

    test "outputs sorted summaries" do
      {:ok, out} = GroupBy.execute(%{items: @hotspots}, %{"field" => "risk_factor"}, %{})

      assert length(out.items) == 3
      [first | _] = out.items
      assert Map.has_key?(first, :group)
      assert Map.has_key?(first, :count)
    end
  end

  # ── Catalog integration ──────────────────────────────────────

  describe "NodeCatalog integration" do
    test "all logic nodes are in the catalog" do
      logic = GitlockWorkflows.NodeCatalog.by_category(:logic)
      type_ids = Enum.map(logic, & &1.type_id) |> MapSet.new()

      for expected <-
            ~w(filter sort limit if_condition switch merge aggregate remove_duplicates group_by)a do
        assert MapSet.member?(type_ids, expected), "Missing logic node: #{expected}"
      end
    end

    test "all logic nodes have runtime modules" do
      for type_def <- GitlockWorkflows.NodeCatalog.by_category(:logic) do
        assert type_def.runtime_module != nil, "#{type_def.type_id} missing runtime_module"
      end
    end

    test "serializer catalog includes Logic category" do
      catalog = GitlockWorkflows.Serializer.catalog_to_list()
      categories = Enum.map(catalog, & &1.name)
      assert "Logic" in categories
    end
  end
end
