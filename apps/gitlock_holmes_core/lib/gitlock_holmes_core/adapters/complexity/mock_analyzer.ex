defmodule GitlockHolmesCore.Adapters.Complexity.MockAnalyzer do
  @moduledoc """

    Mock adapater 
  """

  use GitlockHolmesCore.Adapters.Complexity.BaseAnalyzer

  def supported_extensions, do: ["*"]

  defp calculate_complexity(_content, _file_path), do: Enum.random(1..5)
end
