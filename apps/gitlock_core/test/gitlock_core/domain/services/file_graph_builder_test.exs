defmodule GitlockCore.Domain.Services.FileGraphBuilderTest do
  use ExUnit.Case, async: true

  alias GitlockCore.Domain.Services.FileGraphBuilder
  alias GitlockCore.Domain.Entities.{Commit, Author}
  alias GitlockCore.Domain.Values.{FileChange, ComplexityMetrics}

  describe "create_from_commits/4" do
    test "builds a graph with correct nodes and edges" do
      # Create test commits where files change together
      commits = [
        create_test_commit("c1", "2023-01-01", [
          {"lib/auth/session.ex", 10, 5},
          {"lib/auth/token.ex", 7, 3}
        ]),
        create_test_commit("c2", "2023-01-02", [
          {"lib/auth/session.ex", 5, 2},
          {"lib/user/profile.ex", 15, 0}
        ])
      ]

      # Create test complexity metrics
      complexity_map = %{
        "lib/auth/session.ex" => ComplexityMetrics.new("lib/auth/session.ex", 100, 12, :elixir),
        "lib/auth/token.ex" => ComplexityMetrics.new("lib/auth/token.ex", 80, 8, :elixir),
        "lib/user/profile.ex" => ComplexityMetrics.new("lib/user/profile.ex", 120, 5, :elixir)
      }

      # Test creating the graph
      graph = FileGraphBuilder.create_from_commits(commits, complexity_map)

      # Verify nodes
      assert map_size(graph.nodes) == 3
      assert graph.nodes["lib/auth/session.ex"].revisions == 2
      assert graph.nodes["lib/auth/session.ex"].complexity == 12

      # Verify edges (coupling relationships)
      assert length(graph.edges) > 0

      # Check component detection
      assert graph.nodes["lib/auth/session.ex"].component == "auth"
      assert graph.nodes["lib/user/profile.ex"].component == "user"
    end

    test "handles empty commit list" do
      graph = FileGraphBuilder.create_from_commits([])
      assert map_size(graph.nodes) == 0
      assert length(graph.edges) == 0
    end

    # Helper for creating test commits
    defp create_test_commit(id, date, file_changes) do
      changes =
        Enum.map(file_changes, fn {path, added, deleted} ->
          FileChange.new(path, to_string(added), to_string(deleted))
        end)

      Commit.new(
        id,
        Author.new("Test Author"),
        date,
        "Test commit",
        changes
      )
    end
  end

  describe "build_nodes/6" do
    test "correctly builds node metadata with component detection" do
      # Test data
      file_paths = ["lib/auth/session.ex", "lib/user/profile.ex"]

      authors_by_file = %{
        "lib/auth/session.ex" => ["Alice", "Bob"],
        "lib/user/profile.ex" => ["Carol"]
      }

      file_revisions = %{
        "lib/auth/session.ex" => 5,
        "lib/user/profile.ex" => 3
      }

      complexity_map = %{
        "lib/auth/session.ex" => ComplexityMetrics.new("lib/auth/session.ex", 100, 10, :elixir)
      }

      nodes =
        FileGraphBuilder.build_nodes(
          file_paths,
          authors_by_file,
          file_revisions,
          complexity_map,
          MapSet.new(),
          %{}
        )

      # Check component detection
      assert nodes["lib/auth/session.ex"].component == "auth"
      assert nodes["lib/user/profile.ex"].component == "user"

      # Check author lists
      assert nodes["lib/auth/session.ex"].authors == ["Alice", "Bob"]

      # Check complexity values
      assert nodes["lib/auth/session.ex"].complexity == 10
      assert nodes["lib/auth/session.ex"].loc == 100

      # Check revisions
      assert nodes["lib/auth/session.ex"].revisions == 5
    end
  end
end
