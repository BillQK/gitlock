defmodule GitlockCore.Adapters.Reporters.StdoutReporterTest do
  use ExUnit.Case, async: false
  import ExUnit.CaptureIO

  alias GitlockCore.Adapters.Reporters.StdoutReporter

  alias GitlockCore.Domain.Values.{
    Hotspot,
    CouplingsMetrics,
    KnowledgeSilo,
    ChangeImpact,
    ComplexityMetrics
  }

  describe "report/2 - basic functionality" do
    test "returns :ok tuple with formatted output" do
      results = [%{entity: "file.ex", value: 42}]

      assert {:ok, output} = StdoutReporter.report(results, %{})
      assert is_binary(output)
      assert String.contains?(output, "file.ex")
      assert String.contains?(output, "42")
    end

    test "handles empty results" do
      assert {:ok, output} = StdoutReporter.report([], %{})
      assert String.contains?(output, "No results found")
    end

    test "handles nil results" do
      assert {:ok, output} = StdoutReporter.report(nil, %{})
      assert String.contains?(output, "No results found")
    end

    test "applies row limit when specified" do
      results = [
        %{entity: "file1.ex", value: 1},
        %{entity: "file2.ex", value: 2},
        %{entity: "file3.ex", value: 3}
      ]

      {:ok, output} = StdoutReporter.report(results, %{rows: 2})

      assert String.contains?(output, "file1.ex")
      assert String.contains?(output, "file2.ex")
      refute String.contains?(output, "file3.ex")
      assert String.contains?(output, "Showing 2 of 3 results")
    end

    test "handles invalid rows option" do
      results = [%{entity: "file.ex", value: 42}]

      assert {:error, error} = StdoutReporter.report(results, %{rows: "invalid"})
      assert String.contains?(error, "rows must be a non-negative integer")
    end

    test "handles non-map options" do
      results = [%{entity: "file.ex", value: 42}]

      assert {:error, error} = StdoutReporter.report(results, "invalid")
      assert String.contains?(error, "Options must be a map")
    end
  end

  describe "report/2 - HotspotMetrics formatting" do
    test "formats hotspot metrics correctly" do
      results = [
        %Hotspot{
          entity: "lib/core/main.ex",
          revisions: 150,
          complexity: 85,
          loc: 1200,
          risk_score: 12.75,
          risk_factor: :high
        },
        %Hotspot{
          entity: "lib/utils/helper.ex",
          revisions: 45,
          complexity: 25,
          loc: 300,
          risk_score: 5.25,
          risk_factor: :medium
        }
      ]

      {:ok, output} = StdoutReporter.report(results, %{})

      # Check header
      assert String.contains?(output, "Hotspot Analysis Results")

      # Check high risk formatting
      assert String.contains?(output, "🔴 HIGH RISK")
      assert String.contains?(output, "lib/core/main.ex")
      assert String.contains?(output, "150 changes")
      assert String.contains?(output, "complexity: 85")
      assert String.contains?(output, "1,200 lines")

      # Check medium risk formatting
      assert String.contains?(output, "🟡 Medium Risk")
      assert String.contains?(output, "lib/utils/helper.ex")

      # Check summary statistics
      assert String.contains?(output, "Summary Statistics")
      assert String.contains?(output, "Files analyzed: 2")
      assert String.contains?(output, "High risk files: 1")
      assert String.contains?(output, "Average complexity: 55.00")
    end

    test "formats single hotspot metric" do
      result = %Hotspot{
        entity: "app.ex",
        revisions: 10,
        complexity: 5,
        loc: 100,
        risk_score: 2.5,
        risk_factor: :low
      }

      {:ok, output} = StdoutReporter.report([result], %{})

      assert String.contains?(output, "🟢 Low Risk")
      assert String.contains?(output, "app.ex")
    end
  end

  describe "report/2 - CouplingsMetrics formatting" do
    test "formats coupling metrics correctly" do
      results = [
        %CouplingsMetrics{
          entity: "lib/api/controller.ex",
          coupled: "lib/api/view.ex",
          degree: 85.5,
          windows: 45,
          trend: 2.5
        },
        %CouplingsMetrics{
          entity: "lib/data/repo.ex",
          coupled: "lib/data/schema.ex",
          degree: 65.0,
          windows: 30,
          trend: -1.2
        }
      ]

      {:ok, output} = StdoutReporter.report(results, %{})

      # Check header
      assert String.contains?(output, "Couplings Analysis Results")

      # Check first coupling
      assert String.contains?(output, "lib/api/controller.ex ⟷ lib/api/view.ex")
      assert String.contains?(output, "85.5% coupling")
      assert String.contains?(output, "45 changes together")
      assert String.contains?(output, "📈 Increasing")

      # Check second coupling
      assert String.contains?(output, "lib/data/repo.ex ⟷ lib/data/schema.ex")
      assert String.contains?(output, "65.0% coupling")
      assert String.contains?(output, "📉 Decreasing")

      # Check insights
      assert String.contains?(output, "Couplings Insights")
      assert String.contains?(output, "Strong couplings (>75%): 1")
    end

    test "handles stable coupling trend" do
      result = %CouplingsMetrics{
        entity: "file1.ex",
        coupled: "file2.ex",
        degree: 50.0,
        windows: 20,
        trend: 0.0
      }

      {:ok, output} = StdoutReporter.report([result], %{})
      assert String.contains?(output, "→ Stable")
    end
  end

  describe "report/2 - KnowledgeSilo formatting" do
    test "formats knowledge silo metrics correctly" do
      results = [
        %KnowledgeSilo{
          entity: "lib/complex/algorithm.ex",
          main_author: "Alice Developer",
          ownership_ratio: 92.5,
          num_authors: 3,
          num_commits: 120,
          risk_level: :high
        },
        %KnowledgeSilo{
          entity: "lib/shared/utils.ex",
          main_author: "Bob Coder",
          ownership_ratio: 65.0,
          num_authors: 8,
          num_commits: 50,
          risk_level: :medium
        }
      ]

      {:ok, output} = StdoutReporter.report(results, %{})

      # Check header
      assert String.contains?(output, "Knowledge Silo Analysis Results")

      # Check high risk silo
      assert String.contains?(output, "⚠️  HIGH RISK SILO")
      assert String.contains?(output, "lib/complex/algorithm.ex")
      assert String.contains?(output, "Owner: Alice Developer (92.5% ownership)")
      assert String.contains?(output, "Only 3 contributors")

      # Check medium risk silo
      assert String.contains?(output, "🟡 Medium Risk Silo")
      assert String.contains?(output, "lib/shared/utils.ex")
      assert String.contains?(output, "Owner: Bob Coder (65.0% ownership)")

      # Check summary
      assert String.contains?(output, "Knowledge Distribution Summary")
      assert String.contains?(output, "High risk silos: 1")
    end

    test "formats low risk knowledge silo" do
      result = %KnowledgeSilo{
        entity: "shared.ex",
        main_author: "Team",
        ownership_ratio: 35.0,
        num_authors: 15,
        num_commits: 200,
        risk_level: :low
      }

      {:ok, output} = StdoutReporter.report([result], %{})
      assert String.contains?(output, "✓ Low Risk")
    end
  end

  describe "report/2 - ChangeImpact formatting" do
    test "formats change impact metrics correctly" do
      results = [
        %ChangeImpact{
          entity: "lib/core/engine.ex",
          risk_score: 95.5,
          impact_severity: :high,
          affected_files: [
            %{file: "lib/core/processor.ex", impact: 0.95, distance: 1, component: "core"},
            %{file: "lib/core/validator.ex", impact: 0.87, distance: 1, component: "core"},
            %{file: "lib/api/handler.ex", impact: 0.72, distance: 2, component: "api"}
          ],
          affected_components: %{
            "core" => 0.91,
            "api" => 0.72
          },
          suggested_reviewers: ["Alice", "Bob", "Charlie"],
          risk_factors: ["High complexity", "Cross-component impact"]
        }
      ]

      {:ok, output} = StdoutReporter.report(results, %{})

      # Check header
      assert String.contains?(output, "Change Impact Analysis Results")

      # Check critical impact
      assert String.contains?(output, "🚨 CRITICAL IMPACT")
      assert String.contains?(output, "lib/core/engine.ex")
      assert String.contains?(output, "Risk Score: 95.50")
      assert String.contains?(output, "3 files affected")
      assert String.contains?(output, "2 components")

      # Check suggested reviewers
      assert String.contains?(output, "Suggested Reviewers: Alice, Bob, Charlie")

      # Check blast radius
      assert String.contains?(output, "Blast Radius")
      assert String.contains?(output, "lib/core/processor.ex (impact: 0.95)")
    end

    test "handles missing optional fields in change impact" do
      result = %ChangeImpact{
        entity: "simple.ex",
        risk_score: 25.0,
        impact_severity: :low,
        affected_files: [],
        affected_components: %{},
        suggested_reviewers: [],
        risk_factors: []
      }

      {:ok, output} = StdoutReporter.report([result], %{})

      assert String.contains?(output, "🟢 Low Impact")
      refute String.contains?(output, "Suggested Reviewers:")
      refute String.contains?(output, "Blast Radius:")
      refute String.contains?(output, "File Metrics:")
    end
  end

  describe "report/2 - Summary formatting" do
    test "formats summary statistics correctly" do
      results = [
        %{statistic: "total-commits", value: 1234},
        %{statistic: "total-authors", value: 42},
        %{statistic: "total-entities", value: 567},
        %{statistic: "active-days", value: 365}
      ]

      {:ok, output} = StdoutReporter.report(results, %{})

      assert String.contains?(output, "Repository Summary")
      assert String.contains?(output, "Total commits: 1,234")
      assert String.contains?(output, "Total authors: 42")
      assert String.contains?(output, "Total entities: 567")
      assert String.contains?(output, "Active days: 365")
    end
  end

  describe "report/2 - Generic map formatting" do
    test "formats generic maps as a table" do
      results = [
        %{name: "Feature A", status: "completed", progress: 100},
        %{name: "Feature B", status: "in_progress", progress: 75},
        %{name: "Feature C", status: "planned", progress: 0}
      ]

      {:ok, output} = StdoutReporter.report(results, %{})

      # Should format as a table
      assert String.contains?(output, "Analysis Results")
      assert String.contains?(output, "Name")
      assert String.contains?(output, "Status")
      assert String.contains?(output, "Progress")
      assert String.contains?(output, "Feature A")
      assert String.contains?(output, "completed")
      assert String.contains?(output, "100")
    end

    test "handles maps with varying keys" do
      results = [
        %{a: 1, b: 2},
        %{a: 3, c: 4},
        %{b: 5, c: 6, d: 7}
      ]

      {:ok, output} = StdoutReporter.report(results, %{})

      # Should handle all unique keys
      assert String.contains?(output, "A")
      assert String.contains?(output, "B")
      assert String.contains?(output, "C")
      assert String.contains?(output, "D")
    end
  end

  describe "report/2 - mixed types" do
    test "handles mixed result types gracefully" do
      results = [
        %Hotspot{
          entity: "hotspot.ex",
          revisions: 100,
          complexity: 50,
          loc: 500,
          risk_score: 10.0,
          risk_factor: :high
        },
        %{entity: "generic.ex", value: 42}
      ]

      # Should handle the first type it encounters
      assert {:ok, output} = StdoutReporter.report(results, %{})
      assert String.contains?(output, "Hotspot Analysis Results")
    end
  end

  describe "output capture" do
    test "actually writes to stdout when called directly" do
      results = [%{test: "value"}]

      output =
        capture_io(fn ->
          {:ok, _} = StdoutReporter.report(results, %{})
        end)

      # By default, the function returns the formatted output but doesn't print
      # The actual printing would be handled by the caller
      assert output == ""
    end
  end

  describe "edge cases" do
    test "handles special characters in values" do
      results = [
        %{entity: "file.ex", description: "Contains \"quotes\" and 'apostrophes'"},
        %{entity: "other.ex", description: "Has\nnewlines\tand\ttabs"}
      ]

      assert {:ok, output} = StdoutReporter.report(results, %{})
      assert is_binary(output)
    end

    test "handles nil values in results" do
      results = [
        %{entity: "file.ex", value: nil, status: "unknown"},
        %{entity: "other.ex", value: 42, status: nil}
      ]

      assert {:ok, output} = StdoutReporter.report(results, %{})
      assert String.contains?(output, "file.ex")
      assert String.contains?(output, "other.ex")
    end

    test "handles float formatting" do
      results = [
        %{entity: "file.ex", score: 3.14159, percentage: 99.9999}
      ]

      {:ok, output} = StdoutReporter.report(results, %{})

      # Should format floats reasonably
      assert String.contains?(output, "3.14")
      assert String.contains?(output, "100.00") || String.contains?(output, "99.99")
    end
  end
end
