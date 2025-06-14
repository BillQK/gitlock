defmodule GitlockCore.Adapters.Complexity.DispatchAnalyzerTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Adapters.Complexity.DispatchAnalyzer

  describe "supported_extensions/0" do
    test "returns combined extensions from all analyzers" do
      extensions = DispatchAnalyzer.supported_extensions()

      # Should include extensions from all supported languages
      assert ".ex" in extensions
      assert ".exs" in extensions
      assert ".js" in extensions
      assert ".jsx" in extensions
      assert ".ts" in extensions
      assert ".tsx" in extensions
      assert ".py" in extensions
    end
  end

  describe "analyze_file/1" do
    setup do
      # Create a test directory with files of different types
      {:ok, test_dir} = Briefly.create(directory: true)

      # Create sample files of different types
      js_file = Path.join(test_dir, "test.js")

      File.write!(js_file, """
      function test() {
        if (true) {
          return 1;
        } else {
          return 0;
        }
      }
      """)

      ex_file = Path.join(test_dir, "test.ex")

      File.write!(ex_file, """
      defmodule Test do
        def func(x) do
          if x > 0 do
            :positive
          else
            :negative
          end
        end
      end
      """)

      py_file = Path.join(test_dir, "test.py")

      File.write!(py_file, """
      def test_function(value):
          if value > 10:
              return "high"
          elif value > 5:
              return "medium"
          else:
              return "low"
      """)

      unknown_file = Path.join(test_dir, "test.txt")
      File.write!(unknown_file, "Just a text file")

      {:ok,
       files: %{
         js: js_file,
         ex: ex_file,
         py: py_file,
         txt: unknown_file
       }}
    end

    test "delegates to appropriate analyzer based on extension", %{files: files} do
      # Test JavaScript file
      {:ok, js_metrics} = DispatchAnalyzer.analyze_file(files.js)
      assert js_metrics.language == :javascript
      # Should detect the if-else
      assert js_metrics.cyclomatic_complexity > 1

      # Test Elixir file
      {:ok, ex_metrics} = DispatchAnalyzer.analyze_file(files.ex)
      assert ex_metrics.language == :elixir
      # Should detect the if-else
      assert ex_metrics.cyclomatic_complexity > 1

      # Test Python file
      {:ok, py_metrics} = DispatchAnalyzer.analyze_file(files.py)
      assert py_metrics.language == :python
      # Should detect if-elif-else
      assert py_metrics.cyclomatic_complexity > 2

      # Test unknown file type (should use MockAnalyzer)
      {:ok, txt_metrics} = DispatchAnalyzer.analyze_file(files.txt)
      assert txt_metrics.language == :unknown
    end
  end
end
