defmodule GitlockHolmesCore.Domain.Values.ChangeImpact do
  @moduledoc """
  Represents the imacpt analysis of changing a specific file. 

  This value object contains the complete analysis of changing a target file: 
  - Target file information 
  - Risk score (0-10)
  - Impact severity classification (high, medium, low)
  - Affected files with impact levels and distances 
  - Component impact anlaysis 
  - Recommended reviewers 
  - Identified risk factors
  """
  @type severity :: :high | :medium | :low

  @type affected_file :: %{
          file: String.t(),
          impact: float(),
          distance: non_neg_integer(),
          component: String.t() | nil
        }

  @type t :: %__MODULE__{
          entity: String.t(),
          risk_score: float(),
          impact_severity: severity(),
          affected_files: [affected_file()],
          affected_components: %{String.t() => float()},
          suggested_reviewers: [String.t()],
          risk_factors: [String.t()]
        }
  defstruct [
    :entity,
    :risk_score,
    :impact_severity,
    :affected_files,
    :affected_components,
    :suggested_reviewers,
    :risk_factors
  ]

  @doc """
  Creates a new change impact value object.

  ## Parameters
    * `entity` - Path of the target file
    * `risk_score` - Calculated risk score (0-10)
    * `affected_files` - List of files affected by the change
    * `affected_components` - Map of component names to impact values
    * `suggested_reviewers` - List of recommended reviewers
    * `risk_factors` - List of identified risk factors
    
  ## Returns
    A new immutable ChangeImpact struct with calculated severity
    
  ## Examples
      iex> affected_files = [
      ...>   %{file: "lib/auth/token.ex", impact: 0.8, distance: 1, component: "auth"},
      ...>   %{file: "lib/user/profile.ex", impact: 0.5, distance: 2, component: "user"}
      ...> ]
      iex> affected_components = %{"auth" => 0.8, "user" => 0.5}
      iex> ChangeImpact.new(
      ...>   "lib/auth/session.ex",
      ...>   7.5,
      ...>   affected_files,
      ...>   affected_components,
      ...>   ["Alice", "Bob"],
      ...>   ["High complexity", "Cross-component impact"]
      ...> )
      %ChangeImpact{
        entity: "lib/auth/session.ex",
        risk_score: 7.5,
        impact_severity: :high,
        affected_files: [
          %{file: "lib/auth/token.ex", impact: 0.8, distance: 1, component: "auth"},
          %{file: "lib/user/profile.ex", impact: 0.5, distance: 2, component: "user"}
        ],
        affected_components: %{"auth" => 0.8, "user" => 0.5},
        suggested_reviewers: ["Alice", "Bob"],
        risk_factors: ["High complexity", "Cross-component impact"]
      }
  """

  @spec new(
          String.t(),
          float(),
          [affected_file()],
          %{String.t() => float()},
          [String.t()],
          [String.t()]
        ) :: t()
  def new(
        entity,
        risk_score,
        affected_files,
        affected_components,
        suggested_reviewers,
        risk_factors
      ) do
    %__MODULE__{
      entity: entity,
      risk_score: risk_score,
      impact_severity: calculate_severity(risk_score),
      affected_files: affected_files,
      affected_components: affected_components,
      suggested_reviewers: suggested_reviewers,
      risk_factors: risk_factors
    }
  end

  @doc """
  Determines impact severity from risk score.

  ## Parameters
    * `risk_score` - Numerical risk score (0-10)
    
  ## Returns
    The severity level (:high, :medium, or :low)
    
  ## Examples
      iex> ChangeImpact.calculate_severity(8.0)
      :high
      iex> ChangeImpact.calculate_severity(5.5)
      :medium
      iex> ChangeImpact.calculate_severity(3.0)
      :low
  """
  @spec calculate_severity(float()) :: severity()
  def calculate_severity(risk_score) when risk_score >= 7.0, do: :high
  def calculate_severity(risk_score) when risk_score >= 4.0, do: :medium
  def calculate_severity(_risk_score), do: :low

  @doc """
  Gets the most impacted files from the blast radius.

  ## Parameters
    * `impact` - The change impact analysis
    * `limit` - Maximum number of files to return
    
  ## Returns
    List of affected files sorted by impact
    
  ## Examples
      iex> impact = %ChangeImpact{affected_files: [
      ...>   %{file: "a.ex", impact: 0.3, distance: 2, component: "x"},
      ...>   %{file: "b.ex", impact: 0.8, distance: 1, component: "y"},
      ...>   %{file: "c.ex", impact: 0.5, distance: 1, component: "z"}
      ...> ]}
      iex> ChangeImpact.most_impacted_files(impact, 2)
      [
        %{file: "b.ex", impact: 0.8, distance: 1, component: "y"},
        %{file: "c.ex", impact: 0.5, distance: 1, component: "z"}
      ]
  """
  @spec most_impacted_files(t(), non_neg_integer()) :: [affected_file()]
  def most_impacted_files(%__MODULE__{affected_files: affected_files}, limit) do
    affected_files
    |> Enum.sort_by(fn file -> file.impact end, :desc)
    |> Enum.take(limit)
  end

  @doc """
  Gets files impacted in a specific component.

  ## Parameters
    * `impact` - The change impact analysis
    * `component` - Name of the component
    
  ## Returns
    List of affected files in the specified component
    
  ## Examples
      iex> impact = %ChangeImpact{affected_files: [
      ...>   %{file: "lib/auth/a.ex", impact: 0.8, distance: 1, component: "auth"},
      ...>   %{file: "lib/auth/b.ex", impact: 0.5, distance: 2, component: "auth"},
      ...>   %{file: "lib/user/c.ex", impact: 0.4, distance: 1, component: "user"}
      ...> ]}
      iex> ChangeImpact.component_files(impact, "auth")
      [
        %{file: "lib/auth/a.ex", impact: 0.8, distance: 1, component: "auth"},
        %{file: "lib/auth/b.ex", impact: 0.5, distance: 2, component: "auth"}
      ]
  """
  @spec component_files(t(), String.t()) :: [affected_file()]
  def component_files(%__MODULE__{affected_files: affected_file}, component) do
    Enum.filter(affected_file, fn file -> file.component == component end)
  end

  @doc """
  Gets all impacted components sorted by impact level.

  ## Returns
    List of {component, impact} tuples sorted by descending impact
    
  ## Examples
      iex> impact = %ChangeImpact{affected_components: %{
      ...>   "auth" => 0.8,
      ...>   "user" => 0.5,
      ...>   "utils" => 0.3
      ...> }}
      iex> ChangeImpact.impacted_components(impact)
      [{"auth", 0.8}, {"user", 0.5}, {"utils", 0.3}]
  """
  @spec impacted_components(t()) :: [{String.t(), float()}]
  def impacted_components(%__MODULE__{affected_components: components}) do
    components
    |> Enum.to_list()
    |> Enum.sort_by(fn {_component, impact} -> impact end, :desc)
  end

  @doc """
  Generates a human-readable summary of the impact analysis.

  ## Returns
    Formatted string summary
    
  ## Examples
      iex> impact = %ChangeImpact{
      ...>   entity: "lib/auth/session.ex",
      ...>   risk_score: 7.5,
      ...>   impact_severity: :high,
      ...>   affected_files: [%{}, %{}, %{}],
      ...>   affected_components: %{"auth" => 0.8, "user" => 0.4},
      ...>   suggested_reviewers: ["Alice", "Bob"]
      ...> }
      iex> ChangeImpact.to_summary(impact)
      "TARGET FILE: lib/auth/session.ex\\nRISK SCORE: 7.5/10 (HIGH RISK)\\nIMPACT SUMMARY:\\n- Blast Radius: 3 files affected across 2 components\\n- SUGGESTED REVIEWERS: Alice, Bob"
  """
  @spec to_summary(t()) :: String.t()
  def to_summary(%__MODULE__{} = impact) do
    severity_text = impact.impact_severity |> Atom.to_string() |> String.upcase()

    component_count = map_size(impact.affected_components)
    files_count = length(impact.affected_files)

    reviewers = Enum.join(impact.suggested_reviewers, ", ")

    """
    TARGET FILE: #{impact.entity}
    RISK SCORE: #{:io_lib.format("~.1f", [impact.risk_score])}/10 (#{severity_text} RISK)
    IMPACT SUMMARY:
    - Blast Radius: #{files_count} files affected across #{component_count} components
    - SUGGESTED REVIEWERS: #{reviewers}
    """
  end

  @doc """
  Converts the impact analysis to a map for JSON serialization.

  ## Returns
    A plain map representation
  """
  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = impact) do
    Map.from_struct(impact)
  end

  @doc """
  Determines if the impact is considered high risk.

  ## Returns
    `true` if high risk, `false` otherwise
  """
  @spec high_risk?(t()) :: boolean()
  def high_risk?(%__MODULE__{impact_severity: :high}), do: true
  def high_risk?(_), do: false
end
