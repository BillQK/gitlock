defmodule GitlockCore.Adapters.Complexity.Lang.JavaScriptAnalyzerTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Adapters.Complexity.Lang.JavaScriptAnalyzer

  describe "supported_extensions/0" do
    test "returns JS/TS file extensions" do
      assert JavaScriptAnalyzer.supported_extensions() == [".js", ".jsx"]
    end
  end

  describe "analyze_content/2 - basic constructs" do
    test "simple function with no branching" do
      code = """
      function hello() {
        return "world";
      }
      """

      {:ok, metrics} = JavaScriptAnalyzer.analyze_content(code, "test.js")
      # 1 base + 1 function decl = 2
      assert metrics.cyclomatic_complexity >= 1
    end

    test "if statement adds complexity" do
      code = """
      function test(x) {
        if (x > 0) {
          return "positive";
        }
      }
      """

      {:ok, metrics} = JavaScriptAnalyzer.analyze_content(code, "test.js")
      assert metrics.cyclomatic_complexity >= 2
    end

    test "switch case counts each case" do
      code = """
      function test(x) {
        switch(x) {
          case 1: return "one";
          case 2: return "two";
          case 3: return "three";
        }
      }
      """

      {:ok, metrics} = JavaScriptAnalyzer.analyze_content(code, "test.js")
      # 1 base + 1 fn + 3 cases = 5
      assert metrics.cyclomatic_complexity >= 4
    end

    test "logical operators add complexity" do
      code = """
      function test(a, b) {
        if (a && b || c) {
          return true;
        }
      }
      """

      {:ok, metrics} = JavaScriptAnalyzer.analyze_content(code, "test.js")
      # 1 base + 1 fn + 1 if + 1 && + 1 || = 5
      assert metrics.cyclomatic_complexity >= 4
    end
  end

  describe "analyze_content/2 - comment/string stripping" do
    test "if inside a single-line comment is NOT counted" do
      code = """
      function test() {
        // if (this should not count)
        return 1;
      }
      """

      {:ok, metrics} = JavaScriptAnalyzer.analyze_content(code, "test.js")
      # 1 base + 1 fn, NO if = 2
      assert metrics.cyclomatic_complexity <= 3
    end

    test "if inside a multi-line comment is NOT counted" do
      code = """
      function test() {
        /* if (x > 0) {
          return "this is a comment";
        } */
        return 1;
      }
      """

      {:ok, metrics} = JavaScriptAnalyzer.analyze_content(code, "test.js")
      assert metrics.cyclomatic_complexity <= 3
    end

    test "if inside a string literal is NOT counted" do
      code = """
      function test() {
        const msg = "if this is counted, it's a bug";
        const other = 'if single quotes too';
        return msg;
      }
      """

      {:ok, metrics} = JavaScriptAnalyzer.analyze_content(code, "test.js")
      assert metrics.cyclomatic_complexity <= 3
    end

    test "if inside a template literal is NOT counted" do
      code = """
      function test() {
        const msg = `if (x > 0) { this is a template literal }`;
        return msg;
      }
      """

      {:ok, metrics} = JavaScriptAnalyzer.analyze_content(code, "test.js")
      assert metrics.cyclomatic_complexity <= 3
    end
  end

  describe "analyze_content/2 - arrow functions" do
    test "arrow functions are counted" do
      code = """
      const add = (a, b) => a + b;
      const multiply = (a, b) => a * b;
      """

      {:ok, metrics} = JavaScriptAnalyzer.analyze_content(code, "test.js")
      # 1 base + 2 arrows = 3
      assert metrics.cyclomatic_complexity >= 3
    end
  end

  describe "behavior compliance" do
    test "implements ComplexityAnalyzerPort behavior" do
      behaviors = JavaScriptAnalyzer.__info__(:attributes)[:behaviour] || []
      assert GitlockCore.Ports.ComplexityAnalyzerPort in behaviors
    end
  end
end
