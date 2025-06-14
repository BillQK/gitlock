defmodule GitlockCore.Domain.Values.CouplingsMetricsTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Domain.Values.CouplingsMetrics

  describe "new/5" do
    test "creates a new coupling metrics value object" do
      coupling =
        CouplingsMetrics.new(
          "lib/auth/session.ex",
          "lib/auth/token.ex",
          85.7,
          5,
          12.3
        )

      assert coupling.entity == "lib/auth/session.ex"
      assert coupling.coupled == "lib/auth/token.ex"
      assert coupling.degree == 85.7
      assert coupling.windows == 5
      assert coupling.trend == 12.3
    end

    test "handles zero and negative values" do
      # Zero coupling degree
      zero_degree = CouplingsMetrics.new("file1.ex", "file2.ex", 0.0, 1, 0.0)
      assert zero_degree.degree == 0.0
      assert zero_degree.trend == 0.0

      # Negative trend (declining coupling)
      negative_trend = CouplingsMetrics.new("file1.ex", "file2.ex", 50.0, 10, -15.5)
      assert negative_trend.trend == -15.5
    end

    test "handles different file paths" do
      # Test with various file path formats
      paths = [
        {"lib/auth/session.ex", "lib/auth/token.ex"},
        {"src/components/Button.jsx", "src/components/Input.jsx"},
        {"/absolute/path/file.ex", "./relative/path/file.ex"},
        {"file with spaces.ex", "special$chars.ex"}
      ]

      for {path1, path2} <- paths do
        coupling = CouplingsMetrics.new(path1, path2, 75.0, 3, 5.0)
        assert coupling.entity == path1
        assert coupling.coupled == path2
      end
    end

    test "accepts float precision for degree and trend" do
      # Test with various levels of precision
      coupling = CouplingsMetrics.new("file1.ex", "file2.ex", 75.123456, 3, 5.987654)

      # The struct should store the values exactly as provided
      assert coupling.degree == 75.123456
      assert coupling.trend == 5.987654
    end
  end
end
