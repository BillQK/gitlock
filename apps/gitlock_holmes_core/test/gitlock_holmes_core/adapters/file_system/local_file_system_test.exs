defmodule GitlockHolmesCore.Adapters.FileSystem.LocalFileSystemTest do
  use ExUnit.Case, async: true

  alias GitlockHolmesCore.Adapters.FileSystem.LocalFileSystem

  # Use Briefly for temporary files and directories
  setup do
    # Create a temporary directory for tests
    {:ok, tmp_dir} = Briefly.create(directory: true)

    # Return the temporary directory path
    # Briefly will automatically clean up when the test finishes
    {:ok, %{tmp_dir: tmp_dir}}
  end

  test "read_file/1 reads file content", %{tmp_dir: dir} do
    # Create a temporary file with Briefly
    {:ok, file_path} = Briefly.create(directory: false)
    File.write!(file_path, "test content")

    # Test reading an existing file
    assert {:ok, "test content"} = LocalFileSystem.read_file(file_path)

    # Test reading a non-existent file
    non_existent = Path.join(dir, "does_not_exist.txt")
    assert {:error, :enoent} = LocalFileSystem.read_file(non_existent)
  end

  test "dir?/1 identifies directories", %{tmp_dir: dir} do
    # Create a temporary file with Briefly
    {:ok, file_path} = Briefly.create()

    # Test directory identification
    assert LocalFileSystem.dir?(dir)
    refute LocalFileSystem.dir?(file_path)
    refute LocalFileSystem.dir?(Path.join(dir, "non_existent"))
  end

  test "regular?/1 identifies regular files", %{tmp_dir: dir} do
    # Create a temporary file with Briefly
    {:ok, file_path} = Briefly.create()

    # Test file identification
    assert LocalFileSystem.regular?(file_path)
    refute LocalFileSystem.regular?(dir)
    refute LocalFileSystem.regular?(Path.join(dir, "non_existent"))
  end

  test "wildcard/1 finds matching files", %{tmp_dir: dir} do
    # Create test files with specific extensions
    File.write!(Path.join(dir, "a.txt"), "")
    File.write!(Path.join(dir, "b.txt"), "")
    File.write!(Path.join(dir, "c.ex"), "")

    # Test wildcard matching
    txt_files = LocalFileSystem.wildcard(Path.join(dir, "*.txt"))
    assert length(txt_files) == 2
    assert Enum.all?(txt_files, &String.ends_with?(&1, ".txt"))

    ex_files = LocalFileSystem.wildcard(Path.join(dir, "*.ex"))
    assert length(ex_files) == 1
  end

  test "extname/1 returns file extension" do
    assert LocalFileSystem.extname("file.txt") == ".txt"
    assert LocalFileSystem.extname("path/to/file.ex") == ".ex"
    assert LocalFileSystem.extname("no_extension") == ""
  end

  test "exists?/1 checks if path exists", %{tmp_dir: dir} do
    # Create a temporary file with Briefly
    {:ok, file_path} = Briefly.create()

    # Test existence checks
    assert LocalFileSystem.exists?(dir)
    assert LocalFileSystem.exists?(file_path)
    refute LocalFileSystem.exists?(Path.join(dir, "non_existent"))
  end

  test "list_all_files/1 lists files recursively", %{tmp_dir: dir} do
    # Create file structure for testing
    File.write!(Path.join(dir, "root.txt"), "")

    subdir = Path.join(dir, "subdir")
    File.mkdir_p!(subdir)
    File.write!(Path.join(subdir, "nested.txt"), "")

    # Test recursive file listing
    files = LocalFileSystem.list_all_files(dir)

    assert length(files) == 2
    assert "root.txt" in files
    assert "subdir/nested.txt" in files
  end

  test "implements FileSystemPort behavior" do
    behaviors = LocalFileSystem.__info__(:attributes)[:behaviour] || []
    assert GitlockHolmesCore.Ports.FileSystemPort in behaviors

    # Verify all callbacks are implemented
    port_callbacks = GitlockHolmesCore.Ports.FileSystemPort.behaviour_info(:callbacks)
    module_functions = LocalFileSystem.__info__(:functions)

    for {function, arity} <- port_callbacks do
      assert {function, arity} in module_functions,
             "#{function}/#{arity} callback not implemented"
    end
  end

  # Example of using Briefly for a VCS log file test
  test "handles reading log files" do
    # Sample log content
    log_content = """
    --abc123--2023-01-01--Test Author
    10\t5\tlib/file.ex

    --def456--2023-01-02--Another Author
    8\t3\tlib/another_file.ex
    """

    # Create temporary log file
    {:ok, log_file} = Briefly.create()
    File.write!(log_file, log_content)

    # Test reading the log file
    assert {:ok, ^log_content} = LocalFileSystem.read_file(log_file)
  end
end
