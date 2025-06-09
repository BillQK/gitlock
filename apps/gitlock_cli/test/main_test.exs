defmodule GitlockCLI.MainTest do
  # Make sure this is synchronous since it captures IO
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias GitlockCLI.Main

  describe "main/1" do
    test "displays help when --help is provided" do
      output =
        capture_io(fn ->
          Main.main(["--help"])
        end)

      assert output =~ "Gitlock - Forensic Code Analysis Tool"
      assert output =~ "Available Investigations:"
    end

    test "displays version when --version is provided" do
      output =
        capture_io(fn ->
          Main.main(["--version"])
        end)

      assert output =~ "Gitlock version"
    end

    test "displays error for invalid options" do
      output =
        capture_io(:stderr, fn ->
          assert catch_exit(Main.main(["--unknown-flag"])) == 1
        end)

      assert output =~ "Error: Invalid option(s): --unknown-flag"
    end

    test "displays error when no investigation type is provided" do
      output =
        capture_io(:stderr, fn ->
          assert catch_exit(Main.main([])) == 1
        end)

      assert output =~ "Error: Missing investigation type"
    end

    test "displays error for unknown investigation type" do
      output =
        capture_io(:stderr, fn ->
          assert catch_exit(Main.main(["unknown_investigation"])) == 1
        end)

      assert output =~ "Unknown investigation type: unknown_investigation"
    end

    test "runs hotspots investigation" do
      # Mock the core to avoid actual analysis
      output =
        capture_io(fn ->
          Main.main(["hotspots", "--dir", "/src"])
        end)

      assert output =~ "entity,revisions,complexity,loc,risk_score,risk_factor"
      assert output =~ "src/core/main.ex"
    end

    test "runs couplings investigation" do
      output =
        capture_io(fn ->
          Main.main(["couplings"])
        end)

      assert output =~ "entity,coupled,degree,windows,trend"
      assert output =~ "src/main.ex,lib/core.ex"
    end

    test "runs knowledge_silos investigation" do
      output =
        capture_io(fn ->
          Main.main(["knowledge_silos"])
        end)

      assert output =~ "entity,main_author,ownership_ratio,num_authors,num_commits,risk_level"
      assert output =~ "src/legacy/old_system.ex"
    end

    test "runs blast_radius investigation" do
      output =
        capture_io(fn ->
          Main.main(["blast_radius", "--target-files", "src/main.ex", "--dir", "/src"])
        end)

      assert output =~ "entity,impact_level,impact_reason"
      assert output =~ "src/main.ex"
    end

    test "runs summary investigation" do
      output =
        capture_io(fn ->
          Main.main(["summary"])
        end)

      assert output =~ "statistic,value"
      assert output =~ "number-of-commits"
    end

    test "handles investigation errors" do
      # Test with a case that will generate an error
      output =
        capture_io(:stderr, fn ->
          assert catch_exit(Main.main(["hotspots"])) == 1
        end)

      assert output =~ "Validation error: Directory option (--dir) is required"
    end

    test "supports output to file" do
      {:ok, temp_file} =
        Briefly.create(prefix: "gitlock_test_#{System.unique_integer([:positive])}")

      output =
        capture_io(fn ->
          Main.main(["couplings", "--output", temp_file])
        end)

      assert output =~ "Writing output to #{temp_file}"
      assert File.exists?(temp_file)

      file_content = File.read!(temp_file)
      assert file_content =~ "entity,coupled,degree,windows,trend"
    end

    test "supports different output formats" do
      # Test JSON format
      output =
        capture_io(fn ->
          Main.main(["summary", "--format", "json"])
        end)

      # Since JSON formatting is a placeholder
      assert output =~ "statistic,value"
    end
  end
end
