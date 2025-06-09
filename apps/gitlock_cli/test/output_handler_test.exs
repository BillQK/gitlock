defmodule GitlockCLI.OutputHandlerTest do
  # Remove async: true for tests that capture IO
  use ExUnit.Case
  import ExUnit.CaptureIO

  alias GitlockCLI.OutputHandler

  setup do
    # Create a temp directory for file outputs with a unique name
    {:ok, output_dir} =
      Briefly.create(
        directory: true,
        prefix: "gitlock_test_#{System.unique_integer([:positive])}"
      )

    # Create a test content with well-known size
    test_content = String.duplicate("test data row\n", 100)

    %{output_dir: output_dir, test_content: test_content}
  end

  describe "output_to_file/4" do
    test "handles CSV output to file", %{output_dir: dir, test_content: content} do
      output_file = Path.join(dir, "output.csv")
      options = %{format: "csv", output: output_file}
      investigation_type = :hotspots

      output =
        capture_io(fn ->
          OutputHandler.output_to_file(content, investigation_type, options, output_file)
        end)

      assert output =~ "Writing output to #{output_file}"
      assert File.exists?(output_file)
      assert File.read!(output_file) == content
    end
  end

  describe "generate_output_filename/2" do
    test "generates timestamped filename for investigation" do
      filename = OutputHandler.generate_output_filename(:hotspots, %{format: "csv"})

      assert filename =~ "gitlock_hotspots_"
      assert filename =~ ".csv"
      assert File.dir?(Path.dirname(filename))
    end

    test "handles different investigation types" do
      filename1 = OutputHandler.generate_output_filename(:couplings, %{format: "csv"})
      filename2 = OutputHandler.generate_output_filename(:summary, %{format: "json"})

      assert filename1 =~ "gitlock_couplings_"
      assert filename1 =~ ".csv"

      assert filename2 =~ "gitlock_summary_"
      assert filename2 =~ ".json"
    end
  end

  describe "output_to_stdout/2" do
    test "outputs content to stdout", %{test_content: content} do
      output =
        capture_io(fn ->
          OutputHandler.output_to_stdout(content, %{format: "csv"})
        end)

      assert output == content
    end

    test "handles JSON format", %{test_content: content} do
      output =
        capture_io(fn ->
          OutputHandler.output_to_stdout(content, %{format: "json"})
        end)

      # Since JSON formatting is a placeholder in the implementation,
      # we just check that the content is returned
      assert output == content
    end
  end

  describe "warn_if_large_output/2" do
    test "warns if content is large" do
      # Create a large content (greater than 10MB)
      large_content = String.duplicate("x", 11_000_000)

      # Capture both stderr streams to handle both the warning and potential deprecation messages
      stderr_output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          OutputHandler.warn_if_large_output(large_content)
        end)

      assert stderr_output =~ "Output is quite large"
      assert stderr_output =~ "MB"
      assert stderr_output =~ "Consider using --limit"
    end

    test "doesn't warn if content is small" do
      small_content = String.duplicate("x", 100)

      # Focus only on warnings related to output size
      stderr_output =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          OutputHandler.warn_if_large_output(small_content)
        end)

      refute stderr_output =~ "Output is quite large"
    end

    test "uses custom threshold" do
      medium_content = String.duplicate("x", 1_500_000)

      # With default threshold (10MB), no warning about size
      stderr_output1 =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          OutputHandler.warn_if_large_output(medium_content)
        end)

      refute stderr_output1 =~ "Output is quite large"

      # With custom threshold (1MB), should warn about size
      stderr_output2 =
        ExUnit.CaptureIO.capture_io(:stderr, fn ->
          OutputHandler.warn_if_large_output(medium_content, 1_000_000)
        end)

      assert stderr_output2 =~ "Output is quite large"
    end
  end
end
