defmodule GitlockHolmesCore.Domain.Values.HotspotTest do
  use ExUnit.Case, async: true

  alias GitlockHolmesCore.Domain.Values.Hotspot

  describe "new/6" do
    test "creates a new hotspot value object" do
      hotspot =
        Hotspot.new(
          "lib/hotspot.ex",
          15,
          25,
          200,
          :high,
          8.5
        )

      assert hotspot.entity == "lib/hotspot.ex"
      assert hotspot.revisions == 15
      assert hotspot.complexity == 25
      assert hotspot.loc == 200
      assert hotspot.risk_factor == :high
      assert hotspot.risk_score == 8.5
    end
  end

  describe "to_map/1" do
    test "converts hotspot to a plain map" do
      hotspot = %Hotspot{
        entity: "lib/test.ex",
        revisions: 10,
        complexity: 15,
        loc: 150,
        risk_factor: :medium,
        risk_score: 5.5
      }

      map = Hotspot.to_map(hotspot)

      assert is_map(map)
      assert map.entity == "lib/test.ex"
      assert map.revisions == 10
      assert map.complexity == 15
      assert map.loc == 150
      assert map.risk_factor == :medium
      assert map.risk_score == 5.5
      refute Map.has_key?(map, :__struct__)
    end
  end

  describe "high_risk?/1" do
    test "returns true for high risk hotspots" do
      hotspot = %Hotspot{risk_factor: :high}
      assert Hotspot.high_risk?(hotspot)
    end

    test "returns false for medium and low risk hotspots" do
      medium = %Hotspot{risk_factor: :medium}
      low = %Hotspot{risk_factor: :low}

      refute Hotspot.high_risk?(medium)
      refute Hotspot.high_risk?(low)
    end
  end

  describe "to_string/1" do
    test "formats hotspot information as a string" do
      hotspot = %Hotspot{
        entity: "lib/complex/file.ex",
        revisions: 10,
        complexity: 15,
        risk_factor: :high,
        risk_score: 7.8
      }

      result = Hotspot.to_string(hotspot)

      assert is_binary(result)
      assert String.contains?(result, "file.ex")
      assert String.contains?(result, "10 revisions")
      assert String.contains?(result, "complexity: 15")
      assert String.contains?(result, "7.8")
      assert String.contains?(result, "HIGH RISK")
    end
  end
end
