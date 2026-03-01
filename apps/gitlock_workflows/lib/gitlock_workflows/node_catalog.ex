defmodule GitlockWorkflows.NodeCatalog do
  @moduledoc """
  Registry of available workflow node types.

  Each type definition describes a node's category, ports, configuration
  schema, and runtime module. This is the **single source of truth** for
  node definitions — the Compiler and Runtime.Registry both derive their
  information from here.

  ## Adding a new node type

  1. Create a runtime module implementing `GitlockWorkflows.Runtime.Node`
  2. Add an entry here with `runtime_module: YourModule`
  3. That's it — the Compiler will map it, the Registry will register it
  """

  alias GitlockWorkflows.Port

  @type port_def :: %{name: String.t(), data_type: Port.data_type()}

  @type config_field :: %{
          key: String.t(),
          label: String.t(),
          type: :string | :integer | :select | :date,
          required: boolean(),
          default: any(),
          placeholder: String.t(),
          options: [%{value: String.t(), label: String.t()}] | nil
        }

  @type type_def :: %{
          type_id: atom(),
          category: :source | :filter | :analyze | :logic | :output,
          label: String.t(),
          description: String.t(),
          input_ports: [port_def()],
          output_ports: [port_def()],
          config_schema: [config_field()],
          runtime_module: module() | nil
        }

  alias GitlockWorkflows.Runtime.Nodes

  @node_types %{
    # ── Sources ─────────────────────────────────────────────────
    git_log: %{
      type_id: :git_log,
      category: :source,
      label: "Git Log",
      description: "Fetches commit history from a git repository",
      input_ports: [],
      output_ports: [
        %{name: "commits", data_type: :commits},
        %{name: "repo_path", data_type: :string}
      ],
      runtime_module: Nodes.Triggers.GitCommits,
      config_schema: [
        %{
          key: "repo_url",
          label: "Repository URL",
          type: :string,
          required: true,
          default: "",
          placeholder: "https://github.com/org/repo"
        },
        %{
          key: "branch",
          label: "Branch",
          type: :string,
          required: false,
          default: "",
          placeholder: "main (default: all branches)"
        },
        %{
          key: "depth",
          label: "Commit depth",
          type: :integer,
          required: false,
          default: nil,
          placeholder: "All commits"
        },
        %{
          key: "since",
          label: "Since date",
          type: :date,
          required: false,
          default: nil,
          placeholder: "YYYY-MM-DD"
        },
        %{
          key: "until",
          label: "Until date",
          type: :date,
          required: false,
          default: nil,
          placeholder: "YYYY-MM-DD"
        },
        %{
          key: "path_filter",
          label: "Path filter",
          type: :string,
          required: false,
          default: "",
          placeholder: "src/ or lib/my_app"
        }
      ]
    },

    # ── Analyzers ───────────────────────────────────────────────
    hotspot_detection: %{
      type_id: :hotspot_detection,
      category: :analyze,
      label: "Hotspot Detection",
      description: "Identifies high-change, high-complexity files",
      input_ports: [
        %{name: "commits", data_type: :commits},
        %{name: "complexity_map", data_type: :map, optional: true}
      ],
      output_ports: [%{name: "hotspots", data_type: :hotspots}],
      runtime_module: Nodes.Analysis.Hotspot,
      config_schema: [
        %{
          key: "rows",
          label: "Max results",
          type: :integer,
          required: false,
          default: nil,
          placeholder: "All results"
        }
      ]
    },
    coupling_detection: %{
      type_id: :coupling_detection,
      category: :analyze,
      label: "Coupling Detection",
      description: "Detects files that change together (temporal coupling)",
      input_ports: [%{name: "commits", data_type: :commits}],
      output_ports: [%{name: "couplings", data_type: :couplings}],
      runtime_module: Nodes.Analysis.Coupling,
      config_schema: [
        %{
          key: "min_coupling",
          label: "Min coupling score",
          type: :integer,
          required: false,
          default: 1,
          placeholder: "1"
        },
        %{
          key: "min_windows",
          label: "Min time windows",
          type: :integer,
          required: false,
          default: 5,
          placeholder: "5"
        }
      ]
    },
    knowledge_silo_detection: %{
      type_id: :knowledge_silo_detection,
      category: :analyze,
      label: "Knowledge Silos",
      description: "Identifies concentrated code ownership patterns",
      input_ports: [%{name: "commits", data_type: :commits}],
      output_ports: [%{name: "knowledge_silos", data_type: :knowledge_silos}],
      runtime_module: Nodes.Analysis.KnowledgeSilo,
      config_schema: []
    },
    code_age_analysis: %{
      type_id: :code_age_analysis,
      category: :analyze,
      label: "Code Age",
      description: "Analyzes how recently code was modified",
      input_ports: [%{name: "commits", data_type: :commits}],
      output_ports: [%{name: "code_age", data_type: :code_age}],
      runtime_module: Nodes.Analysis.CodeAge,
      config_schema: []
    },
    blast_radius_analysis: %{
      type_id: :blast_radius_analysis,
      category: :analyze,
      label: "Blast Radius",
      description: "Measures the impact scope of component changes",
      input_ports: [%{name: "commits", data_type: :commits}],
      output_ports: [%{name: "blast_radius", data_type: :blast_radius}],
      runtime_module: nil,
      config_schema: []
    },
    complexity_analysis: %{
      type_id: :complexity_analysis,
      category: :analyze,
      label: "Complexity Analysis",
      description: "Analyzes cyclomatic complexity of source files via git",
      input_ports: [%{name: "repo_path", data_type: :string}],
      output_ports: [%{name: "complexity_map", data_type: :map}],
      runtime_module: Nodes.Analysis.Complexity,
      config_schema: []
    },
    coupled_hotspot_analysis: %{
      type_id: :coupled_hotspot_analysis,
      category: :analyze,
      label: "Coupled Hotspots",
      description: "Finds hotspots that are temporally coupled",
      input_ports: [%{name: "commits", data_type: :commits}],
      output_ports: [%{name: "coupled_hotspots", data_type: :coupled_hotspots}],
      runtime_module: Nodes.Analysis.CoupledHotspot,
      config_schema: []
    },
    complexity_trend: %{
      type_id: :complexity_trend,
      category: :analyze,
      label: "Complexity Trends",
      description: "X-ray hotspots to reveal complexity trajectories over time",
      input_ports: [%{name: "commits", data_type: :commits}],
      output_ports: [%{name: "complexity_trends", data_type: :complexity_trends}],
      runtime_module: Nodes.Analysis.ComplexityTrend,
      config_schema: [
        %{
          key: "max_files",
          label: "Max files to analyze",
          type: :integer,
          required: false,
          default: 15,
          placeholder: "15"
        },
        %{
          key: "interval_days",
          label: "Sample interval (days)",
          type: :integer,
          required: false,
          default: 30,
          placeholder: "30"
        }
      ]
    },
    summary: %{
      type_id: :summary,
      category: :analyze,
      label: "Summary",
      description: "Generates a summary of repository activity",
      input_ports: [%{name: "commits", data_type: :commits}],
      output_ports: [%{name: "summary", data_type: :summary}],
      runtime_module: Nodes.Analysis.Summary,
      config_schema: []
    },

    # ── Logic ───────────────────────────────────────────────────
    filter: %{
      type_id: :filter,
      category: :logic,
      label: "Filter",
      description: "Keeps items matching a condition",
      input_ports: [%{name: "items", data_type: :analysis_result}],
      output_ports: [
        %{name: "kept", data_type: :analysis_result},
        %{name: "rejected", data_type: :analysis_result}
      ],
      runtime_module: Nodes.Logic.Filter,
      config_schema: [
        %{
          key: "field",
          label: "Field",
          type: :string,
          required: true,
          default: "",
          placeholder: "risk_factor"
        },
        %{
          key: "operator",
          label: "Operator",
          type: :select,
          required: true,
          default: "eq",
          placeholder: "",
          options: [
            %{value: "eq", label: "Equals"},
            %{value: "neq", label: "Not Equals"},
            %{value: "gt", label: "Greater Than"},
            %{value: "lt", label: "Less Than"},
            %{value: "gte", label: "≥"},
            %{value: "lte", label: "≤"},
            %{value: "contains", label: "Contains"},
            %{value: "not_contains", label: "Not Contains"}
          ]
        },
        %{
          key: "value",
          label: "Value",
          type: :string,
          required: true,
          default: "",
          placeholder: "high"
        }
      ]
    },
    sort: %{
      type_id: :sort,
      category: :logic,
      label: "Sort",
      description: "Sorts items by a field value",
      input_ports: [%{name: "items", data_type: :analysis_result}],
      output_ports: [%{name: "items", data_type: :analysis_result}],
      runtime_module: Nodes.Logic.Sort,
      config_schema: [
        %{
          key: "field",
          label: "Sort By",
          type: :string,
          required: true,
          default: "",
          placeholder: "risk_score"
        },
        %{
          key: "direction",
          label: "Direction",
          type: :select,
          required: false,
          default: "asc",
          placeholder: "",
          options: [%{value: "asc", label: "Ascending"}, %{value: "desc", label: "Descending"}]
        }
      ]
    },
    limit: %{
      type_id: :limit,
      category: :logic,
      label: "Limit",
      description: "Takes the first or last N items",
      input_ports: [%{name: "items", data_type: :analysis_result}],
      output_ports: [%{name: "items", data_type: :analysis_result}],
      runtime_module: Nodes.Logic.Limit,
      config_schema: [
        %{
          key: "count",
          label: "Count",
          type: :integer,
          required: true,
          default: 10,
          placeholder: "10"
        },
        %{
          key: "from",
          label: "From",
          type: :select,
          required: false,
          default: "start",
          placeholder: "",
          options: [%{value: "start", label: "First N"}, %{value: "end", label: "Last N"}]
        }
      ]
    },
    if_condition: %{
      type_id: :if_condition,
      category: :logic,
      label: "IF",
      description: "Routes items to 'true' or 'false' output based on a condition",
      input_ports: [%{name: "items", data_type: :analysis_result}],
      output_ports: [
        %{name: "true", data_type: :analysis_result},
        %{name: "false", data_type: :analysis_result}
      ],
      runtime_module: Nodes.Logic.If,
      config_schema: [
        %{
          key: "field",
          label: "Field",
          type: :string,
          required: true,
          default: "",
          placeholder: "risk_factor"
        },
        %{
          key: "operator",
          label: "Operator",
          type: :select,
          required: true,
          default: "eq",
          placeholder: "",
          options: [
            %{value: "eq", label: "Equals"},
            %{value: "neq", label: "Not Equals"},
            %{value: "gt", label: ">"},
            %{value: "lt", label: "<"},
            %{value: "gte", label: "≥"},
            %{value: "lte", label: "≤"},
            %{value: "is_empty", label: "Is Empty"},
            %{value: "is_not_empty", label: "Is Not Empty"}
          ]
        },
        %{
          key: "value",
          label: "Value",
          type: :string,
          required: false,
          default: "",
          placeholder: "high"
        }
      ]
    },
    switch: %{
      type_id: :switch,
      category: :logic,
      label: "Switch",
      description: "Routes items to different outputs based on a field's value",
      input_ports: [%{name: "items", data_type: :analysis_result}],
      output_ports: [
        %{name: "case_0", data_type: :analysis_result},
        %{name: "case_1", data_type: :analysis_result},
        %{name: "case_2", data_type: :analysis_result},
        %{name: "case_3", data_type: :analysis_result},
        %{name: "default", data_type: :analysis_result}
      ],
      runtime_module: Nodes.Logic.Switch,
      config_schema: [
        %{
          key: "field",
          label: "Field",
          type: :string,
          required: true,
          default: "",
          placeholder: "risk_factor"
        },
        %{
          key: "cases",
          label: "Cases",
          type: :string,
          required: true,
          default: "",
          placeholder: "high,medium,low"
        }
      ]
    },
    merge: %{
      type_id: :merge,
      category: :logic,
      label: "Merge",
      description: "Combines items from two inputs into one output",
      input_ports: [
        %{name: "items_a", data_type: :analysis_result},
        %{name: "items_b", data_type: :analysis_result}
      ],
      output_ports: [%{name: "items", data_type: :analysis_result}],
      runtime_module: Nodes.Logic.Merge,
      config_schema: [
        %{
          key: "mode",
          label: "Mode",
          type: :select,
          required: false,
          default: "append",
          placeholder: "",
          options: [
            %{value: "append", label: "Append"},
            %{value: "interleave", label: "Interleave"},
            %{value: "keep_a", label: "Keep A only"}
          ]
        }
      ]
    },
    aggregate: %{
      type_id: :aggregate,
      category: :logic,
      label: "Aggregate",
      description: "Computes statistics: count, sum, avg, min, max over items",
      input_ports: [%{name: "items", data_type: :analysis_result}],
      output_ports: [%{name: "result", data_type: :analysis_result}],
      runtime_module: Nodes.Logic.Aggregate,
      config_schema: [
        %{
          key: "operations",
          label: "Operations",
          type: :string,
          required: true,
          default: "count",
          placeholder: "count,sum:revisions,avg:risk_score"
        }
      ]
    },
    remove_duplicates: %{
      type_id: :remove_duplicates,
      category: :logic,
      label: "Remove Duplicates",
      description: "Removes duplicate items based on a field value",
      input_ports: [%{name: "items", data_type: :analysis_result}],
      output_ports: [%{name: "items", data_type: :analysis_result}],
      runtime_module: Nodes.Logic.RemoveDuplicates,
      config_schema: [
        %{
          key: "field",
          label: "Deduplicate By",
          type: :string,
          required: true,
          default: "",
          placeholder: "entity"
        }
      ]
    },
    group_by: %{
      type_id: :group_by,
      category: :logic,
      label: "Group By",
      description: "Groups items by a field value",
      input_ports: [%{name: "items", data_type: :analysis_result}],
      output_ports: [
        %{name: "groups", data_type: :analysis_result},
        %{name: "items", data_type: :analysis_result}
      ],
      runtime_module: Nodes.Logic.GroupBy,
      config_schema: [
        %{
          key: "field",
          label: "Group By",
          type: :string,
          required: true,
          default: "",
          placeholder: "risk_factor"
        }
      ]
    },

    # ── Outputs ─────────────────────────────────────────────────
    csv_report: %{
      type_id: :csv_report,
      category: :output,
      label: "CSV Report",
      description: "Formats analysis results as CSV",
      input_ports: [%{name: "results", data_type: :analysis_result}],
      output_ports: [],
      runtime_module: nil,
      config_schema: [
        %{
          key: "rows",
          label: "Max rows",
          type: :integer,
          required: false,
          default: nil,
          placeholder: "All rows"
        }
      ]
    },
    json_report: %{
      type_id: :json_report,
      category: :output,
      label: "JSON Report",
      description: "Formats analysis results as JSON",
      input_ports: [%{name: "results", data_type: :analysis_result}],
      output_ports: [],
      runtime_module: nil,
      config_schema: [
        %{
          key: "rows",
          label: "Max rows",
          type: :integer,
          required: false,
          default: nil,
          placeholder: "All rows"
        }
      ]
    }
  }

  # ── Public API ───────────────────────────────────────────────

  @doc "Returns all available node type definitions."
  @spec list_types() :: [type_def()]
  def list_types, do: Map.values(@node_types)

  @doc "Returns a node type definition by its id."
  @spec get_type(atom()) :: {:ok, type_def()} | {:error, :unknown_node_type}
  def get_type(type_id) do
    case Map.fetch(@node_types, type_id) do
      {:ok, type_def} -> {:ok, type_def}
      :error -> {:error, :unknown_node_type}
    end
  end

  @doc "Returns the runtime module for a node type, or nil if none."
  @spec runtime_module(atom()) :: module() | nil
  def runtime_module(type_id) do
    case get_type(type_id) do
      {:ok, %{runtime_module: mod}} -> mod
      {:error, _} -> nil
    end
  end

  @doc """
  Returns the runtime type string (Registry ID) for a node type.

  Reads the `metadata().id` from the runtime module. Returns nil if the
  node type has no runtime module.
  """
  @spec runtime_type(atom()) :: String.t() | nil
  def runtime_type(type_id) do
    case runtime_module(type_id) do
      nil -> nil
      mod -> mod.metadata().id
    end
  end

  @doc "Returns node type definitions filtered by category."
  @spec by_category(:source | :filter | :analyze | :logic | :output) :: [type_def()]
  def by_category(category) do
    @node_types
    |> Map.values()
    |> Enum.filter(&(&1.category == category))
  end

  @doc "Returns all node types that have runtime modules."
  @spec executable_types() :: [type_def()]
  def executable_types do
    @node_types
    |> Map.values()
    |> Enum.filter(&(&1.runtime_module != nil))
  end

  @doc """
  Returns all runtime modules from the catalog.

  Used by the Application to register all builtin nodes in the Registry at startup.
  """
  @spec runtime_modules() :: [module()]
  def runtime_modules do
    @node_types
    |> Map.values()
    |> Enum.map(& &1.runtime_module)
    |> Enum.reject(&is_nil/1)
  end
end
