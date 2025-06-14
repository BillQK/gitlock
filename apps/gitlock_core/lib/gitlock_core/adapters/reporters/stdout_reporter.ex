defmodule GitlockCore.Adapters.Reporters.StdoutReporter do
  @moduledoc """
  STDOUT reporter for formatting analysis results.

  Displays analysis results in a human-readable format to the terminal,
  with colored output and formatted tables for better readability.
  """

  @behaviour GitlockCore.Ports.ReportPort

  alias GitlockCore.Domain.Values.{
    Hotspot,
    CouplingsMetrics,
    KnowledgeSilo,
    ChangeImpact,
    CombinedRisk
  }

  @impl GitlockCore.Ports.ReportPort
  def report(results, options \\ %{}) do
    with {:ok, validated_results} <- validate_results(results),
         {:ok, validated_options} <- validate_options(options) do
      try do
        # Determine analysis type from the data structure
        analysis_type = detect_analysis_type(validated_results)

        # Apply row limit if specified
        limited_results = apply_row_limit(validated_results, validated_options)

        # Format the output
        output =
          format_analysis(analysis_type, limited_results, validated_results, validated_options)

        {:ok, output}
      rescue
        error ->
          {:error, "Failed to generate stdout report: #{inspect(error)}"}
      end
    end
  end

  # Validation functions
  defp validate_results(results) when is_list(results), do: {:ok, results}
  defp validate_results(nil), do: {:ok, []}
  defp validate_results(_), do: {:error, "Results must be a list"}

  defp validate_options(options) when is_map(options) do
    case validate_rows_option(options) do
      {:ok, _} -> {:ok, options}
      error -> error
    end
  end

  defp validate_options(_), do: {:error, "Options must be a map"}

  defp validate_rows_option(%{rows: rows}) when is_integer(rows) and rows >= 0,
    do: {:ok, %{rows: rows}}

  defp validate_rows_option(%{rows: _rows}),
    do: {:error, "rows must be a non-negative integer"}

  defp validate_rows_option(options), do: {:ok, options}

  # Detect analysis type based on data structure
  defp detect_analysis_type([]), do: :empty

  defp detect_analysis_type([first | _]) do
    case first do
      %Hotspot{} -> :hotspots
      %CouplingsMetrics{} -> :couplings
      %KnowledgeSilo{} -> :knowledge_silos
      %CombinedRisk{} -> :coupled_hotspots
      %ChangeImpact{} -> :blast_radius
      %{} -> detect_from_map_keys(first)
      _ -> :unknown
    end
  end

  defp detect_from_map_keys(map) do
    cond do
      Map.has_key?(map, :risk_score) and Map.has_key?(map, :revisions) ->
        :hotspots

      Map.has_key?(map, :degree) and Map.has_key?(map, :coupled) ->
        :couplings

      Map.has_key?(map, :ownership_ratio) and Map.has_key?(map, :main_author) ->
        :knowledge_silos

      Map.has_key?(map, :combined_risk_score) ->
        :coupled_hotspots

      Map.has_key?(map, :impact_score) or
          (Map.has_key?(map, :risk_score) and Map.has_key?(map, :impact_severity)) ->
        :blast_radius

      Map.has_key?(map, :statistic) ->
        :summary

      true ->
        :generic
    end
  end

  defp apply_row_limit(results, %{rows: limit}) when is_integer(limit) and limit > 0 do
    Enum.take(results, limit)
  end

  defp apply_row_limit(results, _), do: results

  # Format based on analysis type
  defp format_analysis(:empty, _data, _all_data, _options) do
    "No results found"
  end

  defp format_analysis(:hotspots, data, all_data, options) do
    # Format individual hotspots with emoji indicators
    formatted_hotspots =
      if Enum.empty?(data) do
        "No hotspots found."
      else
        data
        |> Enum.map_join("\n\n", &format_single_hotspot/1)
      end

    # Summary statistics
    summary_stats = """

    Summary Statistics:
    • Files analyzed: #{length(data)}
    • High risk files: #{count_by_risk(data, :high)}
    • Medium risk files: #{count_by_risk(data, :medium)}
    • Low risk files: #{count_by_risk(data, :low)}
    • Average complexity: #{calculate_average_complexity(data)}
    """

    """
    Hotspot Analysis Results
    ========================

    #{formatted_hotspots}
    #{summary_stats}
    #{row_limit_notice(data, all_data, options)}
    """
  end

  defp format_analysis(:couplings, data, all_data, options) do
    # Format individual couplings
    formatted_couplings =
      if Enum.empty?(data) do
        "No significant couplings found."
      else
        data
        |> Enum.map_join("\n\n", &format_single_coupling/1)
      end

    # Insights section
    insights = """

    Couplings Insights:
    • Total coupled pairs: #{length(data)}
    • Strong couplings (>75%): #{count_strong_couplings(data)}
    • Medium couplings (50-75%): #{count_medium_couplings(data)}
    • Weak couplings (<50%): #{count_weak_couplings(data)}
    """

    """
    Couplings Analysis Results
    ==========================

    #{formatted_couplings}
    #{insights}
    #{row_limit_notice(data, all_data, options)}
    """
  end

  defp format_analysis(:knowledge_silos, data, all_data, options) do
    # Format individual silos with risk indicators
    formatted_silos =
      if Enum.empty?(data) do
        "No knowledge silos found."
      else
        data
        |> Enum.map_join("\n\n", &format_single_silo/1)
      end

    # Summary section
    summary = """

    Knowledge Distribution Summary:
    • Total files analyzed: #{length(data)}
    • High risk silos: #{count_silo_risk(data, :high)}
    • Medium risk silos: #{count_silo_risk(data, :medium)}
    • Low risk silos: #{count_silo_risk(data, :low)}
    • Files with single author: #{count_single_author(data)}
    """

    """
    Knowledge Silo Analysis Results
    ===============================

    #{formatted_silos}
    #{summary}
    #{row_limit_notice(data, all_data, options)}
    """
  end

  defp format_analysis(:coupled_hotspots, data, all_data, options) do
    """
    #{header("COUPLED HOTSPOTS ANALYSIS")}

    #{format_coupled_hotspots(data, options)}

    Total risky pairs: #{length(data)}
    #{row_limit_notice(data, all_data, options)}
    """
  end

  defp format_analysis(:blast_radius, data, _all_data, _options) do
    # Format individual impact analyses
    formatted_impacts =
      if Enum.empty?(data) do
        "No impact analysis available."
      else
        data
        |> Enum.map_join("\n\n", &format_single_impact/1)
      end

    """
    Change Impact Analysis Results
    ==============================

    #{formatted_impacts}
    """
  end

  defp format_analysis(:summary, data, _all_data, _options) do
    """
    Repository Summary
    ==================

    #{format_summary_stats(data)}
    """
  end

  defp format_analysis(:generic, data, all_data, options) do
    """
    Analysis Results
    ================

    #{format_generic(data, options)}

    Total results: #{length(data)}
    #{row_limit_notice(data, all_data, options)}
    """
  end

  defp format_analysis(:unknown, _data, _all_data, _options) do
    "Error: Unknown data format"
  end

  # Formatting helpers

  defp header(title) do
    separator = String.duplicate("=", String.length(title))

    """
    #{separator}
    #{title}
    #{separator}
    """
  end

  # Individual item formatters

  defp format_single_hotspot(hotspot) do
    risk_emoji =
      case get_field(hotspot, :risk_factor) do
        :high -> "🔴 HIGH RISK"
        :medium -> "🟡 Medium Risk"
        :low -> "🟢 Low Risk"
        _ -> "⚪ Unknown Risk"
      end

    """
    #{risk_emoji}: #{get_field(hotspot, :entity)}
    • #{get_field(hotspot, :revisions)} changes, complexity: #{get_field(hotspot, :complexity)}, #{format_number(get_field(hotspot, :loc))} lines
    • Risk score: #{format_float(get_field(hotspot, :risk_score))}
    """
    |> String.trim()
  end

  defp format_single_coupling(coupling) do
    trend_indicator =
      case get_field(coupling, :trend, 0) do
        t when t > 0 -> "📈 Increasing"
        t when t < 0 -> "📉 Decreasing"
        _ -> "→ Stable"
      end

    """
    #{get_field(coupling, :entity)} ⟷ #{get_field(coupling, :coupled)}
    • #{Float.round(get_field(coupling, :degree, 0.0), 1)}% coupling (#{get_field(coupling, :windows)} changes together)
    • Trend: #{trend_indicator}
    """
    |> String.trim()
  end

  defp format_single_silo(silo) do
    risk_indicator =
      case get_field(silo, :risk_level) do
        :high -> "⚠️  HIGH RISK SILO"
        :medium -> "🟡 Medium Risk Silo"
        :low -> "✓ Low Risk"
        _ -> "Unknown Risk"
      end

    ownership_info =
      if get_field(silo, :num_authors) == 1 do
        "Single developer!"
      else
        "Only #{get_field(silo, :num_authors)} contributors across #{get_field(silo, :num_commits)} commits"
      end

    """
    #{risk_indicator}: #{get_field(silo, :entity)}
    • Owner: #{get_field(silo, :main_author)} (#{get_field(silo, :ownership_ratio)}% ownership)
    • #{ownership_info}
    """
    |> String.trim()
  end

  defp format_single_impact(impact) do
    severity_indicator =
      case get_field(impact, :impact_severity, :low) do
        :high -> "🚨 CRITICAL IMPACT"
        :medium -> "⚠️  MODERATE IMPACT"
        :low -> "🟢 Low Impact"
        _ -> "Impact Level Unknown"
      end

    risk_score = get_field(impact, :risk_score, 0)
    affected_files = get_field(impact, :affected_files, [])
    affected_components = get_field(impact, :affected_components, %{})
    suggested_reviewers = get_field(impact, :suggested_reviewers, [])
    complexity = get_field(impact, :complexity, nil)
    loc = get_field(impact, :loc, nil)

    # Format basic info
    basic_info = """
    #{severity_indicator}: #{get_field(impact, :entity)}
    • Risk Score: #{format_float(risk_score)}
    • #{length(affected_files)} files affected across #{map_size(affected_components)} components
    """

    # Add suggested reviewers if present
    reviewers_info =
      if length(suggested_reviewers) > 0 do
        "\n• Suggested Reviewers: #{Enum.join(suggested_reviewers, ", ")}"
      else
        ""
      end

    # Add blast radius if there are affected files
    blast_radius =
      if length(affected_files) > 0 do
        "\n\nBlast Radius:\n#{format_affected_files(affected_files)}"
      else
        ""
      end

    # Add file metrics if available
    file_metrics =
      if complexity || loc do
        metrics = []
        metrics = if complexity, do: ["Complexity: #{complexity}" | metrics], else: metrics
        metrics = if loc, do: ["#{format_number(loc)} lines" | metrics], else: metrics

        if length(metrics) > 0 do
          "\n\nFile Metrics:\n• " <> Enum.join(metrics, ", ")
        else
          ""
        end
      else
        ""
      end

    basic_info <> reviewers_info <> blast_radius <> file_metrics
  end

  defp row_limit_notice(displayed_data, all_data, %{rows: limit})
       when is_integer(limit) and length(all_data) > limit do
    "\nShowing #{length(displayed_data)} of #{length(all_data)} results"
  end

  defp row_limit_notice(_, _, _), do: ""

  defp format_coupled_hotspots(coupled_hotspots, _options) do
    if Enum.empty?(coupled_hotspots) do
      "No coupled hotspots found."
    else
      headers = ~w[File1 File2 CombinedRisk Trend]

      rows =
        Enum.map(coupled_hotspots, fn ch ->
          trend_str = format_trend(get_field(ch, :trend))

          [
            truncate_path(get_field(ch, :entity), 40),
            truncate_path(get_field(ch, :coupled), 40),
            get_field(ch, :combined_risk_score) |> format_float(),
            trend_str
          ]
        end)

      format_table(headers, rows)
    end
  end

  defp format_summary_stats(stats) do
    if Enum.empty?(stats) do
      "No summary data available."
    else
      # Handle summary stats format
      stats
      |> Enum.map(fn stat ->
        statistic = get_field(stat, :statistic, "")
        value = get_field(stat, :value, 0)

        case statistic do
          "total-commits" -> "Total commits: #{format_number(value)}"
          "total-authors" -> "Total authors: #{value}"
          "total-entities" -> "Total entities: #{value}"
          "active-days" -> "Active days: #{value}"
          _ -> "#{statistic}: #{value}"
        end
      end)
      |> Enum.join("\n")
    end
  end

  defp format_generic(data, _options) do
    if Enum.empty?(data) do
      "No data to display."
    else
      # Try to format as a table using the first item's keys
      first = List.first(data)

      if is_map(first) do
        # Get all unique keys from all items
        all_keys =
          data
          |> Enum.flat_map(&Map.keys/1)
          |> Enum.reject(&(&1 == :__struct__))
          |> Enum.uniq()
          |> Enum.sort()

        headers = Enum.map(all_keys, &format_key/1)

        rows =
          Enum.map(data, fn item ->
            Enum.map(all_keys, fn key ->
              format_value(Map.get(item, key))
            end)
          end)

        format_table(headers, rows)
      else
        # Fallback to simple list
        Enum.map_join(data, "\n", &inspect/1)
      end
    end
  end

  # Table formatting

  defp format_table(headers, rows) do
    # Calculate column widths
    col_widths = calculate_column_widths(headers, rows)

    # Format header
    header_row = format_row(headers, col_widths)
    separator = create_separator(col_widths)

    # Format data rows
    data_rows = Enum.map(rows, &format_row(&1, col_widths))

    [header_row, separator | data_rows]
    |> Enum.join("\n")
  end

  defp calculate_column_widths(headers, rows) do
    all_rows = [headers | rows]

    all_rows
    |> Enum.zip()
    |> Enum.map(fn column ->
      column
      |> Tuple.to_list()
      |> Enum.map(&String.length/1)
      |> Enum.max()
    end)
  end

  defp format_row(row, widths) do
    row
    |> Enum.zip(widths)
    |> Enum.map_join(" | ", fn {cell, width} ->
      String.pad_trailing(cell, width)
    end)
  end

  defp create_separator(widths) do
    widths
    |> Enum.map_join("-+-", &String.duplicate("-", &1))
  end

  # Utility functions

  defp get_field(struct_or_map, field, default \\ "") do
    case struct_or_map do
      %{^field => value} -> value || default
      _ -> Map.get(struct_or_map, field, default)
    end
  end

  defp truncate_path(path, max_length) do
    path_str = to_string(path)

    if String.length(path_str) > max_length do
      "..." <> String.slice(path_str, -(max_length - 3)..-1)
    else
      path_str
    end
  end

  defp format_key(key) do
    key
    |> to_string()
    |> String.split("_")
    |> Enum.map_join("", &String.capitalize/1)
  end

  defp format_value(nil), do: ""
  defp format_value(value) when is_float(value), do: format_float(value)
  defp format_value(value) when is_list(value), do: "[#{length(value)} items]"
  defp format_value(value), do: to_string(value)

  defp format_float(nil), do: ""

  defp format_float(value) when is_float(value) do
    :erlang.float_to_binary(value, decimals: 2)
  end

  defp format_float(value), do: to_string(value)

  defp format_number(n) when is_integer(n) and n >= 1000 do
    n
    |> Integer.to_string()
    |> String.graphemes()
    |> Enum.reverse()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end

  defp format_number(n), do: to_string(n)

  defp format_trend(trend) when is_number(trend) and trend > 0 do
    "↑ #{Float.round(trend, 1)}%"
  end

  defp format_trend(trend) when is_number(trend) and trend < 0 do
    "↓ #{Float.round(abs(trend), 1)}%"
  end

  defp format_trend(_), do: "→ stable"

  defp format_affected_files([]), do: ""

  defp format_affected_files(files) when is_list(files) do
    files
    |> Enum.take(5)
    |> Enum.map_join("\n", fn
      %{file: file, impact: impact} ->
        "  - #{truncate_path(file, 60)} (impact: #{format_float(impact)})"

      {file, score} ->
        "  - #{truncate_path(file, 60)} (impact: #{format_float(score)})"

      _ ->
        ""
    end)
  end

  defp count_by_risk(data, risk_level) do
    Enum.count(data, fn item ->
      get_field(item, :risk_factor) == risk_level
    end)
  end

  defp count_strong_couplings(data) do
    Enum.count(data, fn item ->
      degree = get_field(item, :degree)
      is_number(degree) and degree > 75
    end)
  end

  defp count_medium_couplings(data) do
    Enum.count(data, fn item ->
      degree = get_field(item, :degree)
      is_number(degree) and degree >= 50 and degree <= 75
    end)
  end

  defp count_weak_couplings(data) do
    Enum.count(data, fn item ->
      degree = get_field(item, :degree)
      is_number(degree) and degree < 50
    end)
  end

  defp count_silo_risk(data, risk_level) do
    Enum.count(data, fn item ->
      get_field(item, :risk_level) == risk_level
    end)
  end

  defp count_single_author(data) do
    Enum.count(data, fn item ->
      get_field(item, :num_authors) == 1
    end)
  end

  defp calculate_average_complexity(data) do
    if Enum.empty?(data) do
      "0.00"
    else
      total =
        Enum.reduce(data, 0, fn item, acc ->
          acc + get_field(item, :complexity, 0)
        end)

      avg = total / length(data)
      :erlang.float_to_binary(avg, decimals: 2)
    end
  end
end
