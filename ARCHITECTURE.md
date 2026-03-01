# Gitlock Architecture

## System Overview

Gitlock is a repository intelligence platform that applies behavioral code analysis to help engineering teams understand their codebases through git history forensics. It's built as an Elixir umbrella application with four apps.

```
┌──────────────────────────────────────────────────────────────────┐
│                        gitlock (umbrella)                        │
│                                                                  │
│  ┌──────────────┐  ┌──────────────────┐                         │
│  │ gitlock_cli   │  │  gitlock_phx     │                         │
│  │ (CLI entry)   │  │  (Web + DB)      │                         │
│  └──────┬───────┘  └────────┬─────────┘                         │
│         │                   │                                    │
│         │    ┌──────────────┴──────────────┐                     │
│         │    │     gitlock_workflows       │                     │
│         │    │  Pipeline model + Executor  │                     │
│         │    └──────────────┬──────────────┘                     │
│         │                   │                                    │
│         └───────────┬───────┘                                    │
│                     │                                            │
│         ┌───────────┴───────────┐                                │
│         │    gitlock_core       │                                │
│         │  (analysis engine)    │                                │
│         └───────────────────────┘                                │
└──────────────────────────────────────────────────────────────────┘
```

## Dependency Direction

```
gitlock_cli ──→ gitlock_core
                     ↑
gitlock_phx ──→ gitlock_workflows ──→ gitlock_core
```

- `gitlock_core` depends on nothing (pure analysis engine)
- `gitlock_workflows` depends on `gitlock_core` (executor maps nodes to use cases)
- `gitlock_phx` depends on `gitlock_workflows` (pipeline model + execution) and `gitlock_core` (direct analysis for landing page demo)
- `gitlock_cli` depends on `gitlock_core` (direct use case invocation)

---

## App Responsibilities

### gitlock_core — Analysis Engine

Hexagonal architecture. Pure domain logic for behavioral code analysis.

```
gitlock_core/
├── application/          # Use case orchestrators
│   ├── use_case.ex       # Base behaviour + execute/2 macro
│   ├── use_case_factory.ex
│   └── use_cases/        # 7 analysis types
│
├── domain/
│   ├── entities/         # Core domain objects (Commit, Author)
│   ├── services/         # Pure analysis algorithms
│   └── values/           # Value objects (Hotspot, FileHistory, etc.)
│
├── ports/                # Interface contracts (behaviours)
├── adapters/             # Port implementations (git, reporters, complexity)
└── infrastructure/       # Workspace management, adapter registry
```

**Public API:**

```elixir
GitlockCore.investigate(:hotspots, repo_path, options)
# => {:ok, result} | {:error, reason}

GitlockCore.available_investigations()
# => [:hotspots, :couplings, :knowledge_silos, :code_age, :blast_radius, :coupled_hotspots, :summary]
```

Each use case follows: `resolve_dependencies → run_domain_logic → format_result`.

#### Node Engine Runtime (feature/node-engine branch)

A more sophisticated execution system exists on `feature/node-engine` inside `gitlock_core/runtime/`. This is a proper DAG execution engine with:

```
runtime/
├── node.ex               # Behaviour: metadata/0, execute/3, validate_parameters/1
├── engine.ex             # GenServer: execution lifecycle, async monitoring
├── workflow.ex           # Workflow struct, Reactor compilation, n8n-compatible JSON
├── context.ex            # Execution context: variables, logging, metrics, temp storage
├── registry.ex           # GenServer: node discovery, registration, search
├── validator.ex          # Structural validation, cycle detection, port compatibility
├── nodes/
│   ├── triggers/git_commits.ex    # Source: fetches commits via VCS adapter
│   ├── analysis/hotspot.ex        # Wraps HotspotDetection domain service
│   ├── analysis/complexity.ex     # Wraps DispatchAnalyzer
│   ├── transform/extract_field.ex # Data reshaping between nodes
│   └── output/csv_export.ex       # File output
└── runtime_supervisor.ex          # Supervises Registry + Engine
```

**Key capabilities not in main:**
- True DAG-based data flow (nodes pass data through ports)
- Compiles workflows to Reactor instances for execution
- Node behaviour allows extensible, pluggable analysis nodes
- Execution context with variables, metrics, and logging
- Comprehensive validation (cycle detection, port type checking, orphan detection)
- 161 tests across all runtime modules

**Status:** This has been moved to `gitlock_workflows/runtime/` and converged with the visual pipeline model. See PROGRESS.md for details.

### gitlock_workflows — Pipeline Model + Execution

