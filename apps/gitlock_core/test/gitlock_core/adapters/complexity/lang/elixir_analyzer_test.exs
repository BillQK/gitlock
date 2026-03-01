defmodule GitlockCore.Adapters.Complexity.Lang.ElixirAnalyzerTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Adapters.Complexity.Lang.ElixirAnalyzer

  describe "supported_extensions/0" do
    test "returns Elixir file extensions" do
      assert ElixirAnalyzer.supported_extensions() == [".ex", ".exs"]
    end
  end

  describe "calculate_complexity/2 - basic constructs" do
    test "simple module with no branching = 1" do
      code = """
      defmodule Simple do
        def hello, do: "world"
      end
      """

      assert ElixirAnalyzer.calculate_complexity(code, "test.ex") == 1
    end

    test "if statement adds 1" do
      code = """
      defmodule M do
        def test(x) do
          if x > 0 do
            :positive
          else
            :negative
          end
        end
      end
      """

      # 1 base + 1 if = 2
      assert ElixirAnalyzer.calculate_complexity(code, "test.ex") == 2
    end

    test "case counts each clause" do
      code = """
      defmodule M do
        def test(x) do
          case x do
            :a -> 1
            :b -> 2
            _ -> 3
          end
        end
      end
      """

      # 1 base + 3 clauses = 4
      assert ElixirAnalyzer.calculate_complexity(code, "test.ex") == 4
    end

    test "cond counts each condition" do
      code = """
      defmodule M do
        def test(x) do
          cond do
            x > 10 -> :high
            x > 0 -> :positive
            true -> :other
          end
        end
      end
      """

      # 1 base + 3 cond clauses = 4
      assert ElixirAnalyzer.calculate_complexity(code, "test.ex") == 4
    end

    test "boolean operators add complexity" do
      code = """
      defmodule M do
        def test(a, b) do
          if a && b do
            :both
          end
        end
      end
      """

      # 1 base + 1 if + 1 && = 3
      assert ElixirAnalyzer.calculate_complexity(code, "test.ex") == 3
    end
  end

  describe "calculate_complexity/2 - with statement" do
    test "with clauses add complexity" do
      code = """
      defmodule M do
        def test(a, b) do
          with {:ok, x} <- fetch(a),
               {:ok, y} <- fetch(b) do
            {:ok, x + y}
          end
        end
      end
      """

      complexity = ElixirAnalyzer.calculate_complexity(code, "test.ex")
      # 1 base + 2 with clauses = 3
      assert complexity >= 3
    end

    test "with/else counts else clauses" do
      code = """
      defmodule M do
        def test(input) do
          with {:ok, parsed} <- parse(input),
               {:ok, valid} <- validate(parsed) do
            {:ok, valid}
          else
            {:error, :parse} -> {:error, "bad parse"}
            {:error, :validate} -> {:error, "invalid"}
          end
        end
      end
      """

      complexity = ElixirAnalyzer.calculate_complexity(code, "test.ex")
      # 1 base + 2 with + 2 else = 5
      assert complexity >= 5
    end
  end

  describe "calculate_complexity/2 - try/rescue/catch" do
    test "rescue clauses add complexity" do
      code = """
      defmodule M do
        def test(x) do
          try do
            risky(x)
          rescue
            ArgumentError -> :arg_error
            RuntimeError -> :runtime_error
          end
        end
      end
      """

      complexity = ElixirAnalyzer.calculate_complexity(code, "test.ex")
      # 1 base + 2 rescue clauses = 3
      assert complexity >= 3
    end

    test "catch clauses add complexity" do
      code = """
      defmodule M do
        def test(x) do
          try do
            risky(x)
          catch
            :exit, _ -> :exited
            :throw, val -> val
          end
        end
      end
      """

      complexity = ElixirAnalyzer.calculate_complexity(code, "test.ex")
      assert complexity >= 3
    end
  end

  describe "calculate_complexity/2 - receive" do
    test "receive clauses add complexity" do
      code = """
      defmodule M do
        def loop do
          receive do
            {:msg, data} -> handle(data)
            :stop -> :ok
          after
            5000 -> :timeout
          end
        end
      end
      """

      complexity = ElixirAnalyzer.calculate_complexity(code, "test.ex")
      # 1 base + 2 receive clauses + 1 after = 4
      assert complexity >= 4
    end
  end

  describe "calculate_complexity/2 - multi-clause functions" do
    test "function with guard adds 1" do
      code = """
      defmodule M do
        def test(x) when x > 0, do: :positive
        def test(_), do: :other
      end
      """

      complexity = ElixirAnalyzer.calculate_complexity(code, "test.ex")
      # 1 base + 1 guard = 2
      assert complexity >= 2
    end
  end

  describe "calculate_complexity/2 - anonymous functions" do
    test "multi-clause fn adds complexity" do
      code = """
      defmodule M do
        def test do
          handler = fn
            :ok -> :success
            :error -> :failure
            _ -> :unknown
          end

          handler.(:ok)
        end
      end
      """

      complexity = ElixirAnalyzer.calculate_complexity(code, "test.ex")
      # 1 base + 3 fn clauses = 4
      assert complexity >= 4
    end

    test "single-clause fn does not add extra complexity" do
      code = """
      defmodule M do
        def test do
          Enum.map([1, 2, 3], fn x -> x * 2 end)
        end
      end
      """

      # 1 base, single-clause fn doesn't branch
      assert ElixirAnalyzer.calculate_complexity(code, "test.ex") == 1
    end
  end

  describe "calculate_complexity/2 - nested complexity" do
    test "deeply nested code accumulates correctly" do
      code = """
      defmodule M do
        def test(x, y, z) do
          if x > 0 do
            if y > 0 do
              case z do
                :a -> 1
                :b -> 2
                _ -> 3
              end
            else
              cond do
                x > 10 && z > 0 -> :high
                x > 5 || z < 0 -> :medium
                true -> :fallback
              end
            end
          else
            :negative
          end
        end
      end
      """

      complexity = ElixirAnalyzer.calculate_complexity(code, "test.ex")
      # 1 base + 2 ifs + 3 case + 3 cond + 2 boolean = 11
      assert complexity > 7
    end
  end

  describe "calculate_complexity/2 - error handling" do
    test "syntax errors return -1" do
      code = """
      defmodule Bad do
        def missing_end do
          if true do
            :true
      end
      """

      assert ElixirAnalyzer.calculate_complexity(code, "test.ex") == -1
    end

    test "empty string returns 1" do
      assert ElixirAnalyzer.calculate_complexity("", "test.ex") == 1
    end
  end

  describe "analyze_file/1" do
    setup do
      {:ok, test_dir} = Briefly.create(directory: true)
      {:ok, test_dir: test_dir}
    end

    test "analyzes file and returns metrics", %{test_dir: test_dir} do
      path = Path.join(test_dir, "simple.ex")

      File.write!(path, """
      defmodule Simple do
        def hello, do: "world"
      end
      """)

      {:ok, metrics} = ElixirAnalyzer.analyze_file(path)

      assert metrics.file_path == path
      assert metrics.language == :elixir
      assert metrics.loc > 0
      assert metrics.cyclomatic_complexity == 1
    end

    test "handles file not found" do
      assert {:error, {:io, _, :enoent}} = ElixirAnalyzer.analyze_file("/nonexistent.ex")
    end
  end

  describe "behavior compliance" do
    test "implements ComplexityAnalyzerPort behavior" do
      behaviors = ElixirAnalyzer.__info__(:attributes)[:behaviour] || []
      assert GitlockCore.Ports.ComplexityAnalyzerPort in behaviors
    end
  end
end
