defmodule GitlockCore.Adapters.FileSystem.LocalFileSystem do
  @moduledoc """
  Adapter implementing FileSystemPort using local file system operations.
  """

  @behaviour GitlockCore.Ports.FileSystemPort

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

  @impl true
  def exists?(file_path) do
    File.exists?(file_path)
  end

  @impl true
  def list_all_files(base_path) do
    base_path
    |> do_list_files()
    |> Enum.map(&Path.relative_to(&1, base_path))
  end

  defp do_list_files(path) do
    Path.wildcard(Path.join([path, "**", "*"]))
    |> Enum.filter(&File.regular?/1)
  end
end
