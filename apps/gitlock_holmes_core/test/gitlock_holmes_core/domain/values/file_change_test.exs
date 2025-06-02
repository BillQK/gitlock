defmodule GitlockHolmesCore.Domain.Values.FileChangeTest do
  use ExUnit.Case, async: true

  alias GitlockHolmesCore.Domain.Values.FileChange

  describe "new/3" do
    test "creates a file change with numeric values" do
      change = FileChange.new("lib/test.ex", 10, 5)

      assert change.entity == "lib/test.ex"
      assert change.loc_added == 10
      assert change.loc_deleted == 5
    end

    test "creates a file change with string values" do
      change = FileChange.new("lib/test.ex", "10", "5")

      assert change.entity == "lib/test.ex"
      assert change.loc_added == "10"
      assert change.loc_deleted == "5"
    end

    test "handles binary file changes with dash notation" do
      change = FileChange.new("image.png", "-", "-")

      assert change.entity == "image.png"
      assert change.loc_added == "-"
      assert change.loc_deleted == "-"
    end
  end

  describe "total_churn/1" do
    test "sums additions and deletions" do
      # Integer values
      change_int = FileChange.new("test.ex", 10, 5)
      assert FileChange.total_churn(change_int) == 15

      # String values
      change_str = FileChange.new("test.ex", "10", "5")
      assert FileChange.total_churn(change_str) == 15

      # Mixed values
      change_mixed = FileChange.new("test.ex", 10, "5")
      assert FileChange.total_churn(change_mixed) == 15
    end

    test "handles binary files with dash notation" do
      change = FileChange.new("binary.bin", "-", "-")
      assert FileChange.total_churn(change) == 0
    end

    test "handles invalid string values" do
      change = FileChange.new("test.ex", "invalid", "5")
      assert FileChange.total_churn(change) == 5
    end
  end

  describe "binary?/1" do
    test "identifies binary files" do
      binary = FileChange.new("image.png", "-", "-")
      assert FileChange.binary?(binary)
    end

    test "identifies text files" do
      text = FileChange.new("test.ex", 10, 5)
      refute FileChange.binary?(text)
    end
  end
end
