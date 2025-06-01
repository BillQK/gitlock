defmodule GitlockHolmesCoreTest do
  use ExUnit.Case, async: true

  import Mox

  alias GitlockHolmesCore

  setup do
    # Create a stub that always returns a file not found error with the input path
    stub(GitlockHolmesCore.Mocks.VersionControlMock, :get_commit_history, fn path, _opts ->
      {:error, {:io, path, :enoent}}
    end)

    # Return a simple report format
    stub(GitlockHolmesCore.Mocks.ReporterMock, :report, fn data, _opts ->
      {:ok, "Report: #{inspect(data)}"}
    end)

    :ok
  end

  describe "investigate/3 - delegation behavior" do
    test "delegates to UseCaseFactory with correct investigation type" do
      # Test that it calls UseCaseFactory with the right type
      # We can verify this by using a known invalid type
      result = GitlockHolmesCore.investigate(:definitely_not_a_valid_type, "path")

      # The error should come from UseCaseFactory
      assert {:error, "Unknown investigation type: definitely_not_a_valid_type"} = result
    end

    test "passes through the return value from use case execution" do
      # When given a valid investigation type, it should return whatever the use case returns
      # Test with a non-existent file to get a predictable error
      result = GitlockHolmesCore.investigate(:summary, "/this/file/does/not/exist.log")

      # Should get an error from the actual use case trying to read the file
      assert {:error, error} = result
      # The error format is {:io, path, reason}
      assert {:io, "/this/file/does/not/exist.log", :enoent} = error
    end

    test "forwards repo_path to use case unchanged" do
      # Use a unique path that we can identify in the error
      unique_path = "/very/unique/path/#{System.unique_integer()}.log"

      result = GitlockHolmesCore.investigate(:summary, unique_path)

      # The error should contain our unique path
      assert {:error, {:io, ^unique_path, :enoent}} = result
    end

    test "forwards options to use case unchanged" do
      # For blast_radius, we can test that options are passed through
      # by not providing required options
      result = GitlockHolmesCore.investigate(:blast_radius, "any.log", %{dir: "/tmp"})

      # Should get error about missing target_files from the use case
      assert {:error, "No target_files specified. Use --target-files option"} = result
    end

    test "provides empty map as default options" do
      # When no options provided, should pass empty map
      # This works with any investigation type
      result1 = GitlockHolmesCore.investigate(:summary, "/nonexistent.log")
      result2 = GitlockHolmesCore.investigate(:summary, "/nonexistent.log", %{})

      # Both should produce the same error
      assert {:error, {:io, "/nonexistent.log", :enoent}} = result1
      assert {:error, {:io, "/nonexistent.log", :enoent}} = result2
    end
  end

  describe "available_investigations/0 - delegation behavior" do
    test "returns list from UseCaseFactory" do
      result = GitlockHolmesCore.available_investigations()

      # Should return the list from UseCaseFactory
      assert is_list(result)
      assert length(result) > 0
      assert Enum.all?(result, &is_atom/1)
    end

    test "returns all expected investigation types" do
      result = GitlockHolmesCore.available_investigations()

      # These are the types we know UseCaseFactory supports
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
    test "investigate always returns {:ok, _} or {:error, _}" do
      # Test various inputs to ensure consistent return format
      test_cases = [
        {:valid_type_bad_file, :summary, "/nonexistent.log", %{}},
        {:invalid_type, :not_a_type, "any_path", %{}},
        {:missing_required_opts, :blast_radius, "path", %{dir: "/tmp"}},
        {:empty_opts, :summary, "/bad/path", %{}}
      ]

      for {_name, type, path, opts} <- test_cases do
        result = GitlockHolmesCore.investigate(type, path, opts)

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
      exports = GitlockHolmesCore.__info__(:functions)

      # Should only have our two main functions
      assert {:investigate, 2} in exports
      assert {:investigate, 3} in exports
      assert {:available_investigations, 0} in exports

      # Shouldn't have many other functions (maybe just module info stuff)
      assert length(exports) < 5
    end

    test "no business logic in facade" do
      # The facade should immediately delegate, meaning errors come from
      # the delegated modules, not from GitlockHolmesCore itself

      # This error comes from UseCaseFactory
      {:error, msg1} = GitlockHolmesCore.investigate(:bad_type, "path")
      assert msg1 == "Unknown investigation type: bad_type"

      # This error comes from the use case (VCS adapter)
      {:error, error} = GitlockHolmesCore.investigate(:summary, "/bad/path")
      assert {:io, "/bad/path", :enoent} = error
    end
  end
end
