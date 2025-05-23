defmodule GitlockHolmesCore.Adapters.FileSystem.LocalFileSystem do
  @moduledoc """
  Adapter implementing FileSystemPort using local file system operations.
  """

  @behaviour GitlockHolmesCore.Ports.FileSystemPort

  @impl true
  def read_file(file_path) do
    File.read(file_path)
  end

  @impl true
  def dir?(path) do
    File.dir?(path)
  end

  @impl true
  def regular?(path) do
    File.regular?(path)
  end

  @impl true
  def wildcard(pattern) do
    Path.wildcard(pattern)
  end

  @impl true
  def extname(file_path) do
    Path.extname(file_path)
  end
end