Visual workflow system, DAG execution engine, and the bridge between them.

```
gitlock_workflows/
├── pipeline.ex           # Visual DAG: nodes, edges, ports
├── node.ex / edge.ex / port.ex  # Visual model structs
├── node_catalog.ex       # Available node types + use_case_key
├── compiler.ex           # Pipeline → Runtime.Workflow → Reactor
├── executor.ex           # DAG executor: compile, topo-sort, execute with data flow
├── serializer.ex         # Pipeline ↔ JSON for DB/UI
├── templates.ex          # Pre-built pipeline configurations
├── application.ex        # OTP app, starts RuntimeSupervisor
├── runtime_supervisor.ex  # Supervises Registry + Engine
└── runtime/
    ├── node.ex           # Behaviour: metadata/execute/validate_parameters
    ├── engine.ex         # GenServer: execution lifecycle, async monitoring
    ├── workflow.ex       # Workflow struct, Reactor compilation
    ├── context.ex        # Execution context (variables, logging, metrics)
    ├── registry.ex       # GenServer: node discovery + registration
    ├── validator.ex      # Cycle detection, port types, orphan detection
    └── nodes/
        ├── triggers/git_commits.ex
        ├── analysis/{hotspot,coupling,knowledge_silo,code_age,
        │                 coupled_hotspot,complexity,summary}.ex
        ├── transform/extract_field.ex
        └── output/csv_export.ex
```

**Execution path:**
Pipeline → `Compiler.to_workflow/2` → Runtime.Workflow → topological sort → execute nodes in order

The Executor compiles the visual Pipeline into a Runtime Workflow, sorts nodes topologically,
then executes them in dependency order. Data flows through port connections — the git trigger
fetches commits once and all downstream analyzers receive them through the DAG.

### Converged Architecture

The visual pipeline model and the runtime engine now live together in `gitlock_workflows`:

| Layer | Purpose | Key modules |
|-------|---------|-------------|
| **Visual** | UI model, DB persistence | Pipeline, Node, Edge, Port, NodeCatalog, Serializer |
| **Bridge** | Conversion between layers | Compiler (Pipeline → Workflow → Reactor) |
| **Runtime** | DAG execution engine | Engine, Registry, Validator, Context, Workflow |
| **Nodes** | Concrete analysis steps | 10 runtime nodes wrapping gitlock_core domain services |

### gitlock_phx — Phoenix Web Application

Web interface, persistence, and user management.

```
gitlock_phx/
├── accounts/             # User auth (phx.gen.auth)
├── pipelines/
│   ├── saved_pipeline.ex # Ecto schema — pipeline config as JSONB
│   └── pipeline_run.ex   # Ecto schema — execution history
├── pipelines.ex          # Context — CRUD, hydration, template seeding
│
└── web/
    ├── live/
    │   ├── analyze_live.ex          # Single-URL analysis entry point
    │   ├── workflow_live.ex         # Visual pipeline builder (SvelteFlow)
    │   └── hotspots_preview_live.ex # Landing page demo
    └── ...
```

**Database schema:**

```
pipelines
├── id (bigint, PK)
├── user_id (FK → users, nullable for templates)
├── name (string)
├── description (text)
├── config (jsonb) ← serialized Pipeline struct
├── is_template (boolean)
└── timestamps

pipeline_runs
├── id (bigint, PK)
├── pipeline_id (FK → pipelines)
├── user_id (FK → users)
├── repo_url (string)
├── status (string: running | completed | failed)
├── results (jsonb) ← node results keyed by node_id
├── error (text)
├── started_at / completed_at (utc_datetime)
└── timestamps
```

### gitlock_cli — Command Line Interface

Thin CLI entry point. Parses arguments, delegates to `gitlock_core` use cases directly.

---

## Key Design Decisions

### Pipelines stored as JSONB blobs (not normalized)

The entire pipeline graph is serialized into a single JSONB column. Pipeline structure changes frequently during editing and is always loaded/saved as a unit.

### Hexagonal architecture in gitlock_core

Ports define contracts, adapters implement them. Swapping git implementations, adding reporters, or mocking for tests doesn't touch domain logic.

### Workflow execution via message passing

The Executor sends `{:pipeline_progress, ...}` messages to a caller PID. This works naturally with LiveView's `handle_info`. For sync mode (CLI/tests), the caller is `nil` and notifications are no-ops.

### Single source of truth for templates

`GitlockWorkflows.Templates` defines all pipeline templates. `GitlockPhx.Pipelines.seed_templates!/0` delegates to it.
