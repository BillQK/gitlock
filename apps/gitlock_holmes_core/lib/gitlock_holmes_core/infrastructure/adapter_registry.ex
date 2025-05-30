defmodule GitlockHolmesCore.Infrastructure.AdapterRegistry do
  @moduledoc """
  Registry for managing adapter instances
  """

  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def register_adapter(type, key, adapter_module) do
    GenServer.call(__MODULE__, {:register, type, key, adapter_module})
  end

  def get_adapter(type, key) do
    GenServer.call(__MODULE__, {:get, type, key})
  end

  def list_adapters(type) do
    GenServer.call(__MODULE__, {:list, type})
  end

  @impl true
  def init(_opts) do
    registry = %{
      vcs: %{
        "git" => GitlockHolmesCore.Adapters.VCS.Git
      },
      reporter: %{
        "csv" => GitlockHolmesCore.Adapters.Reporters.CsvReporter,
        "json" => GitlockHolmesCore.Adapters.Reporters.JsonReporter
      },
      complexity_analyzer: %{
        "dispatch" => GitlockHolmesCore.Adapters.Complexity.DispatchAnalyzer
      }
    }

    {:ok, registry}
  end

  @impl true
  def handle_call({:register, type, key, adapter}, _from, registry) do
    new_registry = put_in(registry, [type, key], adapter)
    {:reply, :ok, new_registry}
  end

  @impl true
  def handle_call({:get, type, key}, _from, registry) do
    case get_in(registry, [type, key]) do
      nil -> {:reply, {:error, "Adapter not found: #{type}/#{key}"}, registry}
      adapter -> {:reply, {:ok, adapter}, registry}
    end
  end

  @impl true
  def handle_call({:list, type}, _from, registry) do
    adapters = Map.get(registry, type, %{}) |> Map.keys()
    {:reply, adapters, registry}
  end
end
