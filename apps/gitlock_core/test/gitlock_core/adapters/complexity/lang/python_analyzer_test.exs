defmodule GitlockCore.Adapters.Complexity.Lang.PythonAnalyzerTest do
  use ExUnit.Case, async: true
  alias GitlockCore.Adapters.Complexity.Lang.PythonAnalyzer

  describe "supported_extensions/0" do
    test "returns Python file extensions" do
      assert PythonAnalyzer.supported_extensions() == [".py"]
    end
  end

  describe "analyze_file/1" do
    setup do
      # Create a temporary directory for test files
      test_dir = Path.join(System.tmp_dir!(), "python_analyzer_test_#{:rand.uniform(10000)}")
      File.mkdir_p!(test_dir)

      on_exit(fn ->
        File.rm_rf!(test_dir)
      end)

      {:ok, test_dir: test_dir}
    end

    test "analyzes a simple Python file", %{test_dir: test_dir} do
      # Create a temporary Python file
      path = Path.join(test_dir, "simple.py")

      content = """
      def calculate_fibonacci(n):
          \"\"\"Calculate fibonacci number.\"\"\"
          if n <= 1:
              return n
          else:
              return calculate_fibonacci(n-1) + calculate_fibonacci(n-2)

      def main():
          for i in range(10):
              if i % 2 == 0:
                  print(f"Fib({i}) = {calculate_fibonacci(i)}")
      """

      File.write!(path, content)

      {:ok, metrics} = PythonAnalyzer.analyze_file(path)

      assert metrics.file_path == path
      assert metrics.language == :python
      assert metrics.loc == 12
      # Base (1) + 2 functions (2) + 2 if statements (2) + 1 for loop (1) = 6
      assert metrics.cyclomatic_complexity >= 6
    end

    test "handles complex Python constructs", %{test_dir: test_dir} do
      path = Path.join(test_dir, "complex.py")

      content = """
      class DataProcessor:
          def process_data(self, data):
              try:
                  # List comprehension with condition
                  filtered = [x for x in data if x > 0 and x < 100]
                  
                  # Multiple conditions
                  if len(filtered) > 0:
                      if all(x % 2 == 0 for x in filtered):
                          return "all even"
                      elif any(x % 2 == 1 for x in filtered):
                          return "has odd"
                  
                  # Exception handling
              except ValueError as e:
                  print(f"Value error: {e}")
              except Exception:
                  print("Unknown error")
              
              # Ternary expression
              result = "success" if len(data) > 0 else "empty"
              return result

      # Match statement (Python 3.10+)
      def handle_command(command):
          match command:
              case "start":
                  return True
              case "stop":
                  return False
              case _:
                  return None
      """

      File.write!(path, content)

      {:ok, metrics} = PythonAnalyzer.analyze_file(path)

      # Should have higher complexity due to multiple constructs
      assert metrics.cyclomatic_complexity >= 10
    end

    test "handles files with syntax errors gracefully", %{test_dir: test_dir} do
      path = Path.join(test_dir, "broken.py")

      content = """
      def broken_function(
          # Missing closing parenthesis
          if True:
              print("This won't parse")
      """

      File.write!(path, content)

      # Should still return metrics even with syntax issues
      {:ok, metrics} = PythonAnalyzer.analyze_file(path)
      assert metrics.cyclomatic_complexity >= 1
    end

    test "handles empty files", %{test_dir: test_dir} do
      path = Path.join(test_dir, "empty.py")
      File.write!(path, "")

      {:ok, metrics} = PythonAnalyzer.analyze_file(path)

      assert metrics.file_path == path
      # Empty file is counted as 1 line
      assert metrics.loc == 1
      # Base complexity
      assert metrics.cyclomatic_complexity == 1
    end

    test "handles files with only comments", %{test_dir: test_dir} do
      path = Path.join(test_dir, "comments_only.py")

      content = """
      # This is a comment
      # Another comment
      # Yet another comment
      \"\"\"
      This is a docstring
      \"\"\"
      """

      File.write!(path, content)

      {:ok, metrics} = PythonAnalyzer.analyze_file(path)

      # Only base complexity
      assert metrics.cyclomatic_complexity == 1
    end
  end

  describe "analyze_directory/2" do
    setup do
      # Create a temporary directory for test files
      test_dir = Path.join(System.tmp_dir!(), "python_analyzer_dir_test_#{:rand.uniform(10000)}")
      File.mkdir_p!(test_dir)

      on_exit(fn ->
        File.rm_rf!(test_dir)
      end)

      {:ok, test_dir: test_dir}
    end

    test "analyzes all Python files in a directory", %{test_dir: test_dir} do
      # Create some Python files
      File.write!(Path.join(test_dir, "module1.py"), """
      def function1():
          if True:
              return 1
          return 0
      """)

      File.write!(Path.join(test_dir, "module2.py"), """
      class MyClass:
          def method1(self):
              for i in range(10):
                  if i > 5:
                      break
      """)

      # Create a subdirectory with another Python file
      subdir = Path.join(test_dir, "subpackage")
      File.mkdir_p!(subdir)

      File.write!(Path.join(subdir, "module3.py"), """
      def helper():
          while True:
              try:
                  break
              except:
                  pass
      """)

      # Create a non-Python file (should be ignored)
      File.write!(Path.join(test_dir, "readme.txt"), "Not a Python file")

      results = PythonAnalyzer.analyze_directory(test_dir)

      assert map_size(results) == 3
      assert Map.has_key?(results, "module1.py")
      assert Map.has_key?(results, "module2.py")
      assert Map.has_key?(results, "subpackage/module3.py")
      assert not Map.has_key?(results, "readme.txt")

      # Check that metrics were calculated for each file
      assert results["module1.py"].cyclomatic_complexity >= 2
      assert results["module2.py"].cyclomatic_complexity >= 3
      assert results["subpackage/module3.py"].cyclomatic_complexity >= 3
    end

    test "handles non-existent directory", %{test_dir: test_dir} do
      non_existent = Path.join(test_dir, "does_not_exist")

      result = PythonAnalyzer.analyze_directory(non_existent)

      assert {:error, _message} = result
    end
  end
end
