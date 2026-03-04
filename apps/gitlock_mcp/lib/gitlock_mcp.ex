defmodule GitlockMCP do
  @moduledoc """
  Gitlock MCP Server — codebase intelligence for AI coding agents.

  Exposes behavioral code analysis (hotspots, coupling, ownership, risk)
  as MCP tools that AI coding agents like Claude Code and Cursor can use
  to write safer code.

  ## How it works

  1. Agent connects via stdio
  2. First tool call triggers repo indexing (parses git log, runs analysis)
  3. Results cached in memory — subsequent queries are instant
  4. Agent gets risk context before modifying files

  ## Tools

  - `gitlock_assess_file` — Risk assessment for a specific file
  - `gitlock_hotspots` — Find riskiest files in a directory
  - `gitlock_file_ownership` — Who owns this file? Knowledge silo risk?
  - `gitlock_find_coupling` — What files change together with this one?
  - `gitlock_review_pr` — Analyze a set of changed files together
  - `gitlock_repo_summary` — Overview of codebase health
  """
end
