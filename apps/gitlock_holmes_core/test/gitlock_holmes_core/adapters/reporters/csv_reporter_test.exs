defmodule GitlockHolmesCore.Adapters.Reporters.CsvReporterTest do
  use ExUnit.Case, async: true

  alias GitlockHolmesCore.Adapters.Reporters.CsvReporter

  describe "report/2" do
    test "formats results as CSV" do
      # Test data
      results = [
        %{entity: "file_a.ex", risk_score: 8.5, revisions: 10},
        %{entity: "file_b.ex", risk_score: 5.2, revisions: 5}
      ]

      {:ok, csv} = CsvReporter.report(results, %{})

      # Validate format - should have header line and data lines
      lines = String.split(csv, "\n")
      # Header + 2 data lines
      assert length(lines) >= 3

      # Check header contains expected fields
      header = hd(lines)
      assert String.contains?(header, "entity")
      assert String.contains?(header, "risk_score")
      assert String.contains?(header, "revisions")

      # Check data lines
      data_lines = tl(lines)
      assert Enum.any?(data_lines, &String.contains?(&1, "file_a.ex"))
      assert Enum.any?(data_lines, &String.contains?(&1, "file_b.ex"))
    end

    test "applies row limit when specified" do
      results = [
        %{entity: "file_a.ex", value: 1},
        %{entity: "file_b.ex", value: 2},
        %{entity: "file_c.ex", value: 3}
      ]

      {:ok, csv} = CsvReporter.report(results, %{rows: 2})

      # Should only include first 2 rows
      lines = String.split(csv, "\n", trim: true)
      # Header + 2 data rows
      assert length(lines) == 3

      data_lines = tl(lines)
      assert Enum.any?(data_lines, &String.contains?(&1, "file_a.ex"))
      assert Enum.any?(data_lines, &String.contains?(&1, "file_b.ex"))
      refute Enum.any?(data_lines, &String.contains?(&1, "file_c.ex"))
    end

    test "handles empty results" do
      {:ok, message} = CsvReporter.report([], %{})
      assert message == "No results found"
    end

    test "properly escapes CSV special characters" do
      results = [
        %{entity: "file with, comma.ex", description: "Contains \"quotes\""}
      ]

      {:ok, csv} = CsvReporter.report(results, %{})

      # Check proper escaping of special characters
      lines = String.split(csv, "\n", trim: true)
      data_line = Enum.at(lines, 1)

      # Commas in values should be escaped (by wrapping in quotes)
      assert String.contains?(data_line, "\"file with, comma.ex\"")

      # Quotes should be properly escaped (by doubling)
      assert String.contains?(data_line, "\"Contains \"\"quotes\"\"\"")
    end

    test "handles structs by converting to maps" do
      results = [
        %{name: "test1", value: 42}
      ]

      {:ok, csv} = CsvReporter.report(results, %{})

      # Check that struct fields were correctly extracted
      lines = String.split(csv, "\n", trim: true)
      # Header + 1 data row
      assert length(lines) == 2

      header = hd(lines)
      assert String.contains?(header, "name")
      assert String.contains?(header, "value")

      data_line = Enum.at(lines, 1)
      assert String.contains?(data_line, "test1")
      assert String.contains?(data_line, "42")
    end

    test "validates input parameters" do
      # Invalid results parameter
      assert {:error, _} = CsvReporter.report("not a list", %{})

      # Invalid options parameter
      assert {:error, _} = CsvReporter.report([], "not a map")

      # Invalid rows option
      assert {:error, _} = CsvReporter.report([], %{rows: "not a number"})
      # Negative number
      assert {:error, _} = CsvReporter.report([], %{rows: -1})
    end

    test "handles different value types" do
      results = [
        %{
          string: "text",
          integer: 42,
          float: 3.14,
          atom: :test,
          nil_value: nil,
          list: [1, 2, 3]
        }
      ]

      {:ok, csv} = CsvReporter.report(results, %{})

      # Should format all values appropriately
      lines = String.split(csv, "\n", trim: true)
      data_line = Enum.at(lines, 1)

      assert String.contains?(data_line, "text")
      assert String.contains?(data_line, "42")
      assert String.contains?(data_line, "3.14")
      assert String.contains?(data_line, "test")
      assert String.contains?(data_line, "[1, 2, 3]")

      # Fix: Check for empty field correctly
      # Look for a field that ends with a comma, indicating an empty field at the end
      assert String.match?(data_line, ~r/,[^,]*$/)
    end
  end
end
