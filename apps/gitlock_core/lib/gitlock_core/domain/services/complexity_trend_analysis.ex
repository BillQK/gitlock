defmodule GitlockCore.Domain.Services.ComplexityTrendAnalysis do
  @moduledoc """
  Analyzes complexity trends over time for hotspot files.

  This is the "X-Ray" from Tornhill's Software Design X-Rays:
  instead of a single complexity snapshot, it reveals how complexity
  has evolved — whether a hotspot is stable, growing, or improving.

  The analysis works by:
  1. Identifying the top N hotspot files
  2. Sampling commits at regular intervals across the repository history
  3. Retrieving file content at each sample point via `git show`
  4. Running complexity analysis on each historical version
  5. Producing a time series per file showing the trajectory

  ## Sampling strategy

  Rather than analyzing every commit (prohibitively expensive), we sample
  at monthly intervals. For a 2-year history with 15 files, this yields
  ~24 × 15 = 360 complexity calculations — completing in seconds.
  """

  alias GitlockCore.Domain.Values.{ComplexityTrend, Hotspot}
  alias GitlockCore.Domain.Services.HotspotDetection
  alias GitlockCore.Domain.Entities.Commit
  alias GitlockCore.Infrastructure.GitRepository
  alias GitlockCore.Adapters.Complexity.DispatchAnalyzer

  require Logger

  @default_max_files 15
  @default_interval_days 30

  # File extensions that have real complexity analyzers
  @analyzable_extensions [".ex", ".exs", ".js", ".jsx", ".ts", ".tsx", ".py"]

  @type option ::
          {:max_files, pos_integer()}
          | {:interval_days, pos_integer()}
          | {:progress_fn, (String.t() -> :ok)}

  @doc """
  Analyzes complexity trends for the hottest files in a repository.

  ## Parameters
    * `commits` - Parsed commit history
    * `repo_path` - Path to the git repository (for `git show`)
    * `opts` - Options:
      * `:max_files` - Number of hotspot files to analyze (default: #{@default_max_files})
      * `:interval_days` - Days between sample points (default: #{@default_interval_days})
      * `:progress_fn` - Optional callback for status updates

  ## Returns
    List of `%ComplexityTrend{}` sorted by absolute complexity change (biggest movers first)
  """
  @spec analyze([Commit.t()], String.t(), [option()]) :: [ComplexityTrend.t()]
  def analyze(commits, repo_path, opts \\ []) do
    max_files = Keyword.get(opts, :max_files, @default_max_files)
    interval_days = Keyword.get(opts, :interval_days, @default_interval_days)
    progress_fn = Keyword.get(opts, :progress_fn, fn _ -> :ok end)

    # 1. Find top hotspot files, filtered to analyzable languages
    hotspots =
      commits
      |> HotspotDetection.detect_hotspots()
      |> filter_analyzable()
      |> Enum.take(max_files)

    if hotspots == [] do
      []
    else
      progress_fn.("Analyzing trends for #{length(hotspots)} hotspot files")

      # 2. Build sample dates
      sample_dates = build_sample_dates(commits, interval_days)
      progress_fn.("Sampling #{length(sample_dates)} time points")

      # 3. Resolve sample dates to commit SHAs
      sample_revisions = resolve_sample_revisions(repo_path, sample_dates)

      # 4. For each file, collect complexity at each sample point
      hotspots
      |> Enum.with_index()
      |> Enum.map(fn {%Hotspot{entity: entity}, idx} ->
        progress_fn.("X-ray #{idx + 1}/#{length(hotspots)}: #{Path.basename(entity)}")
        points = collect_file_trend(repo_path, entity, sample_revisions)
        ComplexityTrend.from_points(entity, points)
      end)
      |> Enum.filter(fn trend -> trend.num_samples >= 2 end)
      |> Enum.sort_by(fn trend -> abs(trend.complexity_change) end, :desc)
    end
  end

  @doc """
  Builds a list of sample dates spanning the commit history at regular intervals.
  """
  @spec build_sample_dates([Commit.t()], pos_integer()) :: [Date.t()]
  def build_sample_dates(commits, interval_days) do
    dates = Enum.map(commits, & &1.date) |> Enum.sort(Date)
    earliest = List.first(dates)
    latest = List.last(dates)

    if earliest == nil or latest == nil or Date.compare(earliest, latest) == :eq do
      if latest, do: [latest], else: []
    else
      build_date_series(earliest, latest, interval_days)
    end
  end

  # ── Private ──────────────────────────────────────────────────

  defp filter_analyzable(hotspots) do
    Enum.filter(hotspots, fn %Hotspot{entity: entity} ->
      Path.extname(entity) in @analyzable_extensions
    end)
  end

  defp build_date_series(from, to, interval_days) do
    Stream.unfold(from, fn current ->
      if Date.compare(current, to) == :gt do
        nil
      else
        {current, Date.add(current, interval_days)}
      end
    end)
    |> Enum.to_list()
    |> then(fn dates ->
      # Always include the latest date if not already there
      if List.last(dates) != to, do: dates ++ [to], else: dates
    end)
  end

  defp resolve_sample_revisions(repo_path, sample_dates) do
    sample_dates
    |> Enum.map(fn date ->
      case GitRepository.commit_at_date(repo_path, date) do
        {:ok, sha} -> {date, sha}
        {:error, _} -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(fn {_date, sha} -> sha end)
  end

  defp collect_file_trend(repo_path, file_path, sample_revisions) do
    sample_revisions
    |> Enum.map(fn {date, sha} ->
      case analyze_file_at_revision(repo_path, sha, file_path) do
        {:ok, metrics} ->
          %{
            date: date,
            revision: sha,
            complexity: metrics.cyclomatic_complexity,
            loc: metrics.loc
          }

        {:error, _} ->
          # File didn't exist at this revision or unsupported — skip
          nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp analyze_file_at_revision(repo_path, sha, file_path) do
    with {:ok, content} <- GitRepository.file_at_revision(repo_path, sha, file_path),
         {:ok, metrics} <- DispatchAnalyzer.analyze_content(content, file_path) do
      {:ok, metrics}
    end
  rescue
    e ->
      Logger.debug(
        "Complexity analysis failed for #{file_path}@#{String.slice(sha, 0..7)}: #{Exception.message(e)}"
      )

      {:error, :analysis_failed}
  end
end
