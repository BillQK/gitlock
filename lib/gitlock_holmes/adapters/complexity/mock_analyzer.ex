defmodule GitlockHolmes.Adapters.Complexity.MockAnalyzer do
  use GitlockHolmes.Adapters.Complexity.BaseAnalyzer

  def supported_extensions, do: [".ex"]

  defp calculate_complexity(_content, _file_path), do: Enum.random(1..5)
end

