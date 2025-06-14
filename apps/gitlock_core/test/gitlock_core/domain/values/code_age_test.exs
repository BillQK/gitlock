defmodule GitlockCore.Domain.Values.CodeAgeTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Domain.Values.CodeAge

  describe "new/3" do
    test "creates a new CodeAge with valid string entity, float age, and risk" do
      code_age = CodeAge.new("src/user.ex", 8.5, :high)

      assert %CodeAge{entity: "src/user.ex", age_months: 8.5, risk: :high} = code_age
      assert code_age.entity == "src/user.ex"
      assert code_age.age_months == 8.5
      assert code_age.risk == :high
    end

    test "creates a new CodeAge with integer age" do
      code_age = CodeAge.new("lib/auth.ex", 12, :high)

      assert %CodeAge{entity: "lib/auth.ex", age_months: 12, risk: :high} = code_age
      assert code_age.age_months == 12
      assert code_age.risk == :high
    end

    test "creates a new CodeAge with zero age and low risk" do
      code_age = CodeAge.new("src/new_file.ex", 0, :low)

      assert %CodeAge{entity: "src/new_file.ex", age_months: 0, risk: :low} = code_age
      assert code_age.age_months == 0
      assert code_age.risk == :low
    end

    test "creates a new CodeAge with float zero age" do
      code_age = CodeAge.new("src/another_file.ex", 0.0, :low)

      assert %CodeAge{entity: "src/another_file.ex", age_months: +0.0, risk: :low} = code_age
      assert code_age.age_months == +0.0
      assert code_age.risk == :low
    end

    test "creates a new CodeAge with complex file path" do
      complex_path = "src/deeply/nested/path/with-dashes_and_underscores.ex"
      code_age = CodeAge.new(complex_path, 15.7, :high)

      assert code_age.entity == complex_path
      assert code_age.age_months == 15.7
      assert code_age.risk == :high
    end

    test "accepts all valid risk atoms" do
      # Test all risk levels
      low_risk = CodeAge.new("src/low.ex", 2.0, :low)
      assert low_risk.risk == :low

      medium_risk = CodeAge.new("src/medium.ex", 24.0, :medium)
      assert medium_risk.risk == :medium

      high_risk = CodeAge.new("src/high.ex", 8.5, :high)
      assert high_risk.risk == :high
    end

    test "accepts any atom as risk" do
      # The guard only checks is_atom, so any atom should work
      custom_risk = CodeAge.new("src/custom.ex", 5.0, :custom_risk)
      assert custom_risk.risk == :custom_risk

      another_custom = CodeAge.new("src/other.ex", 10.0, :danger)
      assert another_custom.risk == :danger
    end

    test "raises FunctionClauseError with non-string entity" do
      assert_raise FunctionClauseError, fn ->
        CodeAge.new(:invalid_entity, 8.5, :high)
      end

      assert_raise FunctionClauseError, fn ->
        CodeAge.new(123, 8.5, :high)
      end

      assert_raise FunctionClauseError, fn ->
        CodeAge.new(nil, 8.5, :high)
      end
    end

    test "raises FunctionClauseError with negative age" do
      assert_raise FunctionClauseError, fn ->
        CodeAge.new("src/user.ex", -1.0, :low)
      end

      assert_raise FunctionClauseError, fn ->
        CodeAge.new("src/user.ex", -0.1, :low)
      end
    end

    test "raises FunctionClauseError with non-numeric age" do
      assert_raise FunctionClauseError, fn ->
        CodeAge.new("src/user.ex", "8.5", :high)
      end

      assert_raise FunctionClauseError, fn ->
        CodeAge.new("src/user.ex", :invalid, :high)
      end

      assert_raise FunctionClauseError, fn ->
        CodeAge.new("src/user.ex", nil, :high)
      end
    end

    test "raises FunctionClauseError with non-atom risk" do
      assert_raise FunctionClauseError, fn ->
        CodeAge.new("src/user.ex", 8.5, "high")
      end

      assert_raise FunctionClauseError, fn ->
        CodeAge.new("src/user.ex", 8.5, 123)
      end

      assert_raise FunctionClauseError, fn ->
        CodeAge.new("src/user.ex", 8.5, %{risk: :high})
      end
    end
  end

  describe "calculate_risk/1" do
    test "returns :low for fresh files (0-3 months)" do
      assert CodeAge.calculate_risk(0.0) == :low
      assert CodeAge.calculate_risk(1.5) == :low
      assert CodeAge.calculate_risk(2.9) == :low
      assert CodeAge.calculate_risk(3.0) == :low
    end

    test "returns :high for danger zone files (3-18 months)" do
      assert CodeAge.calculate_risk(3.1) == :high
      assert CodeAge.calculate_risk(8.5) == :high
      assert CodeAge.calculate_risk(12.0) == :high
      assert CodeAge.calculate_risk(17.9) == :high
      assert CodeAge.calculate_risk(18.0) == :high
    end

    test "returns :medium for forgotten files (18-36 months)" do
      assert CodeAge.calculate_risk(18.1) == :medium
      assert CodeAge.calculate_risk(24.0) == :medium
      assert CodeAge.calculate_risk(30.5) == :medium
      assert CodeAge.calculate_risk(35.9) == :medium
      assert CodeAge.calculate_risk(36.0) == :medium
    end

    test "returns :low for stable files (36+ months)" do
      assert CodeAge.calculate_risk(36.1) == :low
      assert CodeAge.calculate_risk(48.0) == :low
      assert CodeAge.calculate_risk(100.0) == :low
      assert CodeAge.calculate_risk(999.9) == :low
    end

    test "handles integer inputs" do
      assert CodeAge.calculate_risk(2) == :low
      assert CodeAge.calculate_risk(8) == :high
      assert CodeAge.calculate_risk(24) == :medium
      assert CodeAge.calculate_risk(48) == :low
    end

    test "handles boundary values precisely" do
      # Test exact boundary values
      assert CodeAge.calculate_risk(3.0) == :low
      assert CodeAge.calculate_risk(3.0000001) == :high

      assert CodeAge.calculate_risk(18.0) == :high
      assert CodeAge.calculate_risk(18.0000001) == :medium

      assert CodeAge.calculate_risk(36.0) == :medium
      assert CodeAge.calculate_risk(36.0000001) == :low
    end

    test "raises FunctionClauseError with negative age" do
      assert_raise FunctionClauseError, fn ->
        CodeAge.calculate_risk(-1.0)
      end

      assert_raise FunctionClauseError, fn ->
        CodeAge.calculate_risk(-0.1)
      end
    end

    test "raises FunctionClauseError with non-numeric age" do
      assert_raise FunctionClauseError, fn ->
        CodeAge.calculate_risk("8.5")
      end

      assert_raise FunctionClauseError, fn ->
        CodeAge.calculate_risk(:invalid)
      end

      assert_raise FunctionClauseError, fn ->
        CodeAge.calculate_risk(nil)
      end
    end
  end

  describe "calculate_age_months/1" do
    test "calculates age in months for past dates" do
      # Test with a date that's clearly in the past
      past_date = ~D[2023-01-15]

      age_months = CodeAge.calculate_age_months(past_date)

      # Should return a positive number
      assert age_months > 0
      assert is_float(age_months)

      # Should be using 30.44 days per month calculation
      today = Date.utc_today()
      expected_days = Date.diff(today, past_date)
      expected_months = expected_days / 30.44

      assert_in_delta age_months, expected_months, 0.01
    end

    test "returns 0 for today's date" do
      today = Date.utc_today()
      age_months = CodeAge.calculate_age_months(today)
      assert age_months == +0.0
    end

    test "uses precise 30.44 days per month calculation" do
      # Test that it uses 30.44, not 30 or other values
      past_date = ~D[2023-01-01]

      age_months = CodeAge.calculate_age_months(past_date)

      today = Date.utc_today()
      expected_days = Date.diff(today, past_date)

      # Verify it uses 30.44 divisor
      expected_with_30_44 = expected_days / 30.44
      expected_with_30 = expected_days / 30.0

      assert_in_delta age_months, expected_with_30_44, 0.01
      # Should be different from using 30 days per month
      refute_in_delta age_months, expected_with_30, 0.1
    end

    test "handles very old dates" do
      # Test with a date from several years ago
      old_date = ~D[2020-06-15]

      age_months = CodeAge.calculate_age_months(old_date)

      # Should be well over 36 months (3 years)
      assert age_months > 36.0
      assert is_float(age_months)
    end

    test "handles recent dates" do
      # Test with a date from a few days ago
      today = Date.utc_today()
      # 10 days ago
      recent_date = Date.add(today, -10)

      age_months = CodeAge.calculate_age_months(recent_date)

      # Should be less than 1 month
      assert age_months < 1.0
      assert age_months > 0

      # Should be approximately 10/30.44
      expected_months = 10 / 30.44
      assert_in_delta age_months, expected_months, 0.01
    end

    test "calculation matches Date.diff / 30.44 formula" do
      test_dates = [
        ~D[2023-01-01],
        ~D[2023-06-15],
        ~D[2024-01-01],
        ~D[2024-03-15]
      ]

      today = Date.utc_today()

      Enum.each(test_dates, fn date ->
        age_months = CodeAge.calculate_age_months(date)
        expected_days = Date.diff(today, date)
        expected_months = expected_days / 30.44

        assert_in_delta age_months, expected_months, 0.01
      end)
    end
  end

  describe "integration with risk calculation" do
    test "full workflow from date to risk assessment" do
      today = Date.utc_today()

      # Test fresh file (recent)
      # ~2 months ago
      fresh_date = Date.add(today, -60)
      age = CodeAge.calculate_age_months(fresh_date)
      risk = CodeAge.calculate_risk(age)
      code_age = CodeAge.new("src/fresh.ex", age, risk)

      assert code_age.risk == :low
      assert code_age.age_months < 3.0

      # Test danger zone file (old enough to be risky)
      # ~10 months ago  
      danger_date = Date.add(today, -300)
      age = CodeAge.calculate_age_months(danger_date)
      risk = CodeAge.calculate_risk(age)
      code_age = CodeAge.new("src/risky.ex", age, risk)

      assert code_age.risk == :high
      assert code_age.age_months > 3.0
      assert code_age.age_months < 18.0

      # Test forgotten file (very old)
      # ~23 months ago
      forgotten_date = Date.add(today, -700)
      age = CodeAge.calculate_age_months(forgotten_date)
      risk = CodeAge.calculate_risk(age)
      code_age = CodeAge.new("src/forgotten.ex", age, risk)

      assert code_age.risk == :medium
      assert code_age.age_months > 18.0
      assert code_age.age_months < 36.0

      # Test stable file (ancient)
      # ~46 months ago
      stable_date = Date.add(today, -1400)
      age = CodeAge.calculate_age_months(stable_date)
      risk = CodeAge.calculate_risk(age)
      code_age = CodeAge.new("src/stable.ex", age, risk)

      assert code_age.risk == :low
      assert code_age.age_months > 36.0
    end

    test "demonstrates typical Git workflow scenarios" do
      # Simulate common Git scenarios
      today = Date.utc_today()

      # Just committed today
      fresh_commit = today
      age = CodeAge.calculate_age_months(fresh_commit)
      risk = CodeAge.calculate_risk(age)
      code_age = CodeAge.new("src/just_committed.ex", age, risk)
      assert code_age.risk == :low
      assert code_age.age_months == +0.0

      # Feature branch merged last week
      last_week = Date.add(today, -7)
      age = CodeAge.calculate_age_months(last_week)
      risk = CodeAge.calculate_risk(age)
      code_age = CodeAge.new("src/feature_branch.ex", age, risk)
      assert code_age.risk == :low
      assert code_age.age_months < 1.0

      # Legacy code from years ago
      # ~33 months ago
      legacy_date = Date.add(today, -1000)
      age = CodeAge.calculate_age_months(legacy_date)
      risk = CodeAge.calculate_risk(age)
      code_age = CodeAge.new("src/legacy.ex", age, risk)
      assert code_age.risk == :medium
      assert code_age.age_months > 18.0
      assert code_age.age_months < 36.0
    end

    test "risk parameter matches calculate_risk result" do
      # Test that the risk passed to new/3 should match calculate_risk result
      test_cases = [
        {2.0, :low},
        {8.5, :high},
        {24.0, :medium},
        {48.0, :low}
      ]

      Enum.each(test_cases, fn {age_months, expected_risk} ->
        calculated_risk = CodeAge.calculate_risk(age_months)
        code_age = CodeAge.new("src/test.ex", age_months, calculated_risk)

        assert code_age.risk == expected_risk
        assert code_age.risk == calculated_risk
      end)
    end

    test "allows manual risk override" do
      # Sometimes you might want to override the calculated risk
      # The new/3 function doesn't enforce that risk matches calculate_risk
      # Would normally be :low
      age_months = 2.0
      # But we can override it
      manual_risk = :high

      code_age = CodeAge.new("src/override.ex", age_months, manual_risk)

      assert code_age.risk == :high
      assert code_age.age_months == 2.0
      # Show that calculate_risk would return different value
      assert CodeAge.calculate_risk(age_months) == :low
    end
  end
end
