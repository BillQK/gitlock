defmodule GitlockCore.Domain.Values.CombinedRiskTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Domain.Values.CombinedRisk

  describe "new/5" do
    test "creates a new combined risk value object" do
      # Test the constructor
      risk =
        CombinedRisk.new(
          "lib/auth/session.ex",
          "lib/user/profile.ex",
          12.5,
          3.2,
          %{"lib/auth/session.ex" => 5.0, "lib/user/profile.ex" => 2.5}
        )

      assert risk.entity == "lib/auth/session.ex"
      assert risk.coupled == "lib/user/profile.ex"
      assert risk.combined_risk_score == 12.5
      assert risk.trend == 3.2

      assert risk.individual_risks == %{
               "lib/auth/session.ex" => 5.0,
               "lib/user/profile.ex" => 2.5
             }
    end
  end

  describe "risk_category/1" do
    test "determines risk category based on combined score" do
      # Test critical risk (score > 15)
      critical_risk = %CombinedRisk{combined_risk_score: 16.0}
      assert CombinedRisk.risk_category(critical_risk) == :critical

      # Test high risk (score > 8)
      high_risk = %CombinedRisk{combined_risk_score: 10.0}
      assert CombinedRisk.risk_category(high_risk) == :high

      # Test medium risk (score > 4)
      medium_risk = %CombinedRisk{combined_risk_score: 6.0}
      assert CombinedRisk.risk_category(medium_risk) == :medium

      # Test low risk (score <= 4)
      low_risk = %CombinedRisk{combined_risk_score: 3.0}
      assert CombinedRisk.risk_category(low_risk) == :low
    end
  end

  describe "increasing_risk?/1" do
    test "identifies if trend is positive" do
      # Positive trend (increasing risk)
      increasing = %CombinedRisk{trend: 2.5}
      assert CombinedRisk.increasing_risk?(increasing) == true

      # Zero trend (stable risk)
      stable = %CombinedRisk{trend: 0.0}
      assert CombinedRisk.increasing_risk?(stable) == false

      # Negative trend (decreasing risk)
      decreasing = %CombinedRisk{trend: -1.5}
      assert CombinedRisk.increasing_risk?(decreasing) == false
    end
  end

  describe "equal?/2" do
    test "compares combined risk objects" do
      risk1 =
        CombinedRisk.new(
          "file_a.ex",
          "file_b.ex",
          10.0,
          2.0,
          %{"file_a.ex" => 5.0, "file_b.ex" => 2.0}
        )

      # Same values
      risk2 =
        CombinedRisk.new(
          "file_a.ex",
          "file_b.ex",
          10.0,
          2.0,
          %{"file_a.ex" => 5.0, "file_b.ex" => 2.0}
        )

      # Different values
      risk3 =
        CombinedRisk.new(
          "file_a.ex",
          "file_b.ex",
          # Different score
          8.0,
          2.0,
          %{"file_a.ex" => 5.0, "file_b.ex" => 2.0}
        )

      assert CombinedRisk.equal?(risk1, risk2) == true
      assert CombinedRisk.equal?(risk1, risk3) == false
    end
  end

  describe "to_string/1" do
    test "formats combined risk as a string" do
      risk =
        CombinedRisk.new(
          "lib/auth/session.ex",
          "lib/user/profile.ex",
          12.5,
          3.2,
          %{"lib/auth/session.ex" => 5.0, "lib/user/profile.ex" => 2.5}
        )

      result = CombinedRisk.to_string(risk)

      # Verify basic formatting
      assert String.contains?(result, "session.ex & profile.ex")
      assert String.contains?(result, "score=12.5")
      assert String.contains?(result, "trend=+3.2")
      assert String.contains?(result, "category=high")
    end

    test "correctly shows risk category based on score" do
      # Test each risk category
      risk_critical = %CombinedRisk{
        entity: "lib/a.ex",
        coupled: "lib/b.ex",
        combined_risk_score: 16.0
      }

      assert String.contains?(CombinedRisk.to_string(risk_critical), "category=critical")

      risk_high = %CombinedRisk{
        entity: "lib/a.ex",
        coupled: "lib/b.ex",
        combined_risk_score: 10.0
      }

      assert String.contains?(CombinedRisk.to_string(risk_high), "category=high")

      risk_medium = %CombinedRisk{
        entity: "lib/a.ex",
        coupled: "lib/b.ex",
        combined_risk_score: 5.0
      }

      assert String.contains?(CombinedRisk.to_string(risk_medium), "category=medium")

      risk_low = %CombinedRisk{
        entity: "lib/a.ex",
        coupled: "lib/b.ex",
        combined_risk_score: 2.0
      }

      assert String.contains?(CombinedRisk.to_string(risk_low), "category=low")
    end

    test "handles nil values gracefully" do
      # Test with nil entity/coupled
      nil_fields = %CombinedRisk{
        entity: nil,
        coupled: nil,
        combined_risk_score: 5.0,
        trend: 1.0
      }

      result = CombinedRisk.to_string(nil_fields)
      assert String.contains?(result, "unknown & unknown")

      # Test with nil score/trend
      nil_metrics = %CombinedRisk{
        entity: "file_a.ex",
        coupled: "file_b.ex",
        combined_risk_score: nil,
        trend: nil
      }

      result = CombinedRisk.to_string(nil_metrics)
      assert String.contains?(result, "score=0.0")
      assert String.contains?(result, "trend=+0.0")
    end
  end
end
