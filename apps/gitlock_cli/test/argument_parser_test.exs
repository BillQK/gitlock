defmodule GitlockCLI.ArgumentParserTest do
  use ExUnit.Case
  alias GitlockCLI.ArgumentParser

  describe "parse/1 - help and version" do
    test "returns help when --help is provided" do
      assert {:help, []} = ArgumentParser.parse(["--help"])
      assert {:help, []} = ArgumentParser.parse(["-h"])
      assert {:help, ["hotspots"]} = ArgumentParser.parse(["--help", "hotspots"])
    end

    test "returns version when --version is provided" do
      assert {:version} = ArgumentParser.parse(["--version"])
      assert {:version} = ArgumentParser.parse(["-v"])
    end
  end

  describe "parse/1 - invalid options" do
    test "returns invalid options for unrecognized flags" do
      assert {:invalid_options, invalid} = ArgumentParser.parse(["--unknown-flag"])
      assert [{"--unknown-flag", nil}] = invalid
    end

    test "returns invalid options for multiple unknown flags" do
      assert {:invalid_options, invalid} = ArgumentParser.parse(["--bad1", "--bad2"])
      assert length(invalid) == 2
    end
  end

  describe "parse/1 - new style positional arguments" do
    test "parses investigation as first positional argument" do
      assert {:ok, args} = ArgumentParser.parse(["hotspots", "--repo", "/path"])

      assert args.investigation_type == "hotspots"
      assert args.repo_source == "/path"
    end

    test "handles investigation with multiple options" do
      assert {:ok, args} =
               ArgumentParser.parse([
                 "blast_radius",
                 "--repo",
                 "/path",
                 "--dir",
                 "/src",
                 "--target-files",
                 "main.ex"
               ])

      assert args.investigation_type == "blast_radius"
      assert args.repo_source == "/path"
      assert args.options.dir == "/src"
      assert args.options.target_files == ["main.ex"]
    end

    test "handles remaining args after investigation" do
      assert {:ok, args} =
               ArgumentParser.parse([
                 "couplings",
                 "--repo",
                 "/path",
                 "extra",
                 "args"
               ])

      assert args.investigation_type == "couplings"
      assert args.repo_source == "/path"
    end
  end

  describe "parse/1 - legacy style with --investigation" do
    test "parses --investigation flag" do
      assert {:ok, args} =
               ArgumentParser.parse(["--investigation", "hotspots", "--repo", "/path"])

      assert args.investigation_type == "hotspots"
      assert args.repo_source == "/path"
    end

    test "parses -i short flag" do
      assert {:ok, args} = ArgumentParser.parse(["-i", "summary", "--repo", "/path"])

      assert args.investigation_type == "summary"
      assert args.repo_source == "/path"
    end

    test "prioritizes positional argument over --investigation flag" do
      assert {:ok, args} =
               ArgumentParser.parse([
                 "couplings",
                 "--investigation",
                 "hotspots",
                 "--repo",
                 "/path"
               ])

      # Positional argument should win
      assert args.investigation_type == "couplings"
    end
  end

  describe "parse/1 - repository source options" do
    test "uses --repo option" do
      assert {:ok, args} = ArgumentParser.parse(["summary", "--repo", "/my/repo"])
      assert args.repo_source == "/my/repo"
    end

    test "uses -r short flag" do
      assert {:ok, args} = ArgumentParser.parse(["summary", "-r", "/my/repo"])
      assert args.repo_source == "/my/repo"
    end

    test "uses --url option" do
      assert {:ok, args} =
               ArgumentParser.parse(["summary", "--url", "https://github.com/user/repo"])

      assert args.repo_source == "https://github.com/user/repo"
      assert args.options.source_type == :url
    end

    test "uses --log option (legacy)" do
      assert {:ok, args} = ArgumentParser.parse(["summary", "--log", "/path/to/log"])
      assert args.repo_source == "/path/to/log"
      assert args.options.source_type == :log_file
    end

    test "defaults to current directory when no source specified" do
      assert {:ok, args} = ArgumentParser.parse(["summary"])
      assert args.repo_source == "."
      assert args.options.source_type == :local_repo
    end
  end

  describe "parse/1 - output options" do
    test "processes format option" do
      assert {:ok, args} = ArgumentParser.parse(["summary", "--format", "json"])
      assert args.options.format == "json"
    end

    test "processes output file option" do
      assert {:ok, args} = ArgumentParser.parse(["summary", "--output", "results.csv"])
      assert args.options.output == "results.csv"
    end

    test "processes limit option" do
      assert {:ok, args} = ArgumentParser.parse(["hotspots", "--limit", "50"])
      assert args.options.rows == 50
    end

    test "processes legacy rows option" do
      assert {:ok, args} = ArgumentParser.parse(["hotspots", "--rows", "25"])
      assert args.options.rows == 25
    end
  end

  describe "parse/1 - analysis options" do
    test "processes dir option" do
      assert {:ok, args} = ArgumentParser.parse(["hotspots", "--dir", "/source"])
      assert args.options.dir == "/source"
    end

    test "processes short option aliases" do
      assert {:ok, args} =
               ArgumentParser.parse([
                 "hotspots",
                 # --dir
                 "-d",
                 "/source",
                 # --format
                 "-f",
                 "csv",
                 # --output
                 "-o",
                 "out.csv"
               ])

      assert args.options.dir == "/source"
      assert args.options.format == "csv"
      assert args.options.output == "out.csv"
    end
  end

  describe "parse/1 - blast radius specific options" do
    test "processes single target file" do
      assert {:ok, args} =
               ArgumentParser.parse([
                 "blast_radius",
                 "--target-files",
                 "main.ex"
               ])

      assert args.options.target_files == ["main.ex"]
    end

    test "processes multiple target files" do
      assert {:ok, args} =
               ArgumentParser.parse([
                 "blast_radius",
                 "--target-files",
                 "main.ex",
                 "--target-files",
                 "helper.ex"
               ])

      assert args.options.target_files == ["main.ex", "helper.ex"]
    end

    test "processes comma-separated target files" do
      assert {:ok, args} =
               ArgumentParser.parse([
                 "blast_radius",
                 "--target-files",
                 "main.ex,helper.ex,utils.ex"
               ])

      assert args.options.target_files == ["main.ex", "helper.ex", "utils.ex"]
    end

    test "processes blast threshold and max radius" do
      assert {:ok, args} =
               ArgumentParser.parse([
                 "blast_radius",
                 "--blast-threshold",
                 "0.5",
                 "--max-radius",
                 "3"
               ])

      assert args.options.blast_threshold == 0.5
      assert args.options.max_radius == 3
    end

    test "processes short aliases for blast radius options" do
      assert {:ok, args} =
               ArgumentParser.parse([
                 "blast_radius",
                 "--tf",
                 "main.ex",
                 "--bt",
                 "0.7",
                 "--mr",
                 "2"
               ])

      assert args.options.target_files == ["main.ex"]
      assert args.options.blast_threshold == 0.7
      assert args.options.max_radius == 2
    end
  end

  describe "parse/1 - repository source detection with file system" do
    test "detects local git repository" do
      {:ok, temp_dir} = Briefly.create(directory: true)

      # Create .git directory to simulate git repo
      git_dir = Path.join(temp_dir, ".git")
      File.mkdir_p!(git_dir)
      File.write!(Path.join(git_dir, "config"), "[core]\n\trepositoryformatversion = 0\n")

      assert {:ok, args} = ArgumentParser.parse(["summary", "--repo", temp_dir])
      assert args.repo_source == temp_dir
      assert args.options.source_type == :local_repo
    end

    test "detects log file" do
      {:ok, temp_file} = Briefly.create()
      File.write!(temp_file, "sample log content")

      assert {:ok, args} = ArgumentParser.parse(["summary", "--repo", temp_file])
      assert args.repo_source == temp_file
      assert args.options.source_type == :log_file
    end

    test "detects URL repository" do
      assert {:ok, args} =
               ArgumentParser.parse(["summary", "--repo", "https://github.com/user/repo.git"])

      assert args.repo_source == "https://github.com/user/repo.git"
      assert args.options.source_type == :url
    end

    test "detects SSH URL repository" do
      assert {:ok, args} =
               ArgumentParser.parse(["summary", "--repo", "git@github.com:user/repo.git"])

      assert args.repo_source == "git@github.com:user/repo.git"
      assert args.options.source_type == :url
    end

    test "handles non-existent path as log file" do
      non_existent = "/tmp/non_existent_#{:rand.uniform(10000)}"
      assert {:ok, args} = ArgumentParser.parse(["summary", "--repo", non_existent])
      assert args.repo_source == non_existent
      assert args.options.source_type == :log_file
    end
  end

  describe "parse/1 - error cases" do
    test "returns error when no investigation specified" do
      assert {:error, message} = ArgumentParser.parse(["--repo", "/path"])
      assert message =~ "No investigation specified"
    end

    test "returns error with helpful message" do
      assert {:error, message} = ArgumentParser.parse(["--output", "file.csv"])
      assert message =~ "Specify an investigation"
    end
  end

  describe "parse/1 - complex option combinations" do
    test "handles all options together" do
      {:ok, temp_dir} = Briefly.create(directory: true)

      assert {:ok, args} =
               ArgumentParser.parse([
                 "coupled_hotspots",
                 "--repo",
                 temp_dir,
                 "--dir",
                 "/source",
                 "--format",
                 "json",
                 "--output",
                 "results.json",
                 "--limit",
                 "100",
                 "--min-coupling",
                 "25.5",
                 "--min-windows",
                 "8"
               ])

      assert args.investigation_type == "coupled_hotspots"
      assert args.repo_source == temp_dir
      assert args.options.dir == "/source"
      assert args.options.format == "json"
      assert args.options.output == "results.json"
      assert args.options.rows == 100
      assert args.options.min_coupling == 25.5
      assert args.options.min_windows == 8
    end

    test "handles mixed long and short options" do
      assert {:ok, args} =
               ArgumentParser.parse([
                 "hotspots",
                 "-r",
                 "/repo",
                 "--dir",
                 "/src",
                 "-f",
                 "csv",
                 "--limit",
                 "50"
               ])

      assert args.investigation_type == "hotspots"
      assert args.repo_source == "/repo"
      assert args.options.dir == "/src"
      assert args.options.format == "csv"
      assert args.options.rows == 50
    end
  end
end
