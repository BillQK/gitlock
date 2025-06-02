defmodule GitlockHolmesCore.Domain.Values.ChangeImpactTest do
  use ExUnit.Case, async: true

  alias GitlockHolmesCore.Domain.Values.ChangeImpact

  describe "new/6" do
    test "creates a change impact value object with all fields" do
      affected_files = [
        %{file: "lib/auth/token.ex", impact: 0.8, distance: 1, component: "auth"},
        %{file: "lib/user/profile.ex", impact: 0.5, distance: 2, component: "user"}
      ]

      affected_components = %{"auth" => 0.8, "user" => 0.5}
      reviewers = ["Alice", "Bob"]
      risk_factors = ["High complexity", "Cross-component impact"]

      impact =
        ChangeImpact.new(
          "lib/auth/session.ex",
          7.5,
          affected_files,
          affected_components,
          reviewers,
          risk_factors
        )

      assert impact.entity == "lib/auth/session.ex"
      assert impact.risk_score == 7.5
      # 7.5 >= 7.0
      assert impact.impact_severity == :high
      assert impact.affected_files == affected_files
      assert impact.affected_components == affected_components
      assert impact.suggested_reviewers == reviewers
      assert impact.risk_factors == risk_factors
    end
  end

  describe "calculate_severity/1" do
    test "classifies high risk (>= 7.0)" do
      assert ChangeImpact.calculate_severity(7.0) == :high
      assert ChangeImpact.calculate_severity(8.5) == :high
      assert ChangeImpact.calculate_severity(10.0) == :high
    end

    test "classifies medium risk (>= 4.0 and < 7.0)" do
      assert ChangeImpact.calculate_severity(4.0) == :medium
      assert ChangeImpact.calculate_severity(6.9) == :medium
      assert ChangeImpact.calculate_severity(5.5) == :medium
    end

    test "classifies low risk (< 4.0)" do
      assert ChangeImpact.calculate_severity(0.0) == :low
      assert ChangeImpact.calculate_severity(3.9) == :low
      assert ChangeImpact.calculate_severity(2.5) == :low
    end
  end

  describe "most_impacted_files/2" do
    test "returns the most impacted files, sorted by impact" do
      affected_files = [
        %{file: "file_c.ex", impact: 0.3, distance: 2, component: "x"},
        %{file: "file_a.ex", impact: 0.8, distance: 1, component: "y"},
        %{file: "file_b.ex", impact: 0.5, distance: 1, component: "z"}
      ]

      impact = %ChangeImpact{affected_files: affected_files}

      # Get top 2 files
      result = ChangeImpact.most_impacted_files(impact, 2)

      # Should be sorted by impact (descending)
      assert length(result) == 2
      assert Enum.at(result, 0).file == "file_a.ex"
      assert Enum.at(result, 1).file == "file_b.ex"
    end

    test "handles limit larger than available files" do
      affected_files = [
        %{file: "file_a.ex", impact: 0.8, distance: 1, component: "y"}
      ]

      impact = %ChangeImpact{affected_files: affected_files}

      # Ask for more than available
      result = ChangeImpact.most_impacted_files(impact, 5)

      assert length(result) == 1
      assert Enum.at(result, 0).file == "file_a.ex"
    end

    test "returns empty list when there are no affected files" do
      impact = %ChangeImpact{affected_files: []}
      result = ChangeImpact.most_impacted_files(impact, 3)
      assert result == []
    end
  end

  describe "component_files/2" do
    test "returns files in a specific component" do
      affected_files = [
        %{file: "lib/auth/a.ex", impact: 0.8, distance: 1, component: "auth"},
        %{file: "lib/auth/b.ex", impact: 0.5, distance: 2, component: "auth"},
        %{file: "lib/user/c.ex", impact: 0.4, distance: 1, component: "user"}
      ]

      impact = %ChangeImpact{affected_files: affected_files}

      auth_files = ChangeImpact.component_files(impact, "auth")

      assert length(auth_files) == 2
      assert Enum.all?(auth_files, &(&1.component == "auth"))

      user_files = ChangeImpact.component_files(impact, "user")

      assert length(user_files) == 1
      assert Enum.at(user_files, 0).file == "lib/user/c.ex"
    end

    test "returns empty list when component has no files" do
      affected_files = [
        %{file: "lib/auth/a.ex", impact: 0.8, distance: 1, component: "auth"}
      ]

      impact = %ChangeImpact{affected_files: affected_files}
      result = ChangeImpact.component_files(impact, "non_existent")

      assert result == []
    end
  end

  describe "impacted_components/1" do
    test "returns components sorted by impact level" do
      components = %{
        "auth" => 0.8,
        "user" => 0.5,
        "utils" => 0.3
      }

      impact = %ChangeImpact{affected_components: components}

      result = ChangeImpact.impacted_components(impact)

      # Should be sorted by impact (descending)
      assert result == [{"auth", 0.8}, {"user", 0.5}, {"utils", 0.3}]
    end

    test "handles empty components" do
      impact = %ChangeImpact{affected_components: %{}}
      result = ChangeImpact.impacted_components(impact)

      assert result == []
    end
  end

  describe "to_summary/1" do
    test "generates a human-readable summary" do
      impact = %ChangeImpact{
        entity: "lib/auth/session.ex",
        risk_score: 7.5,
        impact_severity: :high,
        affected_files: [%{}, %{}, %{}],
        affected_components: %{"auth" => 0.8, "user" => 0.4},
        suggested_reviewers: ["Alice", "Bob"]
      }

      summary = ChangeImpact.to_summary(impact)

      # Check content
      assert summary =~ "TARGET FILE: lib/auth/session.ex"
      assert summary =~ "RISK SCORE: 7.5/10"
      assert summary =~ "HIGH RISK"
      assert summary =~ "Blast Radius: 3 files"
      assert summary =~ "2 components"
      assert summary =~ "SUGGESTED REVIEWERS: Alice, Bob"
    end
  end

  describe "to_map/1" do
    test "converts to a plain map" do
      impact =
        ChangeImpact.new(
          "lib/test.ex",
          5.0,
          [%{file: "lib/other.ex", impact: 0.5, distance: 1, component: "test"}],
          %{"test" => 0.5},
          ["Alice"],
          ["Medium complexity"]
        )

      result = ChangeImpact.to_map(impact)

      # Should be a plain map without __struct__
      refute Map.has_key?(result, :__struct__)

      # Should have all the keys
      assert Map.has_key?(result, :entity)
      assert Map.has_key?(result, :risk_score)
      assert Map.has_key?(result, :impact_severity)
      assert Map.has_key?(result, :affected_files)
      assert Map.has_key?(result, :affected_components)
      assert Map.has_key?(result, :suggested_reviewers)
      assert Map.has_key?(result, :risk_factors)
    end
  end

  describe "high_risk?/1" do
    test "returns true for high severity impacts" do
      impact = %ChangeImpact{impact_severity: :high}
      assert ChangeImpact.high_risk?(impact)
    end

    test "returns false for medium severity impacts" do
      impact = %ChangeImpact{impact_severity: :medium}
      refute ChangeImpact.high_risk?(impact)
    end

    test "returns false for low severity impacts" do
      impact = %ChangeImpact{impact_severity: :low}
      refute ChangeImpact.high_risk?(impact)
    end
  end
end
