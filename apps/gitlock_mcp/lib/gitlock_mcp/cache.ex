defmodule GitlockMCP.Cache do
  @moduledoc """
  Holds pre-computed analysis data for the current repository.

  On first access, indexes the repo by parsing git history and running
  all analyses. Results are cached in memory — subsequent tool calls
  return instantly.

  The cache auto-detects the repo from the current working directory.
  """
  use GenServer
  require Logger

  defstruct [
    :repo_path,
    :indexed_at,
    :commits,
    :hotspots,
    :hotspot_index,
    :couplings,
    :coupling_index,
    :knowledge_silos,
    :silo_index,
    :complexity_map,
    :code_age,
    :summary,
    status: :idle
  ]

  # ── Client API ───────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Ensures the cache is populated. Blocks until indexing completes."
  def ensure_indexed(repo_path \\ nil) do
    GenServer.call(__MODULE__, {:ensure_indexed, repo_path}, :infinity)
  end

  @doc "Returns the risk assessment for a single file."
  def assess_file(file_path) do
    with :ok <- ensure_indexed() do
      GenServer.call(__MODULE__, {:assess_file, file_path})
    end
  end

  @doc "Returns the top hotspots, optionally filtered by directory."
  def hotspots(opts \\ %{}) do
    with :ok <- ensure_indexed() do
      GenServer.call(__MODULE__, {:hotspots, opts})
    end
  end

  @doc "Returns ownership info for a file."
  def file_ownership(file_path) do
    with :ok <- ensure_indexed() do
      GenServer.call(__MODULE__, {:file_ownership, file_path})
    end
  end

  @doc "Returns files temporally coupled to the given file."
  def find_coupling(file_path, min_coupling \\ 30) do
    with :ok <- ensure_indexed() do
      GenServer.call(__MODULE__, {:find_coupling, file_path, min_coupling})
    end
  end

  @doc "Reviews a set of changed files together."
  def review_pr(changed_files) do
    with :ok <- ensure_indexed() do
      GenServer.call(__MODULE__, {:review_pr, changed_files})
    end
  end

  @doc "Returns high-level repo health summary."
  def repo_summary do
    with :ok <- ensure_indexed() do
      GenServer.call(__MODULE__, :repo_summary)
    end
  end

  # ── Server Callbacks ─────────────────────────────────────────

  @impl true
  def init(_opts) do
    {:ok, %__MODULE__{}}
  end

  @impl true
  def handle_call({:ensure_indexed, repo_path}, _from, %{status: :ready} = state)
      when is_nil(repo_path) or repo_path == state.repo_path do
    {:reply, :ok, state}
  end

  def handle_call({:ensure_indexed, repo_path}, _from, state) do
    repo = repo_path || detect_repo_path()

    case GitlockMCP.Indexer.index(repo) do
      {:ok, data} ->
        new_state = %__MODULE__{
          repo_path: repo,
          indexed_at: DateTime.utc_now(),
          status: :ready,
          commits: data.commits,
          hotspots: data.hotspots,
          hotspot_index: Map.new(data.hotspots, &{&1.entity, &1}),
          couplings: data.couplings,
          coupling_index: build_coupling_index(data.couplings),
          knowledge_silos: data.knowledge_silos,
          silo_index: Map.new(data.knowledge_silos, &{&1.entity, &1}),
          complexity_map: data.complexity_map,
          code_age: data.code_age,
          summary: data.summary
        }

        Logger.info("Gitlock indexed #{repo} — #{length(data.hotspots)} hotspots, #{length(data.couplings)} coupling pairs, #{length(data.knowledge_silos)} silos")
        {:reply, :ok, new_state}

      {:error, reason} ->
        Logger.error("Gitlock indexing failed: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:assess_file, file_path}, _from, state) do
    hotspot = Map.get(state.hotspot_index, file_path)
    silo = Map.get(state.silo_index, file_path)
    coupled = Map.get(state.coupling_index, file_path, [])

    risk_score = if hotspot, do: hotspot.normalized_score, else: 0
    risk_level = cond do
      risk_score > 70 -> "critical"
      risk_score > 40 -> "high"
      risk_score > 20 -> "medium"
      true -> "low"
    end

    assessment = %{
      file: file_path,
      risk_score: round(risk_score),
      risk_level: risk_level,
      revisions: if(hotspot, do: hotspot.revisions, else: 0),
      complexity: if(hotspot, do: hotspot.complexity, else: 0),
      loc: if(hotspot, do: hotspot.loc, else: 0),
      ownership: format_ownership(silo),
      coupled_files: Enum.take(coupled, 5),
      recommendation: build_recommendation(file_path, hotspot, silo, coupled)
    }

    {:reply, {:ok, assessment}, state}
  end

  def handle_call({:hotspots, opts}, _from, state) do
    dir = opts["directory"] || opts[:directory]
    limit = opts["limit"] || opts[:limit] || 10

    results =
      state.hotspots
      |> maybe_filter_dir(dir)
      |> Enum.take(limit)
      |> Enum.map(&format_hotspot/1)

    summary_text = if dir do
      "#{dir} contains #{length(results)} hotspots"
    else
      "Repository has #{length(state.hotspots)} total hotspots, showing top #{length(results)}"
    end

    {:reply, {:ok, %{hotspots: results, summary: summary_text}}, state}
  end

  def handle_call({:file_ownership, file_path}, _from, state) do
    silo = Map.get(state.silo_index, file_path)

    if silo do
      {:reply, {:ok, format_ownership_detail(silo)}, state}
    else
      {:reply, {:ok, %{file: file_path, status: "no_data", message: "No ownership data — file may have very few commits"}}, state}
    end
  end

  def handle_call({:find_coupling, file_path, min_coupling}, _from, state) do
    coupled =
      Map.get(state.coupling_index, file_path, [])
      |> Enum.filter(&(&1.coupling_pct >= min_coupling))

    recommendation = if coupled == [] do
      "No strong temporal coupling found for #{file_path}"
    else
      top = hd(coupled)
      "#{file_path} is strongly coupled with #{top.file} (#{top.coupling_pct}% co-change rate). If you changed #{Path.basename(file_path)}, verify #{Path.basename(top.file)} still works correctly."
    end

    {:reply, {:ok, %{file: file_path, coupled_files: coupled, recommendation: recommendation}}, state}
  end

  def handle_call({:review_pr, changed_files}, _from, state) do
    file_assessments =
      Enum.map(changed_files, fn file ->
        hotspot = Map.get(state.hotspot_index, file)
        silo = Map.get(state.silo_index, file)

        %{
          file: file,
          risk_score: if(hotspot, do: round(hotspot.normalized_score), else: 0),
          risk_level: if(hotspot, do: to_string(hotspot.risk_factor), else: "low"),
          ownership: format_ownership(silo)
        }
      end)

    # Find coupled files that AREN'T in the PR
    missing_coupled =
      changed_files
      |> Enum.flat_map(fn file ->
        Map.get(state.coupling_index, file, [])
        |> Enum.filter(&(&1.coupling_pct >= 30))
        |> Enum.map(&Map.put(&1, :coupled_to, file))
      end)
      |> Enum.reject(&(&1.file in changed_files))
      |> Enum.uniq_by(& &1.file)
      |> Enum.sort_by(& &1.coupling_pct, :desc)

    # Collect suggested reviewers from knowledge silos
    reviewers =
      changed_files
      |> Enum.map(&Map.get(state.silo_index, &1))
      |> Enum.reject(&is_nil/1)
      |> Enum.map(& &1.main_author)
      |> Enum.uniq()

    overall_risk =
      case Enum.max_by(file_assessments, & &1.risk_score, fn -> %{risk_score: 0} end) do
        %{risk_score: s} when s > 70 -> "critical"
        %{risk_score: s} when s > 40 -> "high"
        %{risk_score: s} when s > 20 -> "medium"
        _ -> "low"
      end

    recommendation = build_pr_recommendation(file_assessments, missing_coupled, reviewers)

    result = %{
      overall_risk: overall_risk,
      file_assessments: file_assessments,
      missing_coupled_files: Enum.take(missing_coupled, 5),
      suggested_reviewers: reviewers,
      recommendation: recommendation
    }

    {:reply, {:ok, result}, state}
  end

  def handle_call(:repo_summary, _from, state) do
    hotspot_counts =
      state.hotspots
      |> Enum.group_by(& &1.risk_factor)
      |> Map.new(fn {level, items} -> {to_string(level), length(items)} end)

    # Find riskiest directories
    dir_risks =
      state.hotspots
      |> Enum.group_by(fn h -> h.entity |> Path.dirname() end)
      |> Enum.map(fn {dir, hotspots} ->
        avg_risk = Enum.map(hotspots, & &1.normalized_score) |> then(&(Enum.sum(&1) / length(&1)))
        %{directory: dir, avg_risk: round(avg_risk), hotspot_files: length(hotspots)}
      end)
      |> Enum.sort_by(& &1.avg_risk, :desc)
      |> Enum.take(5)

    silo_count = Enum.count(state.knowledge_silos, &(&1.risk_level == :high))
    high_coupling = Enum.count(state.couplings, &(&1.degree >= 30))

    result = %{
      total_files: length(state.hotspots),
      total_commits: length(state.commits),
      hotspot_count: hotspot_counts,
      knowledge_silos: silo_count,
      high_coupling_pairs: high_coupling,
      riskiest_areas: dir_risks,
      summary: "Codebase with #{length(state.hotspots)} tracked files, #{length(state.commits)} commits. #{Map.get(hotspot_counts, "high", 0)} critical hotspots, #{silo_count} knowledge silos, #{high_coupling} high-coupling pairs."
    }

    {:reply, {:ok, result}, state}
  end

  # ── Private Helpers ──────────────────────────────────────────

  defp detect_repo_path do
    cwd = File.cwd!()

    if File.dir?(Path.join(cwd, ".git")) do
      cwd
    else
      # Walk up to find a .git directory
      cwd
      |> Path.split()
      |> Enum.reduce_while(nil, fn _segment, _acc ->
        path = Path.join(Path.split(cwd) |> Enum.take(length(Path.split(cwd))))

        if File.dir?(Path.join(path, ".git")) do
          {:halt, path}
        else
          {:cont, nil}
        end
      end) || cwd
    end
  end

  defp build_coupling_index(couplings) do
    couplings
    |> Enum.flat_map(fn c ->
      [
        {c.entity, %{file: c.coupled, coupling_pct: c.degree, co_changes: c.average}},
        {c.coupled, %{file: c.entity, coupling_pct: c.degree, co_changes: c.average}}
      ]
    end)
    |> Enum.group_by(fn {file, _} -> file end, fn {_, data} -> data end)
    |> Map.new(fn {file, entries} ->
      {file, Enum.sort_by(entries, & &1.coupling_pct, :desc)}
    end)
  end

  defp maybe_filter_dir(hotspots, nil), do: hotspots

  defp maybe_filter_dir(hotspots, dir) do
    Enum.filter(hotspots, &String.starts_with?(&1.entity, dir))
  end

  defp format_hotspot(h) do
    %{
      file: h.entity,
      risk_score: round(h.normalized_score),
      risk_level: to_string(h.risk_factor),
      revisions: h.revisions,
      complexity: h.complexity,
      loc: h.loc
    }
  end

  defp format_ownership(nil), do: nil

  defp format_ownership(silo) do
    %{
      main_author: silo.main_author,
      ownership_pct: silo.ownership_ratio,
      total_authors: silo.num_authors,
      silo_risk: to_string(silo.risk_level)
    }
  end

  defp format_ownership_detail(silo) do
    %{
      file: silo.entity,
      main_author: silo.main_author,
      ownership_pct: silo.ownership_ratio,
      total_authors: silo.num_authors,
      total_commits: silo.num_commits,
      risk_level: to_string(silo.risk_level),
      recommendation: "#{silo.main_author} owns #{silo.ownership_ratio}% of this file. " <>
        if(silo.risk_level == :high, do: "Knowledge silo — ensure this person reviews any changes.", else: "Moderate ownership concentration.")
    }
  end

  defp build_recommendation(file_path, nil, nil, _coupled) do
    "#{file_path} has minimal change history. Low risk."
  end

  defp build_recommendation(file_path, hotspot, silo, coupled) do
    parts = []

    parts = if hotspot && hotspot.normalized_score > 70 do
      ["High-risk file — #{hotspot.revisions} revisions, complexity #{hotspot.complexity}." | parts]
    else
      parts
    end

    parts = if silo && silo.risk_level in [:high, :medium] do
      ["#{silo.main_author} owns #{silo.ownership_ratio}% — consider them as reviewer." | parts]
    else
      parts
    end

    parts = if length(coupled) > 0 do
      top = hd(coupled)
      ["Temporally coupled with #{top.file} (#{top.coupling_pct}% co-change rate)." | parts]
    else
      parts
    end

    case parts do
      [] -> "#{Path.basename(file_path)} appears stable and well-distributed."
      _ -> Enum.reverse(parts) |> Enum.join(" ")
    end
  end

  defp build_pr_recommendation(assessments, missing_coupled, reviewers) do
    high_risk = Enum.count(assessments, &(&1.risk_score > 70))
    parts = []

    parts = if high_risk > 0 do
      ["This PR touches #{high_risk} high-risk file(s)." | parts]
    else
      parts
    end

    parts = if length(missing_coupled) > 0 do
      files = Enum.map_join(missing_coupled, ", ", & &1.file)
      ["Potentially missing coupled files: #{files}." | parts]
    else
      parts
    end

    parts = if length(reviewers) > 0 do
      ["Suggested reviewers: #{Enum.join(reviewers, ", ")}." | parts]
    else
      parts
    end

    case parts do
      [] -> "Low-risk PR. No concerns detected."
      _ -> Enum.reverse(parts) |> Enum.join(" ")
    end
  end
end
