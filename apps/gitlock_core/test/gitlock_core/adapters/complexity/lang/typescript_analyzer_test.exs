defmodule GitlockCore.Adapters.Complexity.Lang.TypeScriptAnalyzerTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Adapters.Complexity.Lang.TypeScriptAnalyzer

  describe "supported_extensions/0" do
    test "returns TypeScript file extensions" do
      assert TypeScriptAnalyzer.supported_extensions() == [".ts", ".tsx"]
    end
  end

  describe "analyze_content/2 - JS constructs still work" do
    test "simple function with no branching" do
      code = """
      function hello(): string {
        return "world";
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      # 1 base + 1 function
      assert metrics.cyclomatic_complexity >= 2
      assert metrics.language == :typescript
    end

    test "if/else counts correctly" do
      code = """
      function test(x: number): string {
        if (x > 0) {
          return "positive";
        } else {
          return "non-positive";
        }
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      # 1 base + 1 fn + 1 if = 3
      assert metrics.cyclomatic_complexity >= 3
    end

    test "switch case counts each case" do
      code = """
      function describe(status: Status): string {
        switch (status) {
          case "active": return "running";
          case "paused": return "waiting";
          case "done": return "finished";
          default: return "unknown";
        }
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      # 1 base + 1 fn + 3 cases (default is not `case`) = 5
      assert metrics.cyclomatic_complexity >= 4
    end

    test "logical operators" do
      code = """
      function check(a: boolean, b: boolean, c: boolean): boolean {
        return a && b || c;
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      # 1 base + 1 fn + 1 && + 1 || = 4
      assert metrics.cyclomatic_complexity >= 4
    end

    test "arrow functions" do
      code = """
      const add = (a: number, b: number): number => a + b;
      const mul = (a: number, b: number): number => a * b;
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      # 1 base + 2 arrows = 3
      assert metrics.cyclomatic_complexity >= 3
    end
  end

  describe "analyze_content/2 - type constructs stripped (no false positives)" do
    test "conditional types do NOT count as ternary" do
      code = """
      type IsString<T> = T extends string ? true : false;
      type Result<T> = T extends Error ? never : T;

      function simple(): void {
        console.log("no branches here");
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      # Should NOT count the two `?` in conditional types
      # 1 base + 1 fn = 2
      assert metrics.cyclomatic_complexity <= 3
    end

    test "interface declarations do NOT add complexity" do
      code = """
      interface User {
        name: string;
        age: number;
        isActive: boolean;
      }

      function greet(user: User): string {
        return "hello";
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      # 1 base + 1 fn = 2
      assert metrics.cyclomatic_complexity <= 3
    end

    test "type aliases do NOT add complexity" do
      code = """
      type Status = "active" | "inactive" | "pending";
      type Handler = (event: Event) => void;

      function process(): void {
        return;
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      assert metrics.cyclomatic_complexity <= 3
    end

    test "generic type parameters do NOT cause false positives" do
      code = """
      function identity<T extends Comparable>(value: T): T {
        return value;
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      # 1 base + 1 fn = 2
      assert metrics.cyclomatic_complexity <= 3
    end

    test "enum declarations do NOT add complexity" do
      code = """
      enum Direction {
        Up = "UP",
        Down = "DOWN",
        Left = "LEFT",
        Right = "RIGHT",
      }

      function move(): void {
        return;
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      assert metrics.cyclomatic_complexity <= 3
    end
  end

  describe "analyze_content/2 - TypeScript-specific patterns" do
    test "optional chaining counts as branch" do
      code = """
      function getName(user: User | null): string {
        const name = user?.name;
        const city = user?.address?.city;
        return name ?? "unknown";
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      # 1 base + 1 fn + 2 optional chain + 1 nullish = 5
      assert metrics.cyclomatic_complexity >= 4
    end

    test "type guard functions count as decision point" do
      code = """
      function isString(value: unknown): value is string {
        return typeof value === "string";
      }

      function isUser(obj: any): obj is User {
        return obj && typeof obj.name === "string";
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      # Should count the type guard signatures
      assert metrics.cyclomatic_complexity >= 3
    end

    test "nullish coalescing counts" do
      code = """
      function defaults(config: Partial<Config>): Config {
        const timeout = config.timeout ?? 5000;
        const retries = config.retries ?? 3;
        return { timeout, retries };
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      # 1 base + 1 fn + 2 ?? = 4
      assert metrics.cyclomatic_complexity >= 4
    end
  end

  describe "analyze_content/2 - comments and strings" do
    test "if inside comment NOT counted" do
      code = """
      function test(): void {
        // if (this should not count)
        /* if (neither should this) */
        return;
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      assert metrics.cyclomatic_complexity <= 3
    end

    test "if inside string literal NOT counted" do
      code = """
      function test(): string {
        return "if this is counted it is a bug";
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      assert metrics.cyclomatic_complexity <= 3
    end
  end

  describe "analyze_content/2 - realistic TypeScript code" do
    test "React component with hooks" do
      code = """
      interface Props {
        userId: string;
        onError?: (err: Error) => void;
      }

      type Status = "loading" | "error" | "success";

      function UserProfile({ userId, onError }: Props): JSX.Element {
        const [status, setStatus] = useState<Status>("loading");

        useEffect(() => {
          fetchUser(userId)
            .then(data => {
              if (data) {
                setStatus("success");
              } else {
                setStatus("error");
              }
            })
            .catch(err => {
              onError?.(err);
              setStatus("error");
            });
        }, [userId]);

        if (status === "loading") {
          return <Spinner />;
        }

        if (status === "error") {
          return <ErrorView />;
        }

        return <Profile />;
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.tsx")
      # Has real runtime complexity: ifs, arrow fns, optional chain, catch
      assert metrics.cyclomatic_complexity >= 6
      assert metrics.language == :typescript
    end

    test "service class with error handling" do
      code = """
      class ApiService {
        async fetchData<T>(url: string): Promise<T> {
          try {
            const response = await fetch(url);
            if (!response.ok) {
              throw new Error("HTTP error");
            }
            return await response.json();
          } catch (error) {
            if (error instanceof TypeError) {
              throw new NetworkError("Network failed");
            }
            throw error;
          }
        }
      }
      """

      {:ok, metrics} = TypeScriptAnalyzer.analyze_content(code, "test.ts")
      # 1 base + arrows/fns + 2 ifs + 1 catch = high
      assert metrics.cyclomatic_complexity >= 4
    end
  end

  describe "analyze_file/1" do
    setup do
      {:ok, test_dir} = Briefly.create(directory: true)
      {:ok, test_dir: test_dir}
    end

    test "analyzes .ts file", %{test_dir: dir} do
      path = Path.join(dir, "app.ts")

      File.write!(path, """
      function greet(name: string): string {
        if (name) {
          return `Hello, ${name}`;
        }
        return "Hello, stranger";
      }
      """)

      {:ok, metrics} = TypeScriptAnalyzer.analyze_file(path)
      assert metrics.file_path == path
      assert metrics.language == :typescript
      assert metrics.cyclomatic_complexity >= 2
    end

    test "analyzes .tsx file", %{test_dir: dir} do
      path = Path.join(dir, "component.tsx")

      File.write!(path, """
      function Button({ label }: { label: string }) {
        return <button>{label}</button>;
      }
      """)

      {:ok, metrics} = TypeScriptAnalyzer.analyze_file(path)
      assert metrics.language == :typescript
    end

    test "handles file not found" do
      assert {:error, {:io, _, :enoent}} = TypeScriptAnalyzer.analyze_file("/nonexistent.ts")
    end
  end

  describe "behavior compliance" do
    test "implements ComplexityAnalyzerPort behavior" do
      behaviors = TypeScriptAnalyzer.__info__(:attributes)[:behaviour] || []
      assert GitlockCore.Ports.ComplexityAnalyzerPort in behaviors
    end
  end
end
