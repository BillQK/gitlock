defmodule GitlockCore.Domain.Values.CodeAge do
  @moduledoc """
  Age of code is define as “the time of the last change to the file”. 
  Note that this means any change. It doesn’t matter if you rename a variable, 
  add a single line comment or re-write the whole module. All those changes are,
  in the context of Code Age, considered equal.

  Based on Adam Tornhill's Code Maat methodology for analyzing file age
  patterns. Code should be either fresh (in memory) or stable (proven),
  with the dangerous middle ground being old enough to forget but young
  enough to still need changes.

  ## Example

      code_age = CodeAge.new("src/user.ex", 8.5)
      risk = CodeAge.calculate_risk(8.5)
  """

  @enforce_keys [:entity, :age_months, :risk]
  defstruct [:entity, :age_months, :risk]

  @type t :: %__MODULE__{
          entity: String.t(),
          age_months: float(),
          risk: atom()
        }

  @doc """
  Creates a new CodeAge.

  ## Parameters
  - `entity` - File path (e.g., "src/user.ex")
  - `age_months` - Age in months since last modification

  ## Examples

      iex> CodeAge.new("src/user.ex", 8.5)
      %CodeAge{entity: "src/user.ex", age_months: 8.5}
  """
  @spec new(String.t(), float(), atom()) :: t()
  def new(entity, age_months, risk)
      when is_binary(entity) and is_number(age_months) and age_months >= 0 and is_atom(risk) do
    %__MODULE__{
      entity: entity,
      age_months: age_months,
      risk: risk
    }
  end

  @doc """
  Calculates risk level based on file age.

  Risk is based on the "software half-life" principle:
  - 0-3 months: Low risk (fresh in memory)
  - 3-18 months: High risk (danger zone)
  - 18-36 months: Medium risk (forgotten but active)
  - 36+ months: Low risk (stable commodity)

  ## Examples

      iex> CodeAge.calculate_risk(2.0)
      :low

      iex> CodeAge.calculate_risk(8.5)
      :high

      iex> CodeAge.calculate_risk(24.0)
      :medium

      iex> CodeAge.calculate_risk(48.0)
      :low
  """
  @spec calculate_risk(float()) :: :low | :medium | :high
  def calculate_risk(age_months) when is_number(age_months) and age_months >= 0 do
    cond do
      # Fresh
      age_months <= 3.0 -> :low
      # Risky (danger zone)
      age_months <= 18.0 -> :high
      # Forgotten
      age_months <= 36.0 -> :medium
      # Stable
      true -> :low
    end
  end

  @doc """
  Calculates age in months from a given date to now.

  Uses Code Maat's precise calculation of 30.44 days per month
  to account for leap years and varying month lengths.

  ## Parameters
  - `date` - The date to calculate age from (Date.t() or DateTime.t())

  ## Examples

      iex> past_date = ~D[2024-01-15]
      iex> age = CodeAge.calculate_age_months(past_date)
      iex> is_float(age)
      true

      iex> past_datetime = ~U[2024-01-15 10:30:00Z]
      iex> age = CodeAge.calculate_age_months(past_datetime)
      iex> is_float(age)
      true

  ## Use Cases

      # From Git log parsing
      last_modified = ~D[2024-01-15]
      age_months = CodeAge.calculate_age_months(last_modified)
      code_age = CodeAge.new("src/user.ex", age_months)

      # Batch processing
      git_entries
      |> Enum.map(fn entry ->
        age = CodeAge.calculate_age_months(entry.date)
        CodeAge.new(entry.file_path, age)
      end)
  """
  @spec calculate_age_months(Date.t()) :: float()
  def calculate_age_months(%Date{} = date) do
    today = Date.utc_today()
    diff_days = Date.diff(today, date)
    # Code Maat's precise month calculation
    diff_days / 30.44
  end
end
