defmodule GitlockCore.Adapters.Complexity.Lang.MockAnalyzer do
  @moduledoc """

    Mock adapater 
  """

  use GitlockCore.Adapters.Complexity.BaseAnalyzer

  def supported_extensions, do: ["*"]

  defp calculate_complexity(_content, _file_path), do: Enum.random(1..5)
end
