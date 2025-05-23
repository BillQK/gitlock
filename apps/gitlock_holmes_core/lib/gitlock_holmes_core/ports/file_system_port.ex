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
end
