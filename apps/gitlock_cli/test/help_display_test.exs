defmodule GitlockCLI.HelpDisplayTest do
  # Remove async: true for tests that capture IO
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias GitlockCLI.HelpDisplay

  describe "display_help/1" do
    test "displays general help when no specific command is given" do
      output = capture_io(fn -> HelpDisplay.display_help([]) end)

      # Check for common sections in the general help
      assert output =~ "Gitlock - Forensic Code Analysis Tool"
      assert output =~ "Available Investigations:"
      assert output =~ "Repository Source Options:"
      assert output =~ "--help"
      assert output =~ "--version"
    end

    test "displays help for hotspots investigation" do
      output = capture_io(fn -> HelpDisplay.display_help(["hotspots"]) end)

      assert output =~ "Hotspot Analysis"
      assert output =~ "Identifies frequently changed files with high complexity"
      assert output =~ "Options:"
      assert output =~ "--repo, -r PATH"
    end

    test "displays help for couplings investigation" do
      output = capture_io(fn -> HelpDisplay.display_help(["couplings"]) end)

      assert output =~ "Coupling Analysis"
      assert output =~ "Identifies files that frequently change together"
      assert output =~ "Options:"
    end

    test "displays help for knowledge_silos investigation" do
      output = capture_io(fn -> HelpDisplay.display_help(["knowledge_silos"]) end)

      assert output =~ "Knowledge Silo Analysis"
      assert output =~ "knowledge-silos"
      assert output =~ "Options:"
    end

    test "displays help for coupled_hotspots investigation" do
      output = capture_io(fn -> HelpDisplay.display_help(["coupled_hotspots"]) end)

      assert output =~ "Coupled Hotspots Analysis"
      assert output =~ "coupled-hotspots"
      assert output =~ "Options:"
    end

    test "displays help for blast_radius investigation" do
      output = capture_io(fn -> HelpDisplay.display_help(["blast_radius"]) end)

      assert output =~ "Blast Radius Analysis"
      assert output =~ "blast-radius"
      assert output =~ "Options:"
      assert output =~ "--target-files"
    end

    test "displays help for summary investigation" do
      output = capture_io(fn -> HelpDisplay.display_help(["summary"]) end)

      assert output =~ "Summary Analysis"
      assert output =~ "Provides general statistics about the repository"
      assert output =~ "Options:"
    end

    test "displays error for unknown investigation" do
      output = capture_io(fn -> HelpDisplay.display_help(["unknown_investigation"]) end)

      assert output =~ "No help available for unknown investigation: unknown_investigation"
      assert output =~ "Available Investigations:"
    end
  end

  describe "display_version/1" do
    test "displays version information" do
      output = capture_io(fn -> HelpDisplay.display_version([]) end)

      assert output =~ "Gitlock version"
      assert output =~ "Elixir version"
      assert output =~ "OTP version"
    end
  end
end
