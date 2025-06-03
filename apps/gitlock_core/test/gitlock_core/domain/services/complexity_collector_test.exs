defmodule GitlockCore.Domain.Services.ComplexityCollectorTest do
  use ExUnit.Case, async: true
  import Mox

  alias GitlockCore.Domain.Services.ComplexityCollector
  alias GitlockCore.Domain.Values.ComplexityMetrics
  alias GitlockCore.Mocks.ComplexityAnalyzerMock

  # Setup for Mox
  setup :verify_on_exit!

  describe "collect_complexity/2" do
    test "collects complexity metrics from analyzer" do
      # Setup test data
      test_dir = "/test/dir"

      test_metrics = %{
        "file_a.ex" => ComplexityMetrics.new("file_a.ex", 100, 10, :elixir),
        "file_b.ex" => ComplexityMetrics.new("file_b.ex", 50, 5, :elixir)
      }

      # Expect analyze_directory/2 call with empty options map
      ComplexityAnalyzerMock
      |> expect(:analyze_directory, fn ^test_dir, %{} -> test_metrics end)

      # Call the function under test
      result = ComplexityCollector.collect_complexity(ComplexityAnalyzerMock, test_dir)

      # Verify results - using cyclomatic_complexity field instead of complexity
      assert result == test_metrics
      assert map_size(result) == 2
      assert result["file_a.ex"].cyclomatic_complexity == 10
      assert result["file_b.ex"].cyclomatic_complexity == 5
    end

    test "handles empty result from analyzer" do
      test_dir = "/empty/dir"

      # Expect analyze_directory/2 call
      ComplexityAnalyzerMock
      |> expect(:analyze_directory, fn ^test_dir, %{} -> %{} end)

      result = ComplexityCollector.collect_complexity(ComplexityAnalyzerMock, test_dir)

      assert result == %{}
    end

    test "handles error result from analyzer" do
      test_dir = "/error/dir"

      # Expect analyze_directory/2 call
      ComplexityAnalyzerMock
      |> expect(:analyze_directory, fn ^test_dir, %{} ->
        {:error, "Invalid directory"}
      end)

      # Should return empty map on error
      result = ComplexityCollector.collect_complexity(ComplexityAnalyzerMock, test_dir)

      assert result == %{}
    end

    test "passes directory path correctly" do
      # Test with various path formats
      paths = [
        "/absolute/path",
        "relative/path",
        "./current/dir",
        "../parent/dir",
        "single_dir"
      ]

      for path <- paths do
        ComplexityAnalyzerMock
        |> expect(:analyze_directory, fn ^path, %{} -> %{} end)

        ComplexityCollector.collect_complexity(ComplexityAnalyzerMock, path)
      end
    end
  end
end
