defmodule GitlockCore.Adapters.Complexity.Lang.ElixirAnalyzerTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Adapters.Complexity.Lang.ElixirAnalyzer

  describe "supported_extensions/0" do
    test "returns Elixir file extensions" do
      assert ElixirAnalyzer.supported_extensions() == [".ex", ".exs"]
    end
  end

  describe "analyze_file/1" do
    setup do
      # Create a temporary directory for test files
      {:ok, test_dir} = Briefly.create(directory: true)

      {:ok, test_dir: test_dir}
    end

    test "analyzes simple Elixir code", %{test_dir: test_dir} do
      # Create a simple Elixir file
      simple_path = Path.join(test_dir, "simple.ex")

      simple_code = """
      defmodule Simple do
        def hello do
          "world"
        end
      end
      """

      File.write!(simple_path, simple_code)

      # Analyze the file
      {:ok, metrics} = ElixirAnalyzer.analyze_file(simple_path)

      # Verify results
      assert metrics.file_path == simple_path
      assert metrics.language == :elixir
      # 6 lines + trailings \n
      assert metrics.loc == 6
      assert metrics.cyclomatic_complexity > 0
    end

    test "analyzes code with if statements", %{test_dir: test_dir} do
      path = Path.join(test_dir, "if_statements.ex")

      code = """
      defmodule IfStatements do
        def test(value) do
          if value > 0 do
            :positive
          else
            :negative
          end
        end
      end
      """

      File.write!(path, code)

      {:ok, metrics} = ElixirAnalyzer.analyze_file(path)

      # 1 (base) + 1 (if) = at least 2
      assert metrics.cyclomatic_complexity >= 2
    end

    test "analyzes code with case expressions", %{test_dir: test_dir} do
      path = Path.join(test_dir, "case.ex")

      code = """
      defmodule CaseStatements do
        def test(value) do
          case value do
            x when x > 0 -> :positive
            x when x < 0 -> :negative
            0 -> :zero
          end
        end
      end
      """

      File.write!(path, code)

      {:ok, metrics} = ElixirAnalyzer.analyze_file(path)

      # 1 (base) + 3 (case clauses) = at least 4
      assert metrics.cyclomatic_complexity >= 4
    end

    test "analyzes code with cond expressions", %{test_dir: test_dir} do
      path = Path.join(test_dir, "cond.ex")

      code = """
      defmodule CondStatements do
        def test(value) do
          cond do
            value > 10 -> :high
            value > 0 -> :positive
            value < 0 -> :negative
            true -> :zero
          end
        end
      end
      """

      File.write!(path, code)

      {:ok, metrics} = ElixirAnalyzer.analyze_file(path)

      # 1 (base) + 4 (cond clauses) = at least 5
      assert metrics.cyclomatic_complexity >= 5
    end

    test "analyzes code with boolean operators", %{test_dir: test_dir} do
      path = Path.join(test_dir, "boolean_ops.ex")

      code = """
      defmodule BooleanOps do
        def test(a, b, c) do
          if a && (b || c) do
            :true
          else
            :false
          end
        end
      end
      """

      File.write!(path, code)

      {:ok, metrics} = ElixirAnalyzer.analyze_file(path)

      # 1 (base) + 1 (if) + 2 (boolean ops) = at least 4
      assert metrics.cyclomatic_complexity >= 4
    end

    test "analyzes code with nested function definitions", %{test_dir: test_dir} do
      path = Path.join(test_dir, "functions.ex")

      code = """
      defmodule Functions do
        def public_function(value) do
          if value > 0 do
            helper(value)
          else
            :negative
          end
        end
        
        defp helper(value) do
          cond do
            value > 10 -> :high
            true -> :normal
          end
        end
      end
      """

      File.write!(path, code)

      {:ok, metrics} = ElixirAnalyzer.analyze_file(path)

      # Should detect complexity from both functions and their contents
      assert metrics.cyclomatic_complexity >= 4
    end

    test "handles syntax errors gracefully", %{test_dir: test_dir} do
      path = Path.join(test_dir, "syntax_error.ex")

      code = """
      defmodule InvalidSyntax do
        def missing_end do
          if true do
            :true
          # Missing end
      end
      """

      File.write!(path, code)

      # Should return metrics with negative complexity for errors
      {:ok, metrics} = ElixirAnalyzer.analyze_file(path)
      assert metrics.cyclomatic_complexity == -1
    end

    test "handles empty files", %{test_dir: test_dir} do
      path = Path.join(test_dir, "empty.ex")
      File.write!(path, "")

      {:ok, metrics} = ElixirAnalyzer.analyze_file(path)

      assert metrics.file_path == path
      # Empty file has 1 line
      assert metrics.loc == 1
      # Base complexity is 1
      assert metrics.cyclomatic_complexity == 1
    end

    test "handles file not found errors" do
      result = ElixirAnalyzer.analyze_file("/path/to/nonexistent/file.ex")
      assert {:error, {:io, "/path/to/nonexistent/file.ex", :enoent}} = result
    end
  end

  describe "analyze_directory/2" do
    setup do
      # Create a temporary directory using Briefly
      {:ok, tmp_dir} = Briefly.create(directory: true)

      # Create subdirectory
      subdir = Path.join(tmp_dir, "subdir")
      File.mkdir_p!(subdir)

      # Briefly automatically cleans up when tests finish

      {:ok, test_dir: tmp_dir, subdir: subdir}
    end

    test "analyzes all Elixir files in a directory", %{test_dir: test_dir, subdir: subdir} do
      # Create several Elixir files
      File.write!(Path.join(test_dir, "module1.ex"), """
      defmodule Module1 do
        def function1(x) do
          if x > 0, do: :positive, else: :negative
        end
      end
      """)

      File.write!(Path.join(test_dir, "module2.ex"), """
      defmodule Module2 do
        def function2(x) do
          case x do
            n when n > 0 -> :positive
            n when n < 0 -> :negative
            _ -> :zero
          end
        end
      end
      """)

      File.write!(Path.join(subdir, "module3.ex"), """
      defmodule Subdir.Module3 do
        def function3(x) do
          cond do
            x > 10 -> :high
            x > 0 -> :positive
            x < 0 -> :negative
            true -> :zero
          end
        end
      end
      """)

      # Create a non-Elixir file (should be ignored)
      File.write!(Path.join(test_dir, "readme.txt"), "Not an Elixir file")

      # Analyze the directory
      results = ElixirAnalyzer.analyze_directory(test_dir)

      # Should have found all 3 Elixir files
      assert map_size(results) == 3
      assert Map.has_key?(results, "module1.ex")
      assert Map.has_key?(results, "module2.ex")
      assert Map.has_key?(results, "subdir/module3.ex")
      assert not Map.has_key?(results, "readme.txt")

      # Verify each file was analyzed correctly
      assert results["module1.ex"].language == :elixir
      assert results["module2.ex"].language == :elixir
      assert results["subdir/module3.ex"].language == :elixir

      # Check complexity values increase with more complex code structures
      # if statement
      assert results["module1.ex"].cyclomatic_complexity >= 2
      # case with clauses
      assert results["module2.ex"].cyclomatic_complexity >= 3
      # cond with clauses
      assert results["subdir/module3.ex"].cyclomatic_complexity >= 4
    end

    test "handles non-existent directory" do
      non_existent = "/not/a/real/directory/#{:rand.uniform(10000)}"
      result = ElixirAnalyzer.analyze_directory(non_existent)
      assert {:error, _message} = result
    end

    test "handles empty directory", %{test_dir: test_dir} do
      # Directory exists but has no files
      results = ElixirAnalyzer.analyze_directory(test_dir)
      assert is_map(results)
      assert map_size(results) == 0
    end
  end

  describe "calculate_complexity/2" do
    test "calculates correct complexity for simple code" do
      code = """
      defmodule Simple do
        def hello do
          "world"
        end
      end
      """

      complexity = ElixirAnalyzer.calculate_complexity(code, "test.ex")
      # Base complexity for a simple function
      assert complexity == 1
    end

    test "calculates correct complexity for if statements" do
      code = """
      defmodule IfTest do
        def test(x) do
          if x > 0 do
            :positive
          else
            :negative
          end
        end
      end
      """

      complexity = ElixirAnalyzer.calculate_complexity(code, "test.ex")
      # 1 (base) + 1 (if statement) = 2
      assert complexity == 2
    end

    test "calculates correct complexity for case expressions" do
      code = """
      defmodule CaseTest do
        def test(x) do
          case x do
            n when n > 0 -> :positive
            n when n < 0 -> :negative
            _ -> :zero
          end
        end
      end
      """

      complexity = ElixirAnalyzer.calculate_complexity(code, "test.ex")
      # Should count each case clause
      assert complexity >= 4
    end

    test "calculates correct complexity for complex nested code" do
      code = """
      defmodule ComplexTest do
        def test(x, y, z) do
          if x > 0 do
            if y > 0 do
              case z do
                z when z > 10 -> :high_z
                z when z > 0 -> :positive_z
                _ -> :non_positive_z
              end
            else
              cond do
                x > 10 && z > 0 -> :high_x_with_z
                x > 5 || z < 0 -> :medium_x
                true -> :fallback
              end
            end
          else
            :negative_x
          end
        end
      end
      """

      complexity = ElixirAnalyzer.calculate_complexity(code, "test.ex")
      # Has multiple nested conditions, should have high complexity
      assert complexity > 7
    end
  end

  describe "behavior compliance" do
    test "implements ComplexityAnalyzerPort behavior" do
      behaviors = ElixirAnalyzer.__info__(:attributes)[:behaviour] || []
      assert GitlockCore.Ports.ComplexityAnalyzerPort in behaviors

      # Test callback functions exist
      functions = ElixirAnalyzer.__info__(:functions)
      assert Keyword.has_key?(functions, :analyze_file)
      assert Keyword.has_key?(functions, :analyze_directory)
      assert Keyword.has_key?(functions, :supported_extensions)
    end
  end
end
