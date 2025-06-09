defmodule GitlockCLI.RepositorySource do
  @moduledoc """
  Handles determination of repository sources and their types.

  Supports local repositories, remote URLs, and log files with automatic type detection.
  """

  @doc """
  Determines the repository source and type with priority order:
  1. --repo (primary option)
  2. --url (for remote repositories)
  3. --log (legacy option)
  4. Current directory (default)

  Returns a tuple of {source_path, source_type}
  """
  def determine(options) do
    cond do
      # Primary option
      options[:repo] ->
        {options[:repo], determine_source_type(options[:repo])}

      # Remote URL option
      options[:url] ->
        {options[:url], :url}

      # Legacy option (with deprecation warning)
      options[:log] ->
        IO.puts(:stderr, "Warning: The --log option is deprecated. Please use --repo instead.")
        {options[:log], :log_file}

      # Default to current directory
      true ->
        {".", :local_repo}
    end
  end

  @doc """
  Determines the type of a repository source based on its path/URL characteristics.

  Returns one of: :url, :local_repo, :log_file
  """
  def determine_source_type(source) do
    cond do
      # Remote repository URL
      String.match?(source, ~r/^(https?:\/\/|git@)/) ->
        :url

      # Local Git repository
      File.dir?(source) &&
          (File.dir?(Path.join(source, ".git")) ||
             File.exists?(Path.join(source, ".git"))) ->
        :local_repo

      # Existing file - assume it's a log file
      File.regular?(source) ->
        :log_file

      # For non-existent paths, default to log_file for backward compatibility
      true ->
        :log_file
    end
  end

  @doc """
  Validates that the repository source exists and is accessible.
  """
  def validate_source(source, source_type) do
    case source_type do
      :url ->
        # For URLs, we can't validate access without making a network call
        # Let the core module handle validation
        :ok

      :local_repo ->
        if File.dir?(source) do
          :ok
        else
          {:error, "Repository directory does not exist: #{source}"}
        end

      :log_file ->
        if File.regular?(source) do
          :ok
        else
          {:error, "Log file does not exist: #{source}"}
        end
    end
  end

  @doc """
  Returns a human-readable description of the source type.
  """
  def describe_source_type(source_type) do
    case source_type do
      :url -> "remote repository"
      :local_repo -> "local repository"
      :log_file -> "log file"
    end
  end
end
