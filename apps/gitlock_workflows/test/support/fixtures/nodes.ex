defmodule GitlockWorkflows.Fixtures.Nodes do
  @moduledoc """
  Collection of test node implementations.
  """

  defmodule ValidNode do
    @moduledoc false
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.valid",
        displayName: "Valid Test Node",
        group: "test",
        version: 1,
        description: "A valid test node",
        inputs: [%{name: "input", type: :any, required: true}],
        outputs: [%{name: "output", type: :any}],
        parameters: [],
        tags: ["test", "valid"],
        deprecated: false,
        experimental: true
      }
    end

    @impl true
    def execute(input, _params, _context) do
      {:ok, %{:output => input["input"]}}
    end

    @impl true
    def validate_parameters(_params), do: :ok
  end

  defmodule MinimalNode do
    @moduledoc false
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.minimal",
        displayName: "Minimal Node",
        group: "test",
        version: 1,
        description: "Minimal metadata",
        inputs: [],
        outputs: [],
        parameters: []
      }
    end

    @impl true
    def execute(_input, _params, _context) do
      {:ok, %{}}
    end

    @impl true
    def validate_parameters(_params), do: :ok
  end

  defmodule SimpleNode do
    @moduledoc false
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.simple",
        displayName: "Simple Node",
        group: "test",
        version: 1,
        description: "A simple test node",
        inputs: [%{name: "value", type: :number, required: true}],
        outputs: [%{name: "result", type: :number}],
        parameters: [
          %{name: "multiplier", type: "number", default: 2, required: false}
        ]
      }
    end

    @impl true
    def execute(input, params, _context) do
      value = Map.get(input, "value", 0)
      multiplier = Map.get(params, "multiplier", 2)
      {:ok, %{:result => value * multiplier}}
    end

    @impl true
    def validate_parameters(params) do
      case Map.get(params, "multiplier") do
        nil -> :ok
        val when is_number(val) -> :ok
        _ -> {:error, [{:invalid_type, "multiplier", "Expected number"}]}
      end
    end
  end

  defmodule EchoNode do
    @moduledoc false
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.echo",
        displayName: "Echo Node",
        group: "test",
        version: 1,
        description: "Echoes input to output",
        inputs: [%{name: "input", type: :any, required: true}],
        outputs: [%{name: "output", type: :any}],
        parameters: []
      }
    end

    @impl true
    def execute(input_data, _params, _context) do
      {:ok, %{:output => input_data["input"]}}
    end

    @impl true
    def validate_parameters(_params), do: :ok
  end

  defmodule ErrorNode do
    @moduledoc false
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.error",
        displayName: "Error Node",
        group: "test",
        version: 1,
        description: "A node that always fails",
        inputs: [%{name: "main", type: :any, required: false}],
        outputs: [],
        parameters: []
      }
    end

    @impl true
    def execute(_input, _params, _context) do
      {:error, "Intentional error"}
    end

    @impl true
    def validate_parameters(_params), do: :ok
  end

  defmodule SlowNode do
    @moduledoc false
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.slow",
        displayName: "Slow Node",
        group: "test",
        version: 1,
        description: "A node that takes time",
        inputs: [],
        outputs: [],
        parameters: [%{name: "delay_ms", type: "number", default: 100}]
      }
    end

    @impl true
    def execute(_input, params, _context) do
      delay = Map.get(params, "delay_ms", 100)
      :timer.sleep(delay)
      {:ok, %{:completed => true}}
    end

    @impl true
    def validate_parameters(_params), do: :ok
  end

  defmodule CrashNode do
    @moduledoc false
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.crash",
        displayName: "Crash Node",
        group: "test",
        version: 1,
        description: "A node that crashes",
        inputs: [],
        outputs: [],
        parameters: []
      }
    end

    @impl true
    def execute(_input, _params, _context) do
      raise "Intentional crash!"
    end

    @impl true
    def validate_parameters(_params), do: :ok
  end

  defmodule TriggerNode do
    @moduledoc false
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.trigger",
        displayName: "Test Trigger",
        group: "trigger",
        version: 1,
        description: "Test trigger node",
        inputs: [],
        outputs: [%{name: "main", type: :any}],
        parameters: []
      }
    end

    @impl true
    def execute(_input, _params, _context) do
      {:ok, %{:main => %{triggered_at: DateTime.utc_now()}}}
    end

    @impl true
    def validate_parameters(_params), do: :ok
  end

  defmodule ProcessNode do
    @moduledoc false
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.process",
        displayName: "Test Process",
        group: "transform",
        version: 1,
        description: "Test processor node",
        inputs: [%{name: "main", type: :any, required: true}],
        outputs: [%{name: "main", type: :any}],
        parameters: [
          %{name: "delay_ms", type: "number", default: 0}
        ]
      }
    end

    @impl true
    def execute(input, params, _context) do
      delay = Map.get(params, "delay_ms", 0)
      if delay > 0, do: :timer.sleep(delay)

      {:ok, %{:main => Map.put(input["main"] || %{}, :processed, true)}}
    end

    @impl true
    def validate_parameters(_params), do: :ok
  end

  defmodule OutputNode do
    @moduledoc false
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.output",
        displayName: "Test Output",
        group: "output",
        version: 1,
        description: "Test output node",
        inputs: [%{name: "main", type: :any, required: true}],
        outputs: [],
        parameters: []
      }
    end

    @impl true
    def execute(_input, _params, _context) do
      {:ok, %{}}
    end

    @impl true
    def validate_parameters(_params), do: :ok
  end

  defmodule AnalysisNode do
    @moduledoc false
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.analysis",
        displayName: "Analysis Node",
        group: "analysis",
        version: 1,
        description: "Test analysis node",
        inputs: [],
        outputs: [],
        parameters: []
      }
    end

    @impl true
    def execute(_, _, _), do: {:ok, %{}}

    @impl true
    def validate_parameters(_), do: :ok
  end

  defmodule SearchableNode do
    @moduledoc false
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.searchable",
        displayName: "Hotspot Analyzer",
        group: "analysis",
        version: 1,
        description: "Analyzes code hotspots",
        inputs: [],
        outputs: [],
        parameters: [],
        tags: ["git", "analysis", "hotspot"]
      }
    end

    @impl true
    def execute(_, _, _), do: {:ok, %{}}

    @impl true
    def validate_parameters(_), do: :ok
  end

  defmodule TestNode do
    @moduledoc false
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.node",
        displayName: "Test Node",
        group: "test",
        version: 1,
        description: "A test node",
        inputs: [
          %{name: "main", type: :any, required: true},
          %{name: "optional", type: :string, required: false}
        ],
        outputs: [
          %{name: "main", type: :any},
          %{name: "secondary", type: :number}
        ],
        parameters: [
          %{
            name: "threshold",
            displayName: "Threshold",
            type: "number",
            default: 10,
            required: false
          }
        ]
      }
    end

    @impl true
    def execute(input_data, parameters, _context) do
      threshold = Map.get(parameters, "threshold", 10)
      result = Map.get(input_data, "main", 0) + threshold

      {:ok, %{:main => result, :secondary => threshold}}
    end

    @impl true
    def validate_parameters(parameters) do
      case Map.get(parameters, "threshold") do
        nil -> :ok
        val when is_number(val) -> :ok
        _ -> {:error, [{:invalid_type, "threshold must be a number"}]}
      end
    end
  end

  defmodule TargetNode do
    @moduledoc false
    use GitlockWorkflows.Runtime.Node

    @impl true
    def metadata do
      %{
        id: "test.target",
        displayName: "Target Node",
        group: "test",
        version: 1,
        description: "A target test node",
        inputs: [
          %{name: "main", type: :any, required: true},
          %{name: "numbers", type: :number, required: false}
        ],
        outputs: [
          %{name: "result", type: :string}
        ],
        parameters: []
      }
    end

    @impl true
    def execute(_input_data, _parameters, _context) do
      {:ok, %{:result => "processed"}}
    end

    @impl true
    def validate_parameters(_parameters), do: :ok
  end
end
