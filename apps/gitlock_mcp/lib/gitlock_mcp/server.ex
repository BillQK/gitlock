defmodule GitlockMCP.Server do
  @moduledoc """
  MCP Server that exposes Gitlock's codebase intelligence to AI agents.

  Runs as streamable HTTP inside the Phoenix app. Tools are registered
  dynamically on init, and tool calls are dispatched to the Cache.
  """
  use Hermes.Server,
    name: "gitlock",
    version: "0.1.0",
    capabilities: [:tools]

  alias Hermes.Server.Response
  require Logger

  @impl true
  def init(_client_info, frame) do
    {:ok,
     frame
     |> register_tool("gitlock_assess_file",
       input_schema: %{
         file_path: {:required, :string, description: "Path to the file relative to repo root"}
       },
       description:
         "Assess the risk of modifying a specific file. Returns risk score, ownership, temporal coupling, and recommendations. Call this BEFORE modifying any file.",
       annotations: %{read_only: true}
     )
     |> register_tool("gitlock_hotspots",
       input_schema: %{
         directory:
           {:optional, :string,
            description: "Directory to filter (e.g. lib/payments). Omit for entire repo."},
         limit: {:optional, :integer, description: "Max results (default: 10)"}
       },
       description:
         "Find the riskiest files in the repository or a directory. Returns files ranked by risk score (change frequency × complexity).",
       annotations: %{read_only: true}
     )
     |> register_tool("gitlock_file_ownership",
       input_schema: %{
         file_path: {:required, :string, description: "Path to the file relative to repo root"}
       },
       description:
         "Check who owns a file and whether it's a knowledge silo. Returns primary author, ownership percentage, and bus factor risk.",
       annotations: %{read_only: true}
     )
     |> register_tool("gitlock_find_coupling",
       input_schema: %{
         file_path: {:required, :string, description: "Path to the file relative to repo root"},
         min_coupling:
           {:optional, :integer,
            description: "Minimum coupling percentage to include (default: 30)"}
       },
       description:
         "Find files that historically change together with a given file. If you modify a file, its coupled files may also need updating.",
       annotations: %{read_only: true}
     )
     |> register_tool("gitlock_review_pr",
       input_schema: %{
         changed_files:
           {:required, {:array, :string}, description: "List of file paths that were modified"}
       },
       description:
         "Analyze a set of changed files as a PR. Returns overall risk, per-file assessments, missing coupled files, and suggested reviewers. Call AFTER completing changes or before submitting.",
       annotations: %{read_only: true}
     )
     |> register_tool("gitlock_repo_summary",
       input_schema: %{},
       description:
         "Get a high-level overview of repository health. Returns hotspot counts, knowledge silos, coupling pairs, and riskiest directories. Call when first working with a codebase.",
       annotations: %{read_only: true}
     )}
  end

  @impl true
  def handle_tool_call("gitlock_assess_file", %{file_path: file_path}, frame) do
    case GitlockMCP.Cache.assess_file(file_path) do
      {:ok, result} -> {:reply, text_response(format_assess_file(result)), frame}
      {:error, reason} -> {:reply, error_response(inspect(reason)), frame}
    end
  end

  def handle_tool_call("gitlock_hotspots", params, frame) do
    opts = %{
      directory: Map.get(params, :directory) || Map.get(params, "directory"),
      limit: to_integer(Map.get(params, :limit) || Map.get(params, "limit"), 10)
    }

    case GitlockMCP.Cache.hotspots(opts) do
      {:ok, result} -> {:reply, text_response(format_hotspots(result)), frame}
      {:error, reason} -> {:reply, error_response(inspect(reason)), frame}
    end
  end

  def handle_tool_call("gitlock_file_ownership", %{file_path: file_path}, frame) do
    case GitlockMCP.Cache.file_ownership(file_path) do
      {:ok, result} -> {:reply, text_response(format_ownership(result)), frame}
      {:error, reason} -> {:reply, error_response(inspect(reason)), frame}
    end
  end

  def handle_tool_call("gitlock_find_coupling", params, frame) do
    file_path = params[:file_path] || params["file_path"]

    min_coupling =
      to_integer(Map.get(params, :min_coupling) || Map.get(params, "min_coupling"), 30)

    case GitlockMCP.Cache.find_coupling(file_path, min_coupling) do
      {:ok, result} -> {:reply, text_response(format_coupling(result)), frame}
      {:error, reason} -> {:reply, error_response(inspect(reason)), frame}
    end
  end

  def handle_tool_call("gitlock_review_pr", params, frame) do
    files = params[:changed_files] || params["changed_files"]
    files = if is_binary(files), do: Jason.decode!(files), else: files

    case GitlockMCP.Cache.review_pr(files) do
      {:ok, result} -> {:reply, text_response(format_review(result)), frame}
      {:error, reason} -> {:reply, error_response(inspect(reason)), frame}
    end
  end

  def handle_tool_call("gitlock_repo_summary", _params, frame) do
    case GitlockMCP.Cache.repo_summary() do
      {:ok, result} -> {:reply, text_response(format_summary(result)), frame}
      {:error, reason} -> {:reply, error_response(inspect(reason)), frame}
    end
  end

  # ── Formatters ───────────────────────────────────────────────

  defp format_assess_file(a) do
    coupled =
      Enum.map_join(a.coupled_files, "\n", fn c ->
        "  - #{c.file} (#{c.coupling_pct}% co-change)"
      end)

    ownership =
      if a.ownership do
        o = a.ownership
        "Owner: #{o.main_author} (#{o.ownership_pct}%) — #{o.silo_risk} silo risk"
      else
        "No ownership data"
      end

    """
    ## #{a.file}
    Risk: #{a.risk_level} (score: #{a.risk_score}/100)
    Revisions: #{a.revisions} | Complexity: #{a.complexity} | LOC: #{a.loc}
    #{ownership}
    #{if coupled != "", do: "Coupled files:\n#{coupled}", else: "No strong coupling detected"}

    Recommendation: #{a.recommendation}
    """
    |> String.trim()
  end

  defp format_hotspots(%{hotspots: hotspots, summary: summary}) do
    rows =
      Enum.map_join(hotspots, "\n", fn h ->
        "- #{h.file} — risk: #{h.risk_score} (#{h.risk_level}), #{h.revisions} revisions, complexity: #{h.complexity}"
      end)

    "## Hotspots\n#{summary}\n\n#{rows}"
  end

  defp format_ownership(%{status: "no_data"} = r), do: r.message

  defp format_ownership(r) do
    """
    ## #{r.file}
    Primary author: #{r.main_author} (#{r.ownership_pct}% of commits)
    Contributors: #{r.total_authors} | Total commits: #{r.total_commits}
    Risk level: #{r.risk_level}

    #{r.recommendation}
    """
    |> String.trim()
  end

  defp format_coupling(%{coupled_files: [], recommendation: rec}), do: rec

  defp format_coupling(%{file: file, coupled_files: coupled, recommendation: rec}) do
    rows =
      Enum.map_join(coupled, "\n", fn c ->
        "- #{c.file} — #{c.coupling_pct}% co-change rate (#{c.co_changes} shared commits)"
      end)

    "## Files coupled with #{file}\n#{rows}\n\n#{rec}"
  end

  defp format_review(r) do
    files =
      Enum.map_join(r.file_assessments, "\n", fn a ->
        "- #{a.file} — risk: #{a.risk_score} (#{a.risk_level})"
      end)

    missing =
      if length(r.missing_coupled_files) > 0 do
        "\n\nPotentially missing coupled files:\n" <>
          Enum.map_join(r.missing_coupled_files, "\n", fn m ->
            "- #{m.file} (#{m.coupling_pct}% coupled to #{m.coupled_to})"
          end)
      else
        ""
      end

    reviewers =
      if length(r.suggested_reviewers) > 0 do
        "\n\nSuggested reviewers: #{Enum.join(r.suggested_reviewers, ", ")}"
      else
        ""
      end

    "## PR Risk Assessment: #{r.overall_risk}\n#{files}#{missing}#{reviewers}\n\n#{r.recommendation}"
  end

  defp format_summary(r) do
    counts = format_hotspot_counts(r.hotspot_count)

    areas =
      if length(r.riskiest_areas) > 0 do
        "\n\nRiskiest areas:\n" <>
          Enum.map_join(r.riskiest_areas, "\n", fn a ->
            "- #{a.directory}/ — avg risk: #{a.avg_risk}, #{a.hotspot_files} hotspot files"
          end)
      else
        ""
      end

    """
    ## Repository Health Summary
    Files: #{r.total_files} | Commits: #{r.total_commits}
    Hotspots: #{counts}
    Knowledge silos: #{r.knowledge_silos} high-risk
    High coupling pairs: #{r.high_coupling_pairs}
    #{areas}

    #{r.summary}
    """
    |> String.trim()
  end

  defp to_integer(nil, default), do: default
  defp to_integer(val, _default) when is_integer(val), do: val

  defp to_integer(val, default) when is_binary(val) do
    case Integer.parse(val) do
      {n, _} -> n
      :error -> default
    end
  end

  defp to_integer(_, default), do: default

  defp text_response(text) do
    Response.tool() |> Response.text(text)
  end

  defp error_response(message) do
    Response.tool() |> Response.error(message)
  end

  defp format_hotspot_counts(counts) do
    parts =
      [{"high", "critical"}, {"medium", "medium"}, {"low", "low"}]
      |> Enum.map(fn {key, label} -> {Map.get(counts, key, 0), label} end)
      |> Enum.reject(fn {c, _} -> c == 0 end)
      |> Enum.map(fn {c, l} -> "#{c} #{l}" end)

    case parts do
      [] -> "none"
      _ -> Enum.join(parts, ", ")
    end
  end
end
