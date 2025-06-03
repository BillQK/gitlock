defmodule GitlockCore.Domain.Values.KnowledgeSiloTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Domain.Values.KnowledgeSilo

  describe "new/6" do
    test "creates a knowledge silo value object with all fields" do
      silo =
        KnowledgeSilo.new(
          "lib/auth/session.ex",
          "Alice",
          85.5,
          2,
          10,
          :high
        )

      assert silo.entity == "lib/auth/session.ex"
      assert silo.main_author == "Alice"
      assert silo.ownership_ratio == 85.5
      assert silo.num_authors == 2
      assert silo.num_commits == 10
      assert silo.risk_level == :high
    end
  end

  describe "high_risk?/1" do
    test "returns true for high risk silos" do
      silo = KnowledgeSilo.new("test.ex", "Alice", 90.0, 1, 20, :high)
      assert KnowledgeSilo.high_risk?(silo)
    end

    test "returns false for medium risk silos" do
      silo = KnowledgeSilo.new("test.ex", "Alice", 75.0, 2, 8, :medium)
      refute KnowledgeSilo.high_risk?(silo)
    end

    test "returns false for low risk silos" do
      silo = KnowledgeSilo.new("test.ex", "Alice", 60.0, 3, 5, :low)
      refute KnowledgeSilo.high_risk?(silo)
    end
  end

  describe "ownership_percentage/1" do
    test "formats ownership ratio as a percentage string" do
      silo = KnowledgeSilo.new("test.ex", "Alice", 85.5, 2, 10, :high)
      assert KnowledgeSilo.ownership_percentage(silo) == "85.5%"
    end

    test "handles integer values" do
      silo = KnowledgeSilo.new("test.ex", "Alice", 100, 1, 10, :high)
      assert KnowledgeSilo.ownership_percentage(silo) == "100%"
    end

    test "handles zero values" do
      silo = KnowledgeSilo.new("test.ex", "Alice", 0, 10, 10, :low)
      assert KnowledgeSilo.ownership_percentage(silo) == "0%"
    end
  end

  describe "to_string/1" do
    test "formats high risk silos" do
      silo = KnowledgeSilo.new("lib/auth/session.ex", "Alice", 95.0, 1, 20, :high)
      result = KnowledgeSilo.to_string(silo)
      assert result =~ "session.ex"
      assert result =~ "95.0%"
      assert result =~ "Alice"
      assert result =~ "HIGH RISK"
    end

    test "formats medium risk silos" do
      silo = KnowledgeSilo.new("lib/user/profile.ex", "Bob", 75.0, 2, 8, :medium)
      result = KnowledgeSilo.to_string(silo)
      assert result =~ "profile.ex"
      assert result =~ "75.0%"
      assert result =~ "Bob"
      assert result =~ "Medium risk"
    end

    test "formats low risk silos" do
      silo = KnowledgeSilo.new("lib/util/helper.ex", "Carol", 50.0, 4, 4, :low)
      result = KnowledgeSilo.to_string(silo)
      assert result =~ "helper.ex"
      assert result =~ "50.0%"
      assert result =~ "Carol"
      assert result =~ "Low risk"
    end

    test "works with paths containing special characters" do
      silo = KnowledgeSilo.new("lib/auth/special+chars file.ex", "Alice", 80.0, 2, 10, :high)
      result = KnowledgeSilo.to_string(silo)
      assert result =~ "special+chars file.ex"
    end
  end
end
