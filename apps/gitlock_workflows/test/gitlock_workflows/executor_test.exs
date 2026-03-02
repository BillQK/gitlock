defmodule GitlockWorkflows.ExecutorTest do
  use ExUnit.Case, async: true

  alias GitlockWorkflows.{Executor, Pipeline, Node, Templates}

  describe "executable_nodes/1" do
    test "returns nodes with runtime implementations" do
      pipeline = Templates.build(:hotspot_scan)
      executable = Executor.executable_nodes(pipeline)

      types = Enum.map(executable, & &1.type)

      # DAG execution includes the trigger node
      assert :git_log in types
      assert :hotspot_detection in types
      assert :summary in types
    end

    test "full analysis has all compilable nodes" do
      pipeline = Templates.build(:full_analysis)
      executable = Executor.executable_nodes(pipeline)

      types = Enum.map(executable, & &1.type) |> MapSet.new()

      assert MapSet.member?(types, :git_log)
      assert MapSet.member?(types, :hotspot_detection)
      assert MapSet.member?(types, :coupling_detection)
      assert MapSet.member?(types, :knowledge_silo_detection)
      assert MapSet.member?(types, :code_age_analysis)
      assert MapSet.member?(types, :coupled_hotspot_analysis)
      assert MapSet.member?(types, :summary)

      # blast_radius has no runtime impl
      refute MapSet.member?(types, :blast_radius_analysis)
    end

    test "empty pipeline returns empty list" do
      pipeline = Pipeline.new("Empty")
      assert [] = Executor.executable_nodes(pipeline)
    end

    test "excludes output nodes without runtime implementations" do
      git = Node.new(:git_log)
      csv = Node.new(:csv_report)

      pipeline =
        Pipeline.new("Test")
        |> Pipeline.add_node(git)
        |> Pipeline.add_node(csv)

      executable = Executor.executable_nodes(pipeline)
      types = Enum.map(executable, & &1.type)

      assert :git_log in types
      refute :csv_report in types
    end
  end

  describe "templates produce valid pipelines" do
    test "hotspot_scan validates" do
      pipeline = Templates.build(:hotspot_scan)
      assert :ok = Pipeline.validate(pipeline)
    end

    test "full_analysis validates" do
      pipeline = Templates.build(:full_analysis)
      assert :ok = Pipeline.validate(pipeline)
    end

    test "knowledge_risk validates" do
      pipeline = Templates.build(:knowledge_risk)
      assert :ok = Pipeline.validate(pipeline)
    end
  end
end
