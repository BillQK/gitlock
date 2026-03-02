defmodule GitlockWorkflows.Templates do
  @moduledoc """
  Pre-built pipeline templates for common analysis patterns.

  Each template returns a fully wired `%Pipeline{}` ready to execute.
  Templates are the single source of truth — `GitlockPhx.Pipelines.seed_templates!/0`
  delegates here for database seeding.
  """

  alias GitlockWorkflows.{Pipeline, Node, Edge}

  @type template_info :: %{
          id: atom(),
          name: String.t(),
          description: String.t()
        }

  @doc "Lists available templates with metadata."
  @spec list() :: [template_info()]
  def list do
    [
      %{
        id: :full_analysis,
        name: "Full Analysis",
        description: "Complete codebase health analysis with all analyzers"
      },
      %{
        id: :hotspot_scan,
        name: "Hotspot Quick Scan",
        description: "Find high-risk files fast"
      },
      %{
        id: :knowledge_risk,
        name: "Knowledge Risk Assessment",
        description: "Identify bus factor risks and coupling patterns"
      },
      %{
        id: :codebase_intelligence,
        name: "Codebase Intelligence Report",
        description:
          "Advanced multi-stage pipeline: analyzes hotspots, couplings, knowledge silos, and code age, " <>
            "then filters, sorts, groups, aggregates, and merges results into actionable findings"
      }
    ]
  end

  @doc "Builds a pipeline from a template id."
  @spec build(atom()) :: Pipeline.t() | {:error, :unknown_template}
  def build(:full_analysis), do: full_analysis()
  def build(:hotspot_scan), do: hotspot_scan()
  def build(:knowledge_risk), do: knowledge_risk()
  def build(:codebase_intelligence), do: codebase_intelligence()
  # Keep old names as aliases for backward compatibility
  def build(:team_health), do: knowledge_risk()
  def build(_), do: {:error, :unknown_template}

  # ── Full Analysis ────────────────────────────────────────────

  defp full_analysis do
    git = Node.new(:git_log, position: {100, 300})
    hotspots = Node.new(:hotspot_detection, position: {380, 80})
    couplings = Node.new(:coupling_detection, position: {380, 200})
    silos = Node.new(:knowledge_silo_detection, position: {380, 320})
    age = Node.new(:code_age_analysis, position: {380, 440})
    blast = Node.new(:blast_radius_analysis, position: {380, 560})
    coupled = Node.new(:coupled_hotspot_analysis, position: {380, 680})
    summary_node = Node.new(:summary, position: {700, 300})

    Pipeline.new("Full Analysis",
      description: "Complete codebase health analysis with all analyzers"
    )
    |> add_nodes([git, hotspots, couplings, silos, age, blast, coupled, summary_node])
    |> connect(git, hotspots)
    |> connect(git, couplings)
    |> connect(git, silos)
    |> connect(git, age)
    |> connect(git, blast)
    |> connect(git, coupled)
    |> connect(git, summary_node)
  end

  # ── Hotspot Quick Scan ───────────────────────────────────────

  defp hotspot_scan do
    git = Node.new(:git_log, position: {100, 200})
    hotspots = Node.new(:hotspot_detection, position: {380, 200})
    summary_node = Node.new(:summary, position: {380, 340})

    Pipeline.new("Hotspot Quick Scan", description: "Find high-risk files fast")
    |> add_nodes([git, hotspots, summary_node])
    |> connect(git, hotspots)
    |> connect(git, summary_node)
  end

  # ── Knowledge Risk Assessment ────────────────────────────────

  defp knowledge_risk do
    git = Node.new(:git_log, position: {100, 250})
    silos = Node.new(:knowledge_silo_detection, position: {380, 160})
    couplings = Node.new(:coupling_detection, position: {380, 340})
    summary_node = Node.new(:summary, position: {660, 250})

    Pipeline.new("Knowledge Risk Assessment",
      description: "Identify bus factor risks and coupling patterns"
    )
    |> add_nodes([git, silos, couplings, summary_node])
    |> connect(git, silos)
    |> connect(git, couplings)
    |> connect(git, summary_node)
  end

  # ── Codebase Intelligence Report ─────────────────────────────
  #
  #  An advanced pipeline using every logic node type.
  #
  #  ┌─────────────────── HOTSPOT PATH ────────────────────────────────┐
  #  │ Hotspots → IF(revisions≥50) ──true──→ Sort(risk desc) → Limit(20)──→ Merge.a ──→ (combined)
  #  │                              ──false─→ Aggregate(stats)              ↑
  #  │                                                                     │
  #  ├─────────────────── COUPLING PATH ───────────────────────────────│
  #  │ Couplings → Filter(degree>2) ──kept─→ RemoveDups → Sort → Limit(15)→ Merge.b
  #  │                                                                     │
  #  ├─────────────────── KNOWLEDGE PATH ──────────────────────────────│
  #  │ Silos → GroupBy(main_author)                                       │
  #  │                                                                     │
  #  ├─────────────────── CODE AGE PATH ───────────────────────────────│
  #  │ Code Age → Switch(risk_factor: high,medium,low)                    │
  #  │             case_0(high) → Sort(last_modified) → Limit(10)         │
  #  │                                                                     │
  #  └─────────────────── SUMMARY ─────────────────────────────────────┘
  #    Summary
  #

  defp codebase_intelligence do
    # Column 1 (x=80): Source
    git = Node.new(:git_log, position: {80, 360})

    # Column 2 (x=380): Analyzers
    hotspots = Node.new(:hotspot_detection, position: {380, 60})
    couplings = Node.new(:coupling_detection, position: {380, 240})
    silos = Node.new(:knowledge_silo_detection, position: {380, 440})
    age = Node.new(:code_age_analysis, position: {380, 600})
    summary_node = Node.new(:summary, position: {380, 760})

    # Column 3 (x=700): First logic stage
    if_node =
      Node.new(:if_condition,
        position: {700, 60},
        config: %{"field" => "revisions", "operator" => "gte", "value" => "50"}
      )

    filter_node =
      Node.new(:filter,
        position: {700, 240},
        config: %{"field" => "degree", "operator" => "gt", "value" => "2"}
      )

    group_node =
      Node.new(:group_by,
        position: {700, 440},
        config: %{"field" => "main_author"}
      )

    switch_node =
      Node.new(:switch,
        position: {700, 600},
        config: %{"field" => "risk_factor", "cases" => "high,medium,low"}
      )

    # Column 4 (x=1020): Second logic stage
    sort_hotspots =
      Node.new(:sort,
        position: {1020, 20},
        config: %{"field" => "risk_score", "direction" => "desc"}
      )

    agg_low_risk =
      Node.new(:aggregate,
        position: {1020, 120},
        config: %{"operations" => "count,avg:risk_score,max:complexity,sum:revisions"}
      )

    dedup_couplings =
      Node.new(:remove_duplicates,
        position: {1020, 240},
        config: %{"field" => "entity"}
      )

    sort_stale =
      Node.new(:sort,
        position: {1020, 600},
        config: %{"field" => "last_modified", "direction" => "asc"}
      )

    # Column 5 (x=1320): Third logic stage
    limit_hotspots =
      Node.new(:limit,
        position: {1320, 20},
        config: %{"count" => "20", "from" => "start"}
      )

    sort_couplings =
      Node.new(:sort,
        position: {1320, 240},
        config: %{"field" => "degree", "direction" => "desc"}
      )

    limit_stale =
      Node.new(:limit,
        position: {1320, 600},
        config: %{"count" => "10", "from" => "start"}
      )

    # Column 6 (x=1620): Final stage
    limit_couplings =
      Node.new(:limit,
        position: {1620, 240},
        config: %{"count" => "15", "from" => "start"}
      )

    merge_node =
      Node.new(:merge,
        position: {1620, 120},
        config: %{"mode" => "append"}
      )

    Pipeline.new("Codebase Intelligence Report",
      description:
        "Advanced multi-stage pipeline: analyzes hotspots, couplings, knowledge silos, and code age, " <>
          "then filters, sorts, groups, aggregates, and merges results into actionable findings"
    )
    |> add_nodes([
      git,
      hotspots,
      couplings,
      silos,
      age,
      summary_node,
      # Logic stage 1
      if_node,
      filter_node,
      group_node,
      switch_node,
      # Logic stage 2
      sort_hotspots,
      agg_low_risk,
      dedup_couplings,
      sort_stale,
      # Logic stage 3
      limit_hotspots,
      sort_couplings,
      limit_stale,
      # Final
      limit_couplings,
      merge_node
    ])
    # ── Git Log → all analyzers ──
    |> connect(git, hotspots)
    |> connect(git, couplings)
    |> connect(git, silos)
    |> connect(git, age)
    |> connect(git, summary_node)
    # ── Hotspot path: IF → Sort → Limit → Merge.a ──
    |> connect(hotspots, if_node)
    |> connect_ports(if_node, "true", sort_hotspots, "items")
    |> connect_ports(if_node, "false", agg_low_risk, "items")
    |> connect(sort_hotspots, limit_hotspots)
    |> connect_ports(limit_hotspots, "items", merge_node, "items_a")
    # ── Coupling path: Filter → Dedup → Sort → Limit → Merge.b ──
    |> connect(couplings, filter_node)
    |> connect_ports(filter_node, "kept", dedup_couplings, "items")
    |> connect(dedup_couplings, sort_couplings)
    |> connect(sort_couplings, limit_couplings)
    |> connect_ports(limit_couplings, "items", merge_node, "items_b")
    # ── Knowledge path: Silos → Group By ──
    |> connect(silos, group_node)
    # ── Code age path: Switch → Sort(high risk) → Limit ──
    |> connect(age, switch_node)
    |> connect_ports(switch_node, "case_0", sort_stale, "items")
    |> connect(sort_stale, limit_stale)
  end

  # ── Wiring helpers ───────────────────────────────────────────

  defp add_nodes(pipeline, nodes) do
    Enum.reduce(nodes, pipeline, &Pipeline.add_node(&2, &1))
  end

  @doc false
  # Connect source node's first output port to target node's first input port
  defp connect(pipeline, source, target) do
    [out | _] = source.output_ports
    [inp | _] = target.input_ports
    edge = Edge.new(source.id, out.id, target.id, inp.id)
    Pipeline.add_edge(pipeline, edge)
  end

  # Connect a specific named output port to a specific named input port
  defp connect_ports(pipeline, source, out_name, target, in_name) do
    out_port = Enum.find(source.output_ports, &(&1.name == out_name))
    in_port = Enum.find(target.input_ports, &(&1.name == in_name))

    if out_port && in_port do
      edge = Edge.new(source.id, out_port.id, target.id, in_port.id)
      Pipeline.add_edge(pipeline, edge)
    else
      pipeline
    end
  end
end
