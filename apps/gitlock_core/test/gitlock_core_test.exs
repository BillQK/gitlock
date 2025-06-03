defmodule GitlockCoreTest do
  use ExUnit.Case, async: true

  import GitlockCore.TestSupport.AdaptersSetup, only: [setup_real_adapters: 0]

  alias GitlockCore

  setup_real_adapters()

  describe "investigate/3 - delegation behavior" do
    test "delegates to UseCaseFactory with correct investigation type" do
      # Test that it calls UseCaseFactory with the right type
      # We can verify this by using a known invalid type
      result = GitlockCore.investigate(:definitely_not_a_valid_type, "path")

      # The error should come from UseCaseFactory
      assert {:error, "Unknown investigation type: definitely_not_a_valid_type"} = result
    end

    test "passes through the return value from use case execution", %{adapter_keys: adapter_keys} do
      # When given a valid investigation type, it should return whatever the use case returns
      # Test with a non-existent file to get a predictable error
      options = AdaptersSetup.test_options(adapter_keys)
      result = GitlockCore.investigate(:summary, "/this/file/does/not/exist.log", options)

      # Should get an error from the actual use case trying to read the file
      assert {:error, error} = result
      # The error format is {:io, path, reason}
      assert {:io, "/this/file/does/not/exist.log", :enoent} = error
    end

    test "forwards repo_path to use case unchanged", %{adapter_keys: adapter_keys} do
      # Use a unique path that we can identify in the error
      unique_path = "/very/unique/path/#{System.unique_integer()}.log"
      options = AdaptersSetup.test_options(adapter_keys)

      result = GitlockCore.investigate(:summary, unique_path, options)

      # The error should contain our unique path
      assert {:error, {:io, ^unique_path, :enoent}} = result
    end

    test "forwards options to use case unchanged", %{adapter_keys: adapter_keys} do
      # For blast_radius, we can test that options are passed through
      # by not providing required options
      options = AdaptersSetup.test_options(adapter_keys, %{dir: "/tmp"})
      result = GitlockCore.investigate(:blast_radius, "any.log", options)

      # Should get error about missing target_files from the use case
      assert {:error, "No target_files specified. Use --target-files option"} = result
    end

    test "provides empty map as default options", %{adapter_keys: adapter_keys} do
      # When no options provided, should still work with the real adapters
      # Create a unique path that won't exist
      nonexistent_path = "/nonexistent_#{System.unique_integer()}.log"

      # Try with explicit empty options
      options = AdaptersSetup.test_options(adapter_keys)
      result = GitlockCore.investigate(:summary, nonexistent_path, options)

      # Should get the expected error
      assert {:error, {:io, ^nonexistent_path, :enoent}} = result
    end
  end

  describe "available_investigations/0 - delegation behavior" do
    test "returns list from UseCaseFactory" do
      result = GitlockCore.available_investigations()

      # Should return the list from UseCaseFactory
      assert is_list(result)
      assert length(result) > 0
      assert Enum.all?(result, &is_atom/1)
    end

    test "returns all expected investigation types" do
      result = GitlockCore.available_investigations()

      expected = [
        :hotspots,
        :couplings,
        :coupled_hotspots,
        :knowledge_silos,
        :blast_radius,
        :summary
      ]

      assert Enum.all?(expected, &(&1 in result))
    end
  end

  describe "contract testing" do
    test "investigate always returns {:ok, _} or {:error, _}", %{adapter_keys: adapter_keys} do
      # Test various inputs to ensure consistent return format
      test_cases = [
        {:valid_type_bad_file, :summary, "/nonexistent.log", %{}},
        {:invalid_type, :not_a_type, "any_path", %{}},
        {:missing_required_opts, :blast_radius, "path", %{dir: "/tmp"}},
        {:empty_opts, :summary, "/bad/path", %{}}
      ]

      for {_name, type, path, additional_opts} <- test_cases do
        options = AdaptersSetup.test_options(adapter_keys, additional_opts)
        result = GitlockCore.investigate(type, path, options)

        # Check the shape of the result
        assert tuple_size(result) == 2
        assert elem(result, 0) in [:ok, :error]

        case result do
          {:ok, value} ->
            assert is_binary(value)

          {:error, reason} ->
            # Error can be either a string or a tuple
            assert is_binary(reason) or is_tuple(reason)
        end
      end
    end
  end

  describe "facade characteristics" do
    test "module has minimal public API" do
      # Check that we only expose the intended functions
      exports = GitlockCore.__info__(:functions)

      # Should only have our two main functions
      assert {:investigate, 2} in exports
      assert {:investigate, 3} in exports
      assert {:available_investigations, 0} in exports

      # Shouldn't have many other functions (maybe just module info stuff)
      assert length(exports) < 5
    end

    test "no business logic in facade", %{adapter_keys: adapter_keys} do
      # The facade should immediately delegate, meaning errors come from
      # the delegated modules, not from GitlockCore itself

      # This error comes from UseCaseFactory
      {:error, msg1} = GitlockCore.investigate(:bad_type, "path")
      assert msg1 == "Unknown investigation type: bad_type"

      # This error comes from the use case (VCS adapter)
      options = AdaptersSetup.test_options(adapter_keys)
      {:error, error} = GitlockCore.investigate(:summary, "/bad/path", options)
      assert {:io, "/bad/path", :enoent} = error
    end
  end
end
