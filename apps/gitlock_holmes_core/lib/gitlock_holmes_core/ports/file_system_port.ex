defmodule GitlockHolmesCore.Ports.FileSystemPort do
  @moduledoc """
  Port for file system operations.

  This port abstracts file system access, allowing the domain to perform
  file operations without direct dependency on the file system implementation.
  """

  @type read_result :: {:ok, binary()} | {:error, term()}

  @doc """
  Reads a file from the file system.

  ## Parameters
    * `file_path` - Path to the file to read
    
  ## Returns
    * `{:ok, content}` - Successfully read the file
    * `{:error, reason}` - Failed to read the file
  """
  @callback read_file(file_path :: String.t()) :: read_result()

  @doc """
  Checks if a path exists and is a directory.

  ## Parameters
    * `path` - Path to check
    
  ## Returns
    * `boolean` - True if the path exists and is a directory
  """
  @callback dir?(path :: String.t()) :: boolean()

  @doc """
  Checks if a path exists and is a regular file.

  ## Parameters
    * `path` - Path to check
    
  ## Returns
    * `boolean` - True if the path exists and is a regular file
  """
  @callback regular?(path :: String.t()) :: boolean()

  @doc """
  Lists all files in a directory matching a pattern.

  ## Parameters
    * `pattern` - Wildcard pattern to match files
    
  ## Returns
    * `[String.t()]` - List of file paths matching the pattern
  """
  @callback wildcard(pattern :: String.t()) :: [String.t()]

  @doc """
  List the files extensions name


  ## Parameters
    * `file_path` - The file path with the extension
    
  ## Returns
    * `String.t()` - The string of the extension
  """
  @callback extname(file_path :: String.t()) :: String.t()

  @doc """
  Returns true if the file exists


  ## Parameters
    * `file_path` - The file path with the extension
    
  ## Returns
    * `Boolean` - True or False
  """
  @callback exists?(file_path :: String.t()) :: boolean()
  @doc """
  Lists all regular files recursively from a base path.

  This function traverses the directory tree starting from `base_path`
  and returns all regular files found. Symbolic links are not followed
  to avoid infinite loops.

  ## Parameters
    * `base_path` - Starting directory for the file listing

  ## Returns
    * List of relative file paths from the base path
    * Empty list if base path doesn't exist or isn't a directory

  ## Examples
      iex> FileSystem.list_all_files("lib")
      ["core/domain.ex", "core/services/analyzer.ex", ...]
      
      iex> FileSystem.list_all_files("nonexistent")
      []
  """
  @callback list_all_files(base_path :: String.t()) :: [String.t()]
end
