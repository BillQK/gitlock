defmodule GitlockCore.TestSupport.AdaptersSetup do
  @moduledoc """
  Test adapter setup that generates unique keys per test

  ## Usage Examples:

      # Pattern 1: Direct usage
      setup context do
        adapter_keys = 
          context
          |> AdapterSetup.unique_adapter_keys()
          |> AdapterSetup.register_test_adapters()
        
        {:ok, %{adapters: adapter_keys}}
      end
      
      # Pattern 2: Using the macro
      setup_unique_adapters()
      
      # Pattern 3: With real adapters for integration tests
      setup context do
        adapter_keys = 
          context
          |> AdapterSetup.unique_adapter_keys()
          |> AdapterSetup.register_real_adapters()
        
        {:ok, %{adapters: adapter_keys}}
      end
  """

  alias GitlockCore.Infrastructure.AdapterRegistry

  alias GitlockCore.Mocks.{
    VersionControlMock,
    ReporterMock,
    ComplexityAnalyzerMock,
    FileSystemMock
  }

  @doc """
  Generate unique adapter keys for a test based on test module and line
  """
  def unique_adapter_keys(test_context \\ %{}) do
    # Use test context info if available, otherwise generate unique ID
    test_id = generate_test_id(test_context)

    %{
      vcs: "test_vcs_#{test_id}",
      git_vcs: "test_git_vcs_#{test_id}",
      csv_reporter: "test_csv_#{test_id}",
      json_reporter: "test_json_#{test_id}",
      complexity: "test_complexity_#{test_id}",
      file_system: "test_fs_#{test_id}"
    }
  end

  @doc """
  Register test adapters with unique keys using Mox mocks
  """
  def register_test_adapters(adapter_keys) do
    registrations = [
      {:vcs, adapter_keys.vcs, VersionControlMock},
      {:vcs, adapter_keys.git_vcs, VersionControlMock},
      {:reporter, adapter_keys.csv_reporter, ReporterMock},
      {:reporter, adapter_keys.json_reporter, ReporterMock},
      {:complexity_analyzer, adapter_keys.complexity, ComplexityAnalyzerMock},
      {:file_system, adapter_keys.file_system, FileSystemMock}
    ]

    register_adapters(registrations)
    adapter_keys
  end

  @doc """
  Register real adapters with unique keys for integration tests
  """
  def register_real_adapters(adapter_keys) do
    registrations = [
      {:vcs, adapter_keys.vcs, GitlockCore.Adapters.VCS.Git},
      {:vcs, adapter_keys.git_vcs, GitlockCore.Adapters.VCS.Git},
      {:reporter, adapter_keys.csv_reporter, GitlockCore.Adapters.Reporters.CsvReporter},
      {:reporter, adapter_keys.json_reporter, GitlockCore.Adapters.Reporters.JsonReporter},
      {:complexity_analyzer, adapter_keys.complexity,
       GitlockCore.Adapters.Complexity.DispatchAnalyzer},
      {:file_system, adapter_keys.file_system,
       GitlockCore.Adapters.FileSystem.LocalFileSystem}
    ]

    register_adapters(registrations)
    adapter_keys
  end

  @doc """
  Create test options map with adapter keys
  """
  def test_options(adapter_keys, additional_opts \\ %{}) do
    base_opts = %{
      vcs: adapter_keys.vcs,
      format: adapter_keys.csv_reporter,
      complexity_analyzer: adapter_keys.complexity,
      file_system: adapter_keys.file_system
    }

    Map.merge(base_opts, additional_opts)
  end

  @doc """
  Setup macro for easy use in tests with Mox mocks
  """
  defmacro setup_unique_adapters() do
    quote do
      alias GitlockCore.TestSupport.AdaptersSetup
      import Mox

      setup :verify_on_exit!

      setup context do
        adapter_keys =
          context
          |> AdaptersSetup.unique_adapter_keys()
          |> AdaptersSetup.register_test_adapters()

        {:ok, %{adapter_keys: adapter_keys}}
      end
    end
  end

  @doc """
  Setup macro for integration tests with real adapters
  """
  defmacro setup_real_adapters() do
    quote do
      alias GitlockCore.TestSupport.AdaptersSetup
      import Mox

      setup :verify_on_exit!

      setup context do
        adapter_keys =
          context
          |> AdaptersSetup.unique_adapter_keys()
          |> AdaptersSetup.register_real_adapters()

        {:ok, %{adapter_keys: adapter_keys}}
      end
    end
  end

  # Private functions
  defp generate_test_id(test_context) do
    case test_context do
      %{test: test_name, module: module} when is_atom(module) ->
        module_name = module |> Module.split() |> List.last() |> String.downcase()
        "#{module_name}_#{test_name}_#{:rand.uniform(10000)}"

      %{test: test_name} ->
        "#{test_name}_#{:rand.uniform(10000)}_#{:erlang.phash2(self())}"

      %{line: line, file: file} ->
        file_hash = :erlang.phash2(file)
        "#{file_hash}_#{line}_#{:rand.uniform(1000)}"

      _ ->
        pid_hash = :erlang.phash2(self())
        time_hash = :erlang.phash2(System.monotonic_time())
        "#{pid_hash}_#{time_hash}"
    end
  end

  defp register_adapters(registrations) do
    Enum.each(registrations, fn {type, key, adapter} ->
      :ok = AdapterRegistry.register_adapter(type, key, adapter)
    end)
  end
end
