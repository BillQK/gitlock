defmodule GitlockCore.Adapters.Reporters.JsonReporterTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Adapters.Reporters.JsonReporter

  describe "report/2" do
    test "formats results as JSON" do
      results = [
        %{entity: "file_a.ex", risk: 8.5, revisions: 10},
        %{entity: "file_b.ex", risk: 5.2, revisions: 5}
      ]

      {:ok, json} = JsonReporter.report(results, %{})

      # Parse back to verify structure
      {:ok, parsed} = Jason.decode(json)

      assert length(parsed) == 2
      assert Enum.at(parsed, 0)["entity"] == "file_a.ex"
      assert Enum.at(parsed, 0)["risk"] == 8.5
      assert Enum.at(parsed, 1)["entity"] == "file_b.ex"
    end

    test "applies row limit when specified" do
      results = [
        %{entity: "file_a.ex", risk: 8.5},
        %{entity: "file_b.ex", risk: 5.2},
        %{entity: "file_c.ex", risk: 3.1}
      ]

      {:ok, json} = JsonReporter.report(results, %{rows: 2})

      {:ok, parsed} = Jason.decode(json)

      # Should only include first 2 rows
      assert length(parsed) == 2
      assert Enum.at(parsed, 0)["entity"] == "file_a.ex"
      assert Enum.at(parsed, 1)["entity"] == "file_b.ex"
    end

    test "handles structs by converting to maps" do
      results = [
        %{name: "test1", value: 42},
        %{name: "test2", value: 99}
      ]

      {:ok, json} = JsonReporter.report(results, %{})

      {:ok, parsed} = Jason.decode(json)

      # Should convert structs to maps
      assert length(parsed) == 2
      assert Enum.at(parsed, 0)["name"] == "test1"
      assert Enum.at(parsed, 0)["value"] == 42
    end

    test "generates pretty-formatted JSON" do
      results = [%{test: "value"}]

      {:ok, json} = JsonReporter.report(results, %{})

      # Should contain newlines and indentation
      assert String.contains?(json, "\n")
      assert String.contains?(json, "  ")
    end
  end
end
