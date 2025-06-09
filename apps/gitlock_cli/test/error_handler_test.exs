defmodule GitlockCLI.ErrorHandlerTest do
  use ExUnit.Case, async: true
  import ExUnit.CaptureIO

  alias GitlockCLI.ErrorHandler

  describe "handle_error/1" do
    test "handles file not found error" do
      error = {:io, "/path/to/file.txt", :enoent}

      assert capture_io(:stderr, fn ->
               assert catch_exit(ErrorHandler.handle_error(error)) == 1
             end) =~ "Error: File not found: /path/to/file.txt"
    end

    test "handles file permission error" do
      error = {:io, "/path/to/file.txt", :eacces}

      assert capture_io(:stderr, fn ->
               assert catch_exit(ErrorHandler.handle_error(error)) == 1
             end) =~ "Error reading file /path/to/file.txt: :eacces"
    end

    test "handles git error" do
      error = {:git, "repository is corrupted"}

      assert capture_io(:stderr, fn ->
               assert catch_exit(ErrorHandler.handle_error(error)) == 1
             end) =~ "Git error: repository is corrupted"
    end

    test "handles parse error" do
      error = {:parse, "Invalid log format"}

      assert capture_io(:stderr, fn ->
               assert catch_exit(ErrorHandler.handle_error(error)) == 1
             end) =~ "Error parsing input: Invalid log format"
    end

    test "handles analysis error" do
      error = {:analysis, "Failed to analyze coupling"}

      assert capture_io(:stderr, fn ->
               assert catch_exit(ErrorHandler.handle_error(error)) == 1
             end) =~ "Error during analysis: Failed to analyze coupling"
    end

    test "handles commit error" do
      error = {:commit, "Invalid commit format"}

      assert capture_io(:stderr, fn ->
               assert catch_exit(ErrorHandler.handle_error(error)) == 1
             end) =~ "Error processing commit: Invalid commit format"
    end

    test "handles validation error" do
      error = {:validation, "Missing required options"}

      assert capture_io(:stderr, fn ->
               assert catch_exit(ErrorHandler.handle_error(error)) == 1
             end) =~ "Validation error: Missing required options"
    end

    test "handles string error" do
      error = "General error message"

      assert capture_io(:stderr, fn ->
               assert catch_exit(ErrorHandler.handle_error(error)) == 1
             end) =~ "Error: General error message"
    end

    test "handles other error types" do
      error = {:unknown_type, :some_data}

      assert capture_io(:stderr, fn ->
               assert catch_exit(ErrorHandler.handle_error(error)) == 1
             end) =~ "Error: {:unknown_type, :some_data}"
    end
  end

  describe "display_invalid_options/1" do
    test "displays error for single invalid option" do
      invalid = [{"--unknown-flag", nil}]

      assert capture_io(:stderr, fn ->
               assert catch_exit(ErrorHandler.display_invalid_options(invalid)) == 1
             end) =~ "Error: Invalid option(s): --unknown-flag"
    end

    test "displays error for multiple invalid options" do
      invalid = [{"--bad1", nil}, {"--bad2", nil}]

      assert capture_io(:stderr, fn ->
               assert catch_exit(ErrorHandler.display_invalid_options(invalid)) == 1
             end) =~ "Error: Invalid option(s): --bad1, --bad2"
    end
  end

  describe "warn/1" do
    test "outputs warning to stderr" do
      warning = "This is a warning message"

      assert capture_io(:stderr, fn ->
               ErrorHandler.warn(warning)
             end) =~ "Warning: This is a warning message"
    end
  end
end
