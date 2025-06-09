defmodule MockGitlockCore do
  @moduledoc """
  Fake implementation of GitlockCore for testing.
  Returns realistic CSV data without needing actual Git analysis.
  """

  def available_investigations do
    [
      :hotspots,
      :knowledge_silos,
      :couplings,
      :coupled_hotspots,
      :blast_radius,
      :summary,
      :team_communication,
      :code_health
    ]
  end

  def investigate(investigation_type, source, options \\ %{})

  # Summary - Always works, returns basic repo stats
  def investigate(:summary, _source, _options) do
    {:ok,
     """
     statistic,value
     number-of-commits,247
     number-of-entities,82
     number-of-authors,12
     number-of-entities-changed,156
     """}
  end

  # Hotspots - Requires dir option
  def investigate(:hotspots, _source, options) do
    if options[:dir] do
      {:ok,
       """
       entity,revisions,complexity,loc,risk_score,risk_factor
       src/core/main.ex,45,28,650,89.2,high
       lib/api/handler.ex,32,15,420,65.8,high
       src/utils/parser.ex,28,12,380,52.4,medium
       lib/data/processor.ex,18,8,220,34.1,medium
       src/config/settings.ex,12,5,180,22.3,low
       test/support/helpers.ex,8,3,95,15.7,low
       """}
    else
      {:error, {:validation, "Directory option (--dir) is required for complexity analysis"}}
    end
  end

  # Knowledge Silos - Shows ownership concentration
  def investigate(:knowledge_silos, _source, _options) do
    {:ok,
     """
     entity,main_author,ownership_ratio,num_authors,num_commits,risk_level
     src/legacy/old_system.ex,john.doe,96.4,2,28,high
     lib/core/secret_sauce.ex,jane.smith,87.2,3,41,high
     src/api/private_handler.ex,bob.wilson,78.9,4,19,high
     lib/utils/formatter.ex,alice.brown,65.3,5,34,medium
     src/common/helpers.ex,charlie.davis,52.1,7,23,medium
     lib/public/interface.ex,diana.miller,34.2,9,45,low
     """}
  end

  # Couplings - Files that change together
  def investigate(:couplings, _source, _options) do
    {:ok,
     """
     entity,coupled,degree,windows,trend
     src/main.ex,lib/core.ex,92,15,positive
     src/api/handler.ex,src/api/response.ex,78,12,stable
     lib/data/parser.ex,lib/data/validator.ex,71,18,negative
     src/utils/helper.ex,src/utils/formatter.ex,65,8,positive
     lib/config/app.ex,lib/config/env.ex,58,10,stable
     src/core/processor.ex,src/core/utils.ex,45,6,negative
     """}
  end

  # Coupled Hotspots - Requires dir option
  def investigate(:coupled_hotspots, _source, options) do
    if options[:dir] do
      {:ok,
       """
       entity,coupled,combined_risk_score,trend,individual_risks
       src/main.ex,lib/core.ex,94.7,positive,"89.2,87.3"
       src/api/handler.ex,src/api/response.ex,71.2,stable,"65.8,68.4"
       lib/data/parser.ex,lib/data/validator.ex,58.9,negative,"52.4,61.2"
       src/utils/helper.ex,src/utils/formatter.ex,42.3,positive,"38.7,45.1"
       """}
    else
      {:error, {:validation, "Directory option (--dir) is required for complexity analysis"}}
    end
  end

  # Blast Radius - Requires both dir and target_files
  def investigate(:blast_radius, _source, options) do
    cond do
      not options[:target_files] ->
        {:error,
         {:validation, "Target files (--target-files) are required for blast radius analysis"}}

      not options[:dir] ->
        {:error, {:validation, "Directory option (--dir) is required for blast radius analysis"}}

      true ->
        target_files = List.wrap(options[:target_files])
        threshold = options[:blast_threshold] || 0.3
        max_radius = options[:max_radius] || 2

        results =
          Enum.map(target_files, fn file ->
            # Simulate different impact levels based on file name
            impact =
              cond do
                String.contains?(file, "main") -> "high"
                String.contains?(file, "core") -> "high"
                String.contains?(file, "api") -> "medium"
                true -> "low"
              end

            risk_score =
              case impact do
                "high" -> 8.5 + :rand.uniform() * 1.5
                "medium" -> 5.0 + :rand.uniform() * 2.0
                "low" -> 2.0 + :rand.uniform() * 2.0
              end

            affected_files =
              case impact do
                "high" -> 15 + :rand.uniform(10)
                "medium" -> 8 + :rand.uniform(7)
                "low" -> 3 + :rand.uniform(5)
              end

            affected_components = max(1, div(affected_files, 4))

            reviewers =
              case impact do
                "high" -> "jane.doe,john.smith,bob.wilson"
                "medium" -> "jane.doe,alice.brown"
                "low" -> "charlie.davis"
              end

            "#{file},#{impact},#{Float.round(risk_score, 1)},#{affected_files},#{affected_components},\"#{reviewers}\""
          end)

        header =
          "entity,impact_severity,risk_score,affected_files_count,affected_components_count,suggested_reviewers"

        {:ok, header <> "\n" <> Enum.join(results, "\n") <> "\n"}
    end
  end

  # Team Communication
  def investigate(:team_communication, _source, _options) do
    {:ok,
     """
     author,peer,shared,average,strength
     jane.doe,john.smith,23,35,66
     bob.wilson,alice.brown,18,28,64
     john.smith,bob.wilson,15,24,63
     alice.brown,jane.doe,12,21,57
     charlie.davis,diana.miller,8,16,50
     diana.miller,jane.doe,6,18,33
     """}
  end

  # Code Health - Overall assessment
  def investigate(:code_health, _source, options) do
    if options[:dir] do
      {:ok,
       """
       metric,value,status,recommendation
       test_coverage,78.5,good,Increase to 85%+
       complexity_trend,rising,warning,Refactor high complexity files
       duplication_ratio,12.3,acceptable,Monitor for increases
       technical_debt_hours,156,moderate,Address top 5 hotspots
       maintainability_index,68,good,Focus on coupled hotspots
       """}
    else
      {:error, {:validation, "Directory option (--dir) is required for code health analysis"}}
    end
  end

  # Handle unknown investigation types
  def investigate(unknown_type, _source, _options) do
    {:error, {:analysis, "Unknown investigation type: #{unknown_type}"}}
  end

  # Simulate some error conditions based on source path
  def investigate(_type, source, _options) when is_binary(source) do
    cond do
      String.contains?(source, "nonexistent") ->
        {:error, {:io, source, :enoent}}

      String.contains?(source, "permission") ->
        {:error, {:io, source, :eacces}}

      String.contains?(source, "invalid") ->
        {:error, {:parse, "Invalid log format"}}

      String.contains?(source, "corrupt") ->
        {:error, {:git, "repository is corrupted"}}

      true ->
        # Default successful response
        {:ok, "entity,value\ndefault.ex,1\n"}
    end
  end
end
