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
      not Map.has_key?(options, :target_files) ->
        {:error,
         {:validation, "Target files (--target-files) are required for blast radius analysis"}}

      not Map.has_key?(options, :dir) ->
        {:error, {:validation, "Directory option (--dir) is required for blast radius analysis"}}

      true ->
        # Handle both string and list formats for target_files
        target_files =
          case options[:target_files] do
            files when is_list(files) -> files
            file when is_binary(file) -> [file]
            _ -> []
          end

        results =
          Enum.map(target_files, fn file ->
            # Simulate different impact levels based on file name
            impact =
              cond do
                String.contains?(file, "main") -> "high"
                String.contains?(file, "core") -> "high"
                String.contains?(file, "api") -> "medium"
                String.contains?(file, "util") -> "medium"
                true -> "low"
              end

            # Generate a reason for the impact
            reason =
              case impact do
                "high" -> "Core component with many dependencies"
                "medium" -> "Used by multiple components"
                "low" -> "Limited usage in the codebase"
              end

            "#{file},#{impact},\"#{reason}\""
          end)

        header = "entity,impact_level,impact_reason"
        results_str = Enum.join(results, "\n")

        {:ok, "#{header}\n#{results_str}\n"}
    end
  end

  # Other investigations with placeholders
  def investigate(:team_communication, _source, _options) do
    {:ok,
     """
     entity1,entity2,communication_score,num_interactions
     john.doe,jane.smith,87.3,45
     bob.wilson,alice.brown,72.1,36
     charlie.davis,diana.miller,65.8,29
     """}
  end

  def investigate(:code_health, _source, options) do
    if options[:dir] do
      {:ok,
       """
       metric,value,trend,benchmark
       code_coverage,78.2,positive,75.0
       complexity_index,23.4,negative,20.0
       knowledge_dispersion,65.7,stable,70.0
       technical_debt_ratio,18.3,positive,25.0
       """}
    else
      {:error, {:validation, "Directory option (--dir) is required for code health analysis"}}
    end
  end

  # Simulated file reading - returns mock data or errors based on filename
  def read_file(source, _options) do
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
