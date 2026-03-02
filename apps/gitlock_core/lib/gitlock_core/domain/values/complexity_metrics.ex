defmodule GitlockCore.Domain.Values.ComplexityMetrics do
  @moduledoc """
  Value object representing complexity metrics for a file.

  This is an immutable value object that encapsulates various code complexity
  measurements for a specific file.
  """

  @type language :: :elixir | :javascript | :typescript | :ruby | :python | :java | :unknown

  @type t :: %__MODULE__{
          file_path: String.t(),
          loc: non_neg_integer(),
          cyclomatic_complexity: non_neg_integer(),
          language: language()
        }

  defstruct [
    :file_path,
    :loc,
    :cyclomatic_complexity,
    :language
  ]

  @doc """
  Creates a new complexity metrics value object.

  ## Parameters
    * `file_path` - Path to the analyzed file
    * `loc` - Lines of code
    * `cyclomatic_complexity` - Cyclomatic complexity measure
    * `language` - Programming language of the file

  ## Returns
    An immutable ComplexityMetrics value object
  """
  @spec new(String.t(), non_neg_integer(), non_neg_integer(), language()) :: t()
  def new(file_path, loc, cyclomatic_complexity, language) do
    %__MODULE__{
      file_path: file_path,
      loc: loc,
      cyclomatic_complexity: cyclomatic_complexity,
      language: language
    }
  end

  @doc """
  Calculates the complexity density (complexity per line of code).

  This derived metric helps compare complexity across files of different sizes.

  ## Returns
    A float representing complexity per line of code
  """
  @spec complexity_density(t()) :: float()
  def complexity_density(%__MODULE__{loc: loc, cyclomatic_complexity: cc})
      when is_number(loc) and is_number(cc) and loc > 0 do
    cc / loc
  end

  def complexity_density(_), do: 0.0

  @doc """
  Determines the complexity risk category based on complexity metrics.

  ## Returns
    One of `:high`, `:medium`, or `:low` risk
  """
  @spec risk_category(t()) :: :high | :medium | :low
  def risk_category(%__MODULE__{cyclomatic_complexity: cc}) when cc > 30, do: :high
  def risk_category(%__MODULE__{cyclomatic_complexity: cc}) when cc > 15, do: :medium
  def risk_category(_), do: :low

  @doc """
  Checks if two complexity metrics are equal in value.

  Value objects are equal when all their attributes are equal,
  regardless of their identity.
  """
  @spec equal?(t(), t()) :: boolean()
  def equal?(%__MODULE__{} = a, %__MODULE__{} = b) do
    a.file_path == b.file_path &&
      a.loc == b.loc &&
      a.cyclomatic_complexity == b.cyclomatic_complexity &&
      a.language == b.language
  end

  @doc """
  Creates a human-readable string representation of the complexity metrics.
  """
  @spec to_string(t()) :: String.t()
  def to_string(%__MODULE__{} = metrics) do
    "#{Path.basename(metrics.file_path)} (#{metrics.language}): #{metrics.loc} LOC, complexity: #{metrics.cyclomatic_complexity}"
  end
end
