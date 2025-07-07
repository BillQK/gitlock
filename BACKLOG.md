# Gitlock Project Backlog

## Sprint 6/11/2025 - 6/18/2025

- [x] Landing page - adding interactive demos and examples
- [x] BREAKING CHANGES - refactor cli pattern removing :dir options -> Needs to implement a new infrastructure for managing temp directories
- [x] Publish CLI tool to package managers (Homebrew for macOS)
- [x] Implement Code Age analysis methodology (identify stable vs volatile code based on age)
- [x] Add proper descriptions to README files in gitlock_cli and gitlock_core apps
- [x] Add `stdout-reporter` for printing to the terminal (Terminal Friendly)

## Sprint 6/18/2025 - 6/25/2025

- [ ] Design and implement database schema for SaaS features (users, projects, analysis history, subscription tiers, organizations)
- [ ] Set up app.js code structure for Hooks and interactive component
- [x] Implement a git log cache system - improving performance on large repositories
- [ ] Session Analysis Engine - a actor model pipeline system that create flexible, reusable, and interactive analyses
- [x] BUG: Search bar background issues - Chrome
- [ ] Develop a strategy to use Phoenix

## To Do

- [ ] Add proper descriptions to README files in gitlock_cli and gitlock_core apps
- [ ] Implement Docker support (Dockerfile exists but Docker installation method is marked as "Coming soon")
- [ ] Publish to Hex.pm package manager for easier installation
- [ ] Add support for more programming languages in complexity analysis (Ruby, Go, TypeScript, Java, etc.)
- [ ] Implement caching for Git log analysis to improve performance on large repositories
- [ ] Add progress indicators for long-running analyses
- [ ] Add support for GitLab and Bitbucket repositories (currently focused on Git)
- [ ] Implement terminal-based output formatting (currently outputs raw CSV/JSON)
- [ ] Add example analyses and sample reports to documentation
- [ ] Create comprehensive API documentation for library usage

## In Progress

- [ ] Phoenix web interface - completing the dashboard and visualization features
- [ ] Landing page - adding interactive demos and examples

## Done

- [x] Core analysis engine (hotspot detection, knowledge silos, coupling analysis, blast radius)
- [x] CLI implementation with multiple investigation types
- [x] CSV and JSON output reporters
- [x] Basic complexity analyzers for Elixir, JavaScript, and Python
- [x] Git integration for repository history analysis
- [x] Hexagonal architecture implementation
- [x] User authentication system (registration, login, settings)
- [x] Fly.io deployment configuration and documentation
- [x] GitHub Actions CI/CD pipeline
- [x] Comprehensive test coverage for core functionality
- [x] Error handling for edge cases
- [x] Input validation for CLI commands

---

## Backlog Items

### High Priority

- [ ] Publish CLI tool to package managers (Homebrew for macOS, Hex.pm for Elixir ecosystem)
- [ ] Design and implement database schema for SaaS features (users, projects, analysis history, subscription tiers)
- [ ] Build interactive web UI for triggering analyses and persisting results to database
- [ ] Add code coverage reporting to CI pipeline (ExCoveralls integration)
- [ ] Implement web dashboard for analysis results visualization
- [ ] Add real-time analysis progress tracking in web UI
- [ ] Create API endpoints for programmatic access to analysis results
- [ ] Add batch analysis support for multiple repositories
- [ ] Implement analysis result storage and history tracking
- [ ] Add export functionality for reports (PDF, HTML formats)
- [ ] Create onboarding flow for new users in web app
- [ ] Implement Burrito standalone binaries to eliminate Erlang dependency for end users

### Medium Priority

- [ ] Implement Code Age analysis methodology (identify stable vs volatile code based on age)
- [ ] Design and implement LLM integration for intelligent code insights and natural language analysis summaries
- [ ] Create interactive visualizations for analysis results (d3.js/Chart.js integration)
- [ ] Add filtering by file patterns/extensions in CLI
- [ ] Implement analysis comparison between different time periods
- [ ] Add support for analyzing multiple repositories simultaneously
- [ ] Integrate with GitHub/GitLab APIs for automatic repository analysis
- [ ] Add team collaboration features (sharing reports, comments)
- [ ] Implement webhook integrations (Slack, Discord notifications)
- [ ] Add support for custom complexity metrics and thresholds
- [ ] Create dashboard for tracking code health trends over time
- [ ] Add support for monorepo analysis with project boundaries
- [ ] Implement incremental analysis (only analyze changes since last run)
- [ ] Add natural language summaries of analysis results
- [ ] Recommend code reviewers using knowledge silos
- [ ] Maintains expertise map using knowledge silos
- [ ] Set up app.js code structure for Hooks and interactive component
- [ ] Add inbound port `GitlockCore.Ports.AnalysisPort` behavior for `investigate/3` and `available_investigations/0` to enable proper Mox testing across CLI/Web apps
- [ ] Add `stdout-reporter` for printing to the terminal (Terminal Friendly)

### Low Priority

- [ ] Add support for Mercurial and SVN version control systems
- [ ] Create browser extension for GitHub/GitLab integration
- [ ] Implement machine learning for predictive hotspot detection
- [ ] Add internationalization (i18n) support
- [ ] Create mobile-responsive views for reports
- [ ] Add support for analyzing compiled languages (C++, Rust)
- [ ] Implement additional code smell detection patterns
- [ ] Create plugin system for custom analyzers
- [ ] Add Git hooks for pre-commit analysis
- [ ] Implement analysis scheduling and automation
- [ ] Add support for code review integration
- [ ] Create VS Code extension for inline analysis results

---

## Technical Debt

- [ ] Refactor CLI argument parsing for better extensibility
- [ ] Optimize memory usage for very large repositories
- [ ] Improve error messages for better user experience
- [ ] Add performance benchmarks for analysis operations
- [ ] Standardize logging format across all modules

---

## Notes

- Project is inspired by Adam Tornhill's "Your Code as a Crime Scene"
- Currently supports Git repositories with Elixir, JavaScript, and Python
- Phoenix web interface is live at gitlock.fly.dev
- Fly.io deployment is fully configured with CI/CD
- Consider creating video tutorials for common use cases
- Focus on improving visualization and reporting features next
- Planning to add Code Age methodology from "Your Code as a Crime Scene" to identify stable vs volatile code patterns
- LLM integration will provide intelligent insights and natural language explanations of analysis results
- Database schema needed to support multi-tenant SaaS features with project management and analysis history

---

## Features Ideas

- [ ] Smart Reviewer Matching - Score reviewers based on familiarity, activity, quality, and workload
- [ ] Developer Contribution Summary: Automatically generate comprehensive narratives of each developer's impact, expertise, and growth by using LLMs to analyze their commits, PRs, reviews, and code changes—transforming git history into actionable intelligence for performance reviews, expertise discovery, and team planning.
- [ ] Automated PR Creation - Generate pull requests with refactored code and detailed explanations of improvements
- [ ] GitHub API Integration - Automatically create branches, commit changes, and submit PRs to target repositories
- [ ] LLM Refactoring Suggestions - Send hotspot code to GPT-4 with specialized prompts to generate refactoring recommendations
