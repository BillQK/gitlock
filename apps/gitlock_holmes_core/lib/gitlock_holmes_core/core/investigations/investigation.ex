defmodule GitlockHolmesCore.Core.Investigations.Investigation do
  @moduledoc """
  Behaviour and macro for defining investigations.
  Use this module to automatically get the common investigation pipeline,
  so each investigation only needs to implement `analyze/2`.

  ## Usage
      defmodule MyInvestigation do
        use GitlockHolmes.Investigations.Investigation, complexity: true
        
        @impl true
        def analyze(commits, complexity_map) do
          # Your analysis logic here
        end

        # Optional Override 
        def investigate(log_file, vcs, reporter, analyzer, options) do
          # your pipeline logic here
        end
      end
  """

  alias GitlockHolmesCore.Domain.Values.ComplexityMetrics
  alias GitlockHolmesCore.Domain.Services.ComplexityCollector
  alias GitlockHolmesCore.Domain.Entities.{Commit}

  @typedoc "Analysis result list of maps"
  @type results :: [map()]

  @typedoc "Map of file paths to complexity metrics"
  @type complexity_map :: %{String.t() => ComplexityMetrics.t()}

  @doc "Callback to implement the core analysis logic for an investigation"
  @callback analyze(
              commits :: [Commit.t()],
              complexity_map :: complexity_map()
            ) :: results()

  @doc "Callback to run the complete investigation flow"
  @callback investigate(
              log_file :: String.t(),
              vcs_port :: module(),
              reporter_port :: module(),
              analyzer_port :: module() | nil,
              options :: map()
            ) :: {:ok, String.t()} | {:error, String.t()}

  @optional_callbacks [investigate: 5]

  defmacro __using__(opts) do
    needs_complexity = Keyword.get(opts, :complexity, false)

    quote do
      @behaviour GitlockHolmesCore.Core.Investigations.Investigation

      @doc "Runs the investigation using the shared pipeline"
      @impl true
      @spec investigate(
              log_file :: String.t(),
              vcs_port :: module(),
              reporter_port :: module(),
              analyzer_port :: module() | nil,
              options :: map()
            ) :: {:ok, String.t()} | {:error, String.t()}
      def investigate(log_file, vcs, reporter, analyzer, options \\ %{}) do
        complexity_map = get_complexity_map(analyzer, options)

        with {:ok, commits} <- vcs.get_commit_history(log_file, options),
             results <- analyze(commits, complexity_map),
             {:ok, report} <- reporter.report(results, options) do
          {:ok, report}
        else
          {:error, reason} -> {:error, "Investigation failed: #{reason}"}
          _ -> {:error, "Unknown error during investigation"}
        end
      end

      # The value of needs_complexity is being evaluated at compile time, not runtime
      # Instead of trying to use the compile-time value in a runtime condition,
      # we use it to conditionally define entirely different functions.
      # The key difference is here - we use a private function that's defined conditionally
      # based on the compile-time option, rather than trying to use the option at runtime
      if unquote(needs_complexity) do
        defp get_complexity_map(nil, _options), do: %{}

        defp get_complexity_map(analyzer, options) do
          dir = Map.get(options, :dir, ".")
          ComplexityCollector.collect_complexity(analyzer, dir)
        end
      else
        defp get_complexity_map(_analyzer, _options), do: %{}
      end

      defoverridable investigate: 5
    end
  end
end
