defmodule GitlockHolmesCore.Domain.Entities.Author do
  @moduledoc """
  Represents an author who made changes to the codebase.

  This entity stores information about commit authors, including their name
  and optional email address.
  """

  @type t :: %__MODULE__{
          name: String.t(),
          email: String.t() | nil
        }

  defstruct [:name, :email]

  @doc """
  Creates a new author entity.

  ## Parameters
    * `name` - The author's name
    * `email` - The author's email address (optional)
    
  ## Returns
    A new Author struct
    
  ## Examples
      
      iex> Author.new("Jane Smith")
      %Author{name: "Jane Smith", email: nil}
      
      iex> Author.new("John Doe", "john@example.com")
      %Author{name: "John Doe", email: "john@example.com"}
  """
  @spec new(String.t(), String.t() | nil) :: t()
  def new(name, email \\ nil) do
    %__MODULE__{name: name, email: email}
  end

  @doc """
  Returns a formatted display name for the author.

  If an email is present, formats as "Name <email>", otherwise returns just the name.

  ## Parameters
    * `author` - The author entity
    
  ## Returns
    A formatted string representation of the author
    
  ## Examples
      
      iex> author = Author.new("Jane Smith")
      iex> Author.display_name(author)
      "Jane Smith"
      
      iex> author = Author.new("John Doe", "john@example.com")
      iex> Author.display_name(author)
      "John Doe <john@example.com>"
  """
  @spec display_name(t()) :: String.t()
  def display_name(%__MODULE__{name: name, email: nil}), do: name
  def display_name(%__MODULE__{name: name, email: email}), do: "#{name} <#{email}>"

  @doc """
  Determines if two authors are the same person.

  Compares authors based on their email if available, otherwise falls back to name.
  This helps identify the same author who might have different name variations.

  ## Parameters
    * `author1` - First author to compare
    * `author2` - Second author to compare
    
  ## Returns
    `true` if the authors are likely the same person, `false` otherwise
    
  ## Examples
      
      iex> a1 = Author.new("John Doe", "john@example.com")
      iex> a2 = Author.new("J. Doe", "john@example.com")
      iex> Author.same_person?(a1, a2)
      true
      
      iex> a1 = Author.new("John Doe")
      iex> a2 = Author.new("Jane Smith")
      iex> Author.same_person?(a1, a2)
      false
  """
  @spec same_person?(t(), t()) :: boolean()
  def same_person?(%__MODULE__{email: email1}, %__MODULE__{email: email2})
      when is_binary(email1) and is_binary(email2) and email1 != "",
      do: String.downcase(email1) == String.downcase(email2)

  def same_person?(%__MODULE__{name: name1}, %__MODULE__{name: name2}),
    do: String.downcase(name1) == String.downcase(name2)
end
