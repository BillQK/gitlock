defmodule GitlockHolmesCore.Adapters.VCS.Git do
  @moduledoc """
  Git adapter for accessing Git commit history from various sources.

  This adapter can handle multiple repository sources:

  - Local Git repositories (directly analyzes using git command)
  - Git log files (parses pre-generated log files)
  - Remote Git repositories (clones temporarily and analyzes)
  """

  @behaviour GitlockHolmesCore.Ports.VersionControlPort

  alias GitlockHolmesCore.Domain.Entities.{Commit, Author}
  alias GitlockHolmesCore.Domain.Values.FileChange

  @type error_reason ::
          {:io, String.t(), term()}
          | {:parse, String.t()}
          | {:git, String.t()}
          | {:commit, String.t()}

  @type get_history_result :: {:ok, [Commit.t()]} | {:error, error_reason()}

  @impl true
  @doc """
  Gets commit history from a Git repository source.

  ## Parameters

    * `source` - Path to a local repo, log file, or URL to a remote repo
    * `options` - Options for filtering and processing the history
  """
  @spec get_commit_history(String.t(), map()) :: get_history_result()
  def get_commit_history(log_file, options) do
    # Check if a source_type is explicitly provided in options
    source_type = options[:source_type] || determine_source_type(log_file)

    case source_type do
      :log_file ->
        # The original behavior - assume input is a log file
        with {:ok, content} <- File.read(log_file) |> annotate_error({:io, log_file, :enoent}) do
          parse_git_log(content)
        end

      :local_repo ->
        generate_and_parse_git_log(log_file, options)

      :url ->
        clone_and_analyze_repo(log_file, options)

      :unknown ->
        # When type is unknown, default to trying it as a log file for backward compatibility
        with {:ok, content} <- File.read(log_file) |> annotate_error({:io, log_file, :enoent}) do
          parse_git_log(content)
        end
    end
  end

  # Determine what kind of source we're dealing with
  def determine_source_type(source) do
    cond do
      # Remote repository URL
      String.match?(source, ~r/^(https?:\/\/|git@)/) ->
        :url

      # Local Git repository
      File.dir?(source) &&
          (File.dir?(Path.join(source, ".git")) || File.exists?(Path.join(source, ".git"))) ->
        :local_repo

      # Existing file - in tests, we assume any existing file is a log file
      File.regular?(source) ->
        :log_file

      String.ends_with?(source, [".log", ".txt"]) ->
        :log_file

      # For non-existent paths, we'll try as log file and let File.read return the appropriate error
      true ->
        :unknown
    end
  end

  # Generate a git log from a local repository and parse it
  defp generate_and_parse_git_log(repo_path, options) do
    # Validate repo path is a git repository
    if !File.dir?(Path.join(repo_path, ".git")) && !File.exists?(Path.join(repo_path, ".git")) do
      {:error, {:io, repo_path, :enoent}}
    else
      # Generate git log command with appropriate filters
      git_cmd = build_git_log_command(options)

      # Change to repo directory and execute command
      case System.cmd("git", git_cmd, cd: repo_path, stderr_to_stdout: true) do
        {output, 0} ->
          parse_git_log(output)

        {error, code} ->
          {:error, {:git, "Git command failed with code #{code}: #{error}"}}
      end
    end
  end

  # Build git log command based on options
  defp build_git_log_command(options) do
    base_cmd = [
      "log",
      "--all",
      "-M",
      "-C",
      "--numstat",
      "--date=short",
      "--pretty=format:--%h--%cd--%cn"
    ]

    # Add filters based on options
    cmd = base_cmd

    # Add date filter if specified
    cmd = if options[:since], do: cmd ++ ["--since=#{options[:since]}"], else: cmd
    cmd = if options[:until], do: cmd ++ ["--until=#{options[:until]}"], else: cmd

    # Add author filter if specified
    cmd = if options[:author], do: cmd ++ ["--author=#{options[:author]}"], else: cmd

    # Add path filters if specified
    cmd = if options[:paths], do: cmd ++ ["--"] ++ options[:paths], else: cmd

    cmd
  end

  # Clone a remote repository to a temporary directory and analyze it
  defp clone_and_analyze_repo(url, options) do
    # Create a temporary directory
    tmp_dir = System.tmp_dir!() |> Path.join("gitlock_holmes_#{:rand.uniform(1_000_000)}")
    File.mkdir_p!(tmp_dir)

    try do
      # Clone the repository
      case System.cmd("git", ["clone", "--depth", "100", url, tmp_dir]) do
        {_, 0} ->
          # Successfully cloned, now analyze
          generate_and_parse_git_log(tmp_dir, options)

        {error, code} ->
          {:error, {:git, "Git clone failed with code #{code}: #{error}"}}
      end
    after
      # Clean up temporary directory
      File.rm_rf(tmp_dir)
    end
  end

  # Parse git log content
  defp parse_git_log(content) do
    result =
      content
      |> String.split("\n\n", trim: true)
      |> Enum.reduce_while({:ok, []}, fn commit_text, {:ok, commits} ->
        case parse_commit(commit_text) do
          {:ok, commit} -> {:cont, {:ok, [commit | commits]}}
          {:error, reason} -> {:halt, {:error, reason}}
        end
      end)

    case result do
      {:ok, commits} -> {:ok, Enum.reverse(commits)}
      error -> error
    end
  end

  # Parse a single commit entry
  defp parse_commit(commit_text) do
    with {:ok, lines} <- extract_lines(commit_text),
         {:ok, header, file_lines} <- split_header_and_files(lines),
         {:ok, id, date, author_name} <- parse_header(header),
         {:ok, file_changes} <- parse_file_changes(file_lines) do
      # Create the commit with parsed data
      author = Author.new(author_name)
      {:ok, Commit.new(id, author, date, "", file_changes)}
    end
  end

  # Extract lines from commit text
  defp extract_lines(commit_text) do
    lines = String.split(commit_text, "\n", trim: true)
    if Enum.empty?(lines), do: {:error, {:commit, "Empty commit text"}}, else: {:ok, lines}
  end

  # Split header and file lines
  defp split_header_and_files([header | file_lines]), do: {:ok, header, file_lines}

  # Parse header information
  defp parse_header(header) do
    case Regex.run(~r/--(.+?)--(.+?)--(.+)/, header) do
      [_, id, date, author] -> {:ok, id, date, author}
      _ -> {:error, {:commit, "Invalid commit header format: #{header}"}}
    end
  end

  # Parse file changes
  defp parse_file_changes(file_lines) do
    file_lines
    |> Enum.filter(&String.contains?(&1, "\t"))
    |> Enum.reduce_while({:ok, []}, fn line, {:ok, changes} ->
      parse_file_change_line(line, changes)
    end)
    |> case do
      {:ok, changes} -> {:ok, Enum.reverse(changes)}
    end
  end

  # Parse a single file change line
  defp parse_file_change_line(line, changes) do
    case String.split(line, "\t", parts: 3) do
      [added, deleted, file] ->
        {:cont, {:ok, [FileChange.new(file, added, deleted) | changes]}}

      _ ->
        # Skip malformed lines
        {:cont, {:ok, changes}}
    end
  end

  # Helper to annotate error tuples with additional context
  defp annotate_error({:ok, value}, _context), do: {:ok, value}
  defp annotate_error({:error, _reason}, context), do: {:error, context}
end
