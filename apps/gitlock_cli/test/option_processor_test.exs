defmodule GitlockCLI.OptionProcessorTest do
  use ExUnit.Case, async: false
  alias GitlockCLI.OptionProcessor

  describe "prepare_options/2" do
    test "processes single target file" do
      parsed_options = %{target_files: "main.ex"}
      options = OptionProcessor.prepare_options(parsed_options, [])

      assert options.target_files == ["main.ex"]
    end

    test "processes multiple target files as list" do
      parsed_options = %{target_files: ["main.ex", "helper.ex"]}
      options = OptionProcessor.prepare_options(parsed_options, [])

      assert options.target_files == ["main.ex", "helper.ex"]
    end

    test "processes comma-separated target files" do
      parsed_options = %{target_files: "main.ex,helper.ex,utils.ex"}
      options = OptionProcessor.prepare_options(parsed_options, [])

      assert options.target_files == ["main.ex", "helper.ex", "utils.ex"]
    end

    test "merges target files from options and remaining args" do
      parsed_options = %{target_files: "main.ex"}
      options = OptionProcessor.prepare_options(parsed_options, ["helper.ex"])

      assert options.target_files == ["main.ex", "helper.ex"]
    end

    test "removes duplicate target files" do
      parsed_options = %{target_files: ["main.ex", "main.ex"]}
      options = OptionProcessor.prepare_options(parsed_options, ["main.ex"])

      assert options.target_files == ["main.ex"]
    end

    test "processes mix of comma-separated and regular target files" do
      parsed_options = %{target_files: ["main.ex,helper.ex", "utils.ex"]}
      options = OptionProcessor.prepare_options(parsed_options, ["config.ex"])

      assert options.target_files == ["main.ex", "helper.ex", "utils.ex", "config.ex"]
    end

    test "normalizes option aliases" do
      parsed_options = %{tf: "main.ex", bt: 0.2, mr: 3}
      options = OptionProcessor.prepare_options(parsed_options, [])

      assert options.target_files == ["main.ex"]
      assert options.blast_threshold == 0.2
      assert options.max_radius == 3
    end

    test "applies default values" do
      options = OptionProcessor.prepare_options(%{}, [])

      assert options.format == "csv"
      assert options.limit == 10
      assert options.min_revs == 5
      assert options.min_coupling == 0.5
      assert options.blast_threshold == 0.1
      assert options.max_radius == 2
    end
  end
end
