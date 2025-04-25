defmodule GitlockHolmes.Domain.Values.ComplexityMetrics do
  @moduledoc """
  Entity representing complexity metrics for a file.
  """

  @type language :: :elixir | :javascript | :ruby | :python | :java | :unknown

  @type t :: %__MODULE__{
          file_path: String.t(),
          loc: non_neg_integer(),
          cyclomatic_complexity: non_neg_integer(),
          language: language()
        }

  defstruct [:file_path, :loc, :cyclomatic_complexity, :language]

  @doc """
  Creates a new complexity metrics entity.

  ## Parameters

    * `file_path` - Path to the analyzed file
    * `loc` - Lines of code
    * `cyclomatic_complexity` - Cyclomatic complexity measure
    * `language` - Programming language of the file

  ## Returns

    A new ComplexityMetrics struct
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
end
