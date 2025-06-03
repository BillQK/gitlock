defmodule GitlockCore.Infrastructure.AdapterRegistryTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Infrastructure.AdapterRegistry
  alias GitlockCore.TestSupport.AdaptersSetup

  # Create test module for adapter
  defmodule TestAdapter do
    def hello, do: "world"
  end

  setup do
    # Generate unique keys for this test
    test_keys = AdaptersSetup.unique_adapter_keys()

    # Return the test keys to use in tests
    {:ok, %{keys: test_keys}}
  end

  describe "register_adapter/3" do
    test "registers a new adapter", %{keys: keys} do
      test_type = String.to_atom("test_type_#{keys.vcs}")
      test_key = "test_key_#{keys.vcs}"

      # Register a test adapter
      assert :ok = AdapterRegistry.register_adapter(test_type, test_key, TestAdapter)

      # Verify it was registered
      assert {:ok, TestAdapter} = AdapterRegistry.get_adapter(test_type, test_key)
    end

    test "allows overwriting existing adapter", %{keys: keys} do
      test_type = String.to_atom("test_type_#{keys.vcs}")
      test_key = "test_key_overwrite_#{keys.vcs}"

      # Register an adapter
      :ok = AdapterRegistry.register_adapter(test_type, test_key, TestAdapter)

      # Register a different adapter with the same key
      :ok = AdapterRegistry.register_adapter(test_type, test_key, String)

      # Verify it was overwritten
      assert {:ok, String} = AdapterRegistry.get_adapter(test_type, test_key)
    end

    test "registers multiple adapters of the same type", %{keys: keys} do
      test_type = String.to_atom("multi_type_#{keys.vcs}")

      :ok = AdapterRegistry.register_adapter(test_type, "key1_#{keys.vcs}", TestAdapter)
      :ok = AdapterRegistry.register_adapter(test_type, "key2_#{keys.vcs}", String)
      :ok = AdapterRegistry.register_adapter(test_type, "key3_#{keys.vcs}", Map)

      assert {:ok, TestAdapter} = AdapterRegistry.get_adapter(test_type, "key1_#{keys.vcs}")
      assert {:ok, String} = AdapterRegistry.get_adapter(test_type, "key2_#{keys.vcs}")
      assert {:ok, Map} = AdapterRegistry.get_adapter(test_type, "key3_#{keys.vcs}")
    end
  end

  describe "get_adapter/2" do
    test "returns error for non-existent adapter", %{keys: keys} do
      missing_type = String.to_atom("missing_type_#{keys.vcs}")
      missing_key = "missing_key_#{keys.vcs}"

      assert {:error, _} = AdapterRegistry.get_adapter(missing_type, missing_key)
    end

    test "returns error for existing type but missing key", %{keys: keys} do
      existing_type = String.to_atom("existing_type_#{keys.vcs}")
      existing_key = "existing_key_#{keys.vcs}"
      missing_key = "missing_key_#{keys.vcs}"

      :ok = AdapterRegistry.register_adapter(existing_type, existing_key, TestAdapter)

      assert {:ok, TestAdapter} = AdapterRegistry.get_adapter(existing_type, existing_key)
      assert {:error, _} = AdapterRegistry.get_adapter(existing_type, missing_key)
    end
  end

  describe "list_adapters/1" do
    test "lists all registered adapters of a type", %{keys: keys} do
      list_type = String.to_atom("list_test_#{keys.vcs}")
      key1 = "key1_#{keys.vcs}"
      key2 = "key2_#{keys.vcs}"

      # Register multiple adapters
      :ok = AdapterRegistry.register_adapter(list_type, key1, TestAdapter)
      :ok = AdapterRegistry.register_adapter(list_type, key2, String)

      # List adapters
      adapters = AdapterRegistry.list_adapters(list_type)

      assert length(adapters) == 2
      assert key1 in adapters
      assert key2 in adapters
    end

    test "returns empty list for non-existent type", %{keys: keys} do
      non_existent_type = String.to_atom("non_existent_#{keys.vcs}")
      adapters = AdapterRegistry.list_adapters(non_existent_type)
      assert adapters == []
    end
  end

  test "integration with default registry" do
    # Should be able to get predefined adapters
    assert {:ok, _} = AdapterRegistry.get_adapter(:vcs, "git")
    assert {:ok, _} = AdapterRegistry.get_adapter(:reporter, "csv")
    assert {:ok, _} = AdapterRegistry.get_adapter(:reporter, "json")
    assert {:ok, _} = AdapterRegistry.get_adapter(:complexity_analyzer, "dispatch")
    assert {:ok, _} = AdapterRegistry.get_adapter(:file_system, "local_file_system")
  end
end
