defmodule GitlockCore.Domain.Values.ComplexityMetricsTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Domain.Values.ComplexityMetrics

  describe "new/4" do
    test "creates a new complexity metrics value object" do
      metrics = ComplexityMetrics.new("lib/test.ex", 100, 15, :elixir)

      assert metrics.file_path == "lib/test.ex"
      assert metrics.loc == 100
      assert metrics.cyclomatic_complexity == 15
      assert metrics.language == :elixir
    end
  end

  describe "complexity_density/1" do
    test "calculates complexity per line of code" do
      # Test the normal case (loc > 0)
      metrics = ComplexityMetrics.new("lib/test.ex", 100, 25, :elixir)
      assert ComplexityMetrics.complexity_density(metrics) == 0.25

      # Test higher density
      metrics = ComplexityMetrics.new("lib/complex.ex", 10, 50, :elixir)
      assert ComplexityMetrics.complexity_density(metrics) == 5.0

      # Test exact edge case: loc = 0
      metrics = ComplexityMetrics.new("lib/empty.ex", 0, 10, :elixir)
      assert ComplexityMetrics.complexity_density(metrics) == 0.0

      # Test with nil loc
      metrics = %ComplexityMetrics{
        file_path: "lib/nil.ex",
        loc: nil,
        cyclomatic_complexity: 10,
        language: :elixir
      }

      assert ComplexityMetrics.complexity_density(metrics) == 0.0
    end
  end

  describe "risk_category/1" do
    test "identifies high risk code (cc > 30)" do
      metrics = ComplexityMetrics.new("lib/high_risk.ex", 200, 31, :elixir)
      assert ComplexityMetrics.risk_category(metrics) == :high
    end

    test "identifies medium risk code (15 < cc <= 30)" do
      metrics = ComplexityMetrics.new("lib/medium_risk.ex", 150, 16, :elixir)
      assert ComplexityMetrics.risk_category(metrics) == :medium
    end

    test "identifies low risk code (cc <= 15)" do
      metrics = ComplexityMetrics.new("lib/low_risk.ex", 100, 15, :elixir)
      assert ComplexityMetrics.risk_category(metrics) == :low
    end

    test "boundary conditions" do
      # Exactly at the high threshold
      high = ComplexityMetrics.new("test.ex", 100, 31, :elixir)
      assert ComplexityMetrics.risk_category(high) == :high

      # Just below high threshold
      high_minus = ComplexityMetrics.new("test.ex", 100, 30, :elixir)
      assert ComplexityMetrics.risk_category(high_minus) == :medium

      # Exactly at the medium threshold
      medium = ComplexityMetrics.new("test.ex", 100, 16, :elixir)
      assert ComplexityMetrics.risk_category(medium) == :medium

      # Just below medium threshold
      medium_minus = ComplexityMetrics.new("test.ex", 100, 15, :elixir)
      assert ComplexityMetrics.risk_category(medium_minus) == :low

      # Zero complexity
      zero = ComplexityMetrics.new("test.ex", 100, 0, :elixir)
      assert ComplexityMetrics.risk_category(zero) == :low
    end
  end

  describe "equal?/2" do
    test "compares complexity metrics by value, not identity" do
      metrics1 = ComplexityMetrics.new("lib/test.ex", 100, 15, :elixir)
      metrics2 = ComplexityMetrics.new("lib/test.ex", 100, 15, :elixir)
      metrics3 = ComplexityMetrics.new("lib/test.ex", 100, 20, :elixir)

      # Same values should be equal
      assert ComplexityMetrics.equal?(metrics1, metrics2)

      # Different values should not be equal
      refute ComplexityMetrics.equal?(metrics1, metrics3)
    end

    test "all fields must match for equality" do
      base = ComplexityMetrics.new("lib/test.ex", 100, 15, :elixir)

      # Different file path
      diff_path = ComplexityMetrics.new("lib/other.ex", 100, 15, :elixir)
      refute ComplexityMetrics.equal?(base, diff_path)

      # Different LOC
      diff_loc = ComplexityMetrics.new("lib/test.ex", 101, 15, :elixir)
      refute ComplexityMetrics.equal?(base, diff_loc)

      # Different complexity
      diff_complexity = ComplexityMetrics.new("lib/test.ex", 100, 16, :elixir)
      refute ComplexityMetrics.equal?(base, diff_complexity)

      # Different language
      diff_lang = ComplexityMetrics.new("lib/test.ex", 100, 15, :javascript)
      refute ComplexityMetrics.equal?(base, diff_lang)

      # Should be equal to itself
      assert ComplexityMetrics.equal?(base, base)
    end
  end

  describe "to_string/1" do
    test "creates a human-readable representation" do
      metrics = ComplexityMetrics.new("lib/module/test_file.ex", 100, 15, :elixir)
      result = ComplexityMetrics.to_string(metrics)

      # Should contain relevant parts
      assert result =~ "test_file.ex"
      assert result =~ "elixir"
      assert result =~ "100 LOC"
      assert result =~ "complexity: 15"
    end

    test "handles different languages" do
      js_metrics = ComplexityMetrics.new("src/component.js", 200, 25, :javascript)
      result = ComplexityMetrics.to_string(js_metrics)

      assert result =~ "component.js"
      assert result =~ "javascript"
    end

    test "handles files with no path" do
      metrics = ComplexityMetrics.new("test.ex", 50, 10, :elixir)
      result = ComplexityMetrics.to_string(metrics)

      assert result =~ "test.ex"
    end

    test "handles unusual file paths" do
      # With spaces and special characters
      metrics = ComplexityMetrics.new("path with spaces/special!file.ex", 80, 12, :elixir)
      result = ComplexityMetrics.to_string(metrics)

      assert result =~ "special!file.ex"
    end
  end
end
