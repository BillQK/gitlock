defmodule GitlockHolmesCore.Domain.Entities.AuthorTest do
  use ExUnit.Case, async: true

  alias GitlockHolmesCore.Domain.Entities.Author

  describe "new/2" do
    test "creates a new author entity" do
      author = Author.new("Jane Smith")
      assert author.name == "Jane Smith"
      assert author.email == nil

      author_with_email = Author.new("John Doe", "john@example.com")
      assert author_with_email.name == "John Doe"
      assert author_with_email.email == "john@example.com"
    end
  end

  describe "display_name/1" do
    test "formats name without email" do
      author = Author.new("Jane Smith")
      assert Author.display_name(author) == "Jane Smith"
    end

    test "formats name with email" do
      author = Author.new("John Doe", "john@example.com")
      assert Author.display_name(author) == "John Doe <john@example.com>"
    end

    test "handles special characters" do
      author = Author.new("José García", "josé@example.com")
      assert Author.display_name(author) == "José García <josé@example.com>"
    end
  end

  describe "same_person?/2" do
    test "compares authors by email when available" do
      a1 = Author.new("John Doe", "john@example.com")
      a2 = Author.new("J. Doe", "john@example.com")
      a3 = Author.new("John Doe", "different@example.com")

      assert Author.same_person?(a1, a2)
      refute Author.same_person?(a1, a3)
    end

    test "compares authors by name when email not available" do
      a1 = Author.new("John Doe")
      a2 = Author.new("John Doe")
      a3 = Author.new("Jane Smith")

      assert Author.same_person?(a1, a2)
      refute Author.same_person?(a1, a3)
    end

    test "is case-insensitive" do
      a1 = Author.new("john doe", "john@example.com")
      a2 = Author.new("John Doe", "JOHN@example.com")

      assert Author.same_person?(a1, a2)
    end

    test "handles mixed email availability" do
      a1 = Author.new("John Doe", "john@example.com")
      a2 = Author.new("John Doe")
      a3 = Author.new("Jane Doe")

      assert Author.same_person?(a1, a2)
      refute Author.same_person?(a1, a3)
    end
  end
end
