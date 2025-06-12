# Gitlock Project Backlog

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
- [ ] Use the term "Repository Intelligence"
- [ ] Use case: recommend code reviewers using knowledge silos
- [ ] Use case: knowledge silos could be use to maintains expertise map

## In Progress

- [ ] Phoenix web interface - completing the dashboard and visualization features
- [ ] Landing page - adding interactive demos and examples

## Done

- [x] Core analysis engine (hotspot detection, knowledge silos, coupling analysis, blast radius)
- [x] CLI implementation with multiple investigation types
- [x] CSV/JSON/STDOUT output reporters
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

- [ ] Add code coverage reporting to CI pipeline (ExCoveralls integration)
- [ ] Implement web dashboard for analysis results visualization
- [ ] Add real-time analysis progress tracking in web UI
- [ ] Create API endpoints for programmatic access to analysis results
- [ ] Add batch analysis support for multiple repositories
- [ ] Implement analysis result storage and history tracking
- [ ] Add export functionality for reports (PDF, HTML formats)
- [ ] Create onboarding flow for new users in web app

### Medium Priority

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

---

## Features Ideas

- [ ] Smart Reviewer Matching - Score reviewers based on familiarity, activity, quality, and workload
- [ ] Developer Contribution Summary: Automatically generate comprehensive narratives of each developer's impact, expertise, and growth by using LLMs to analyze their commits, PRs, reviews, and code changes—transforming git history into actionable intelligence for performance reviews, expertise discovery, and team planning.
