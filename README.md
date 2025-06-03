# GitlockHolmes: Forensic Code Analysis Tool

<p align="center">
  <img src="assets/logo.svg" alt="GitlockHolmes Logo" width="250"/>
  <p align="center"><em>Uncovering the hidden stories in your codebase</em></p>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#usage">Usage</a> •
  <a href="#understanding-results">Understanding Results</a> •
  <a href="#advanced-usage">Advanced Usage</a> •
  <a href="#faq">FAQ</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

**GitlockHolmes** is a code forensics tool inspired by Adam Tornhill's "Your Code as Crime Scene" methodology. It analyzes your Git repository history to identify hotspots, knowledge silos, and other code health indicators that can help prioritize refactoring efforts and improve code quality.

> _"Just as detectives use forensic techniques to reconstruct crime scenes, GitlockHolmes examines your codebase's history to reveal the story behind your code."_

## Features

- 🔍 **Hotspot Detection**: Find frequently changed files with high complexity, which are more likely to contain bugs
- 🧠 **Knowledge Silo Analysis**: Identify files owned primarily by one developer, creating team risk
- 🔗 **Temporal Coupling Analysis**: Discover files that tend to change together frequently, revealing hidden dependencies
- ⚡ **Coupled Hotspots**: Detect pairs of risky files that are also coupled, representing compounded risk
- 💥 **Blast Radius Analysis**: Assess the potential impact of changing specific files
- 📊 **Flexible Output**: Support for CSV, JSON and other output formats
- 📝 **Summary Statistics**: Get high-level repository statistics

## Installation

### From Source

```bash
# Clone the repository
git clone https://github.com/yourusername/gitlock_holmes.git
cd gitlock_holmes

# Install dependencies and build
mix deps.get
mix build.all

# Optional: Add to your path
cp bin/gitlock_holmes /usr/local/bin/
```

### Using Mix (Coming soon)

```bash
# Not yet available
mix escript.install hex gitlock_holmes
```

### Docker (Coming soon)

```bash
# Pull the Docker image
docker pull yourusername/gitlock_holmes:latest

# Run GitlockHolmes in Docker
docker run -v $(pwd):/code yourusername/gitlock_holmes:latest hotspots --repo /code
```

## Quick Start

Analyze your repository with individual commands:

```bash
# Find hotspots (complex, frequently changed files)
gitlock_holmes hotspots --repo /path/to/repo --dir /path/to/code

# Identify knowledge silos (files with concentrated ownership)
gitlock_holmes knowledge-silos --repo /path/to/repo
```

## Usage

GitlockHolmes provides several investigation types that analyze your code from different perspectives:

```bash
# General usage
gitlock_holmes [investigation] [options]
```

### Available Investigations

| Command            | Description                                   | Key Metrics                            |
| ------------------ | --------------------------------------------- | -------------------------------------- |
| `summary`          | General repository statistics                 | Commits, Authors, Files                |
| `hotspots`         | Find risky, complex, frequently changed files | Revisions, Complexity, Risk Score      |
| `knowledge-silos`  | Find files with concentrated ownership        | Main Author, Ownership %, Author Count |
| `couplings`        | Find files that change together               | Coupling Degree, Windows, Trend        |
| `coupled-hotspots` | Find files that are both risky and coupled    | Combined Risk, Individual Risks        |
| `blast-radius`     | Analyze impact of changing specific files     | Affected Files, Components, Risk Score |

### Repository Source Options

GitlockHolmes accepts input from multiple sources:

| Option         | Description                                       | Default |
| -------------- | ------------------------------------------------- | ------- |
| `--repo`, `-r` | Path to repository or log file (recommended)      | `.`     |
| `--url`, `-u`  | URL to remote Git repository                      | None    |
| `--log`, `-l`  | Path to log file (deprecated, use --repo instead) | None    |

### Git Filtering Options

When analyzing Git repositories (local or remote), you can use these options to filter the commits:

| Option             | Description                                    | Example               |
| ------------------ | ---------------------------------------------- | --------------------- |
| `--since DATE`     | Include commits after this date                | `--since 2023-01-01`  |
| `--until DATE`     | Include commits before this date               | `--until 2023-12-31`  |
| `--author PATTERN` | Filter by author name/email                    | `--author "John Doe"` |
| `--paths LIST`     | Limit to specific file paths (comma-separated) | `--paths lib/,test/`  |
| `--max-count NUM`  | Limit to NUM most recent commits               | `--max-count 1000`    |
| `--branch NAME`    | Analyze only the specified branch              | `--branch main`       |
| `--exclude-merges` | Exclude merge commits from analysis            | `--exclude-merges`    |

You can combine these options to precisely define your analysis scope:

```bash
# Analyze only changes from the last 3 months by a specific author
gitlock_holmes hotspots --repo ./my_project --since "3 months ago" --author "Jane Smith"

# Analyze only the main branch's lib directory from 2023
gitlock_holmes couplings --repo ./my_project --branch main --paths lib/ --since 2023-01-01 --until 2023-12-31
```

### Common Options

| Option                  | Description                             | Default                       |
| ----------------------- | --------------------------------------- | ----------------------------- |
| `--format`, `-f` FORMAT | Output format (`csv`, `json`, `stdout`) | `csv`                         |
| `--output`, `-o` FILE   | Write output to file                    | Timestamped file in `output/` |
| `--limit` NUMBER        | Limit number of results                 | 20                            |
| `--dir`, `-d` PATH      | Directory for complexity analysis       | Required for some analyses    |
| `--target-files` FILE   | Target file for blast radius analysis   | Required for blast-radius     |
| `--help`, `-h`          | Show help information                   |                               |
| `--version`, `-v`       | Show version information                |                               |

### Example Commands

Get an overall repository summary:

```bash
gitlock_holmes summary --repo /path/to/repo
```

Find the top 10 hotspots in JSON format:

```bash
gitlock_holmes hotspots --repo /path/to/repo --dir /path/to/code --format json --limit 10
```

Identify knowledge silos and save to a CSV file:

```bash
gitlock_holmes knowledge-silos --repo /path/to/repo --output silos.csv
```

Find temporal coupling with at least 50% coupling:

```bash
gitlock_holmes couplings --repo /path/to/repo --min-coupling 50
```

Analyze the impact of changing a specific file:

```bash
gitlock_holmes blast-radius --repo /path/to/repo --dir /path/to/code --target-files lib/important_file.ex
```

Output directly to the terminal:

```bash
gitlock_holmes summary --repo /path/to/repo --format stdout
```

Analyze only commits from a specific time period:

```bash
gitlock_holmes hotspots --repo /path/to/repo --dir /path/to/code --since 2023-01-01 --until 2023-06-30
```

### Legacy Command Style (Backward Compatibility)

GitlockHolmes also supports a legacy command style:

```bash
gitlock_holmes --investigation hotspots --log ./git_log.txt --vcs git
```

### Preparing Git Log

For faster analysis, you can prepare a Git log file:

```bash
# Using the provided script
./scripts/prepare_git_log.sh --repo /path/to/repo --output git_log.txt

# Additional filtering options
./scripts/prepare_git_log.sh --repo /path/to/repo --days 90 --author "Jane Smith" --path src/ --output filtered_log.txt

# Or manually
cd /path/to/repo
git log --all -M -C --numstat --date=short --pretty=format:'--%h--%cd--%cn' > git_log.txt
```

Then use this log file for analysis:

```bash
gitlock_holmes summary --repo git_log.txt
```

## Understanding Results

### Hotspots

Hotspots are files that are both complex and frequently changed:

```
entity,revisions,complexity,loc,risk_score,risk_factor
lib/risky_module.ex,25,30,350,8.5,high
lib/another_module.ex,18,15,200,5.2,medium
```

Key metrics:

- **revisions**: Number of times the file has been changed
- **complexity**: Cyclomatic complexity measure
- **loc**: Lines of code
- **risk_score**: Combined risk score (higher is riskier)
- **risk_factor**: Qualitative risk assessment (high, medium, low)

#### Interpretation Guidelines

| Risk Factor | Characteristics                      | Action                                             |
| ----------- | ------------------------------------ | -------------------------------------------------- |
| High        | High complexity + frequent changes   | Prioritize for refactoring, increase test coverage |
| Medium      | Moderate complexity/changes          | Review during regular maintenance                  |
| Low         | Low complexity or infrequent changes | Monitor for changes in patterns                    |

### Knowledge Silos

Knowledge silos identify files that are primarily modified by a single developer:

```
entity,main_author,ownership_ratio,num_authors,num_commits,risk_level
lib/auth/session.ex,Alice Smith,95.0,1,20,high
lib/user/profile.ex,Bob Jones,65.0,3,12,medium
```

Key metrics:

- **main_author**: Developer with the most changes
- **ownership_ratio**: Percentage of changes by the main author
- **num_authors**: Total unique authors who modified the file
- **num_commits**: Total number of commits to the file
- **risk_level**: Risk assessment based on ownership concentration

#### Interpretation Guidelines

| Risk Level | Characteristics                 | Action                                                 |
| ---------- | ------------------------------- | ------------------------------------------------------ |
| High       | >80% ownership with >10 commits | Schedule knowledge transfer sessions, pair programming |
| Medium     | >70% ownership with >5 commits  | Code reviews by different team members                 |
| Low        | More distributed ownership      | Continue normal practices                              |

### Temporal Coupling

Temporal coupling identifies files that tend to change together:

```
entity,coupled,degree,windows,trend
lib/auth/session.ex,lib/auth/token.ex,85.7,10,12.3
lib/user/profile.ex,lib/user/settings.ex,72.4,8,-5.2
```

Key metrics:

- **entity**: First file in the coupling relationship
- **coupled**: Second file that changes with the first
- **degree**: Percentage of co-changes (higher means stronger coupling)
- **windows**: Number of commits where both files changed
- **trend**: Change in coupling over time (positive means increasing coupling)

#### Interpretation Guidelines

| Degree | Windows | Interpretation       | Action                                     |
| ------ | ------- | -------------------- | ------------------------------------------ |
| >80%   | >10     | Very strong coupling | Consider merging or redesigning boundaries |
| 50-80% | >5      | Strong coupling      | Review for architectural violations        |
| <50%   | <5      | Weak coupling        | Normal for related components              |

### Coupled Hotspots

Coupled hotspots are pairs of files that are both risky and coupled:

```
entity,coupled,combined_risk_score,trend,individual_risks
lib/auth/session.ex,lib/auth/token.ex,56.25,3.2,{"lib/auth/session.ex":7.5,"lib/auth/token.ex":7.5}
```

Key metrics:

- **combined_risk_score**: Multiplication of individual risk scores
- **trend**: Change in coupling over time
- **individual_risks**: Risk scores for each file in the pair

#### Interpretation Guidelines

| Combined Risk | Trend      | Action                                          |
| ------------- | ---------- | ----------------------------------------------- |
| >50           | Increasing | Immediate attention, consider major refactoring |
| >25           | Any        | Prioritize in technical debt reduction plan     |
| <25           | Decreasing | Monitor but lower priority                      |

## Advanced Usage

### Programmatic API

GitlockHolmes can be used programmatically in Elixir projects:

```elixir
# Run a hotspots analysis
{:ok, results} = GitlockHolmesCore.investigate(:hotspots, "/path/to/repo", %{
  dir: "/path/to/code",
  format: "json"
})

# Parse and use the results
hotspots = Jason.decode!(results)
top_risk = Enum.max_by(hotspots, fn h -> h["risk_score"] end)
IO.puts("Highest risk file: #{top_risk["entity"]} (Score: #{top_risk["risk_score"]})")
```

See `examples/analyze_repository.exs` for a complete example.

### Integration with CI/CD

Add GitlockHolmes to your CI/CD pipeline to monitor code health:

```yaml
# Example GitHub Action workflow
name: Code Health

on: [push, pull_request]

jobs:
  analyze:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0 # Full history for accurate analysis

      - name: Set up Elixir
        uses: erlef/setup-beam@v1
        with:
          elixir-version: "1.14"
          otp-version: "25"

      - name: Install GitlockHolmes
        run: |
          git clone https://github.com/yourusername/gitlock_holmes.git
          cd gitlock_holmes
          mix deps.get
          mix build.all
          sudo cp bin/gitlock_holmes /usr/local/bin/

      - name: Analyze code health
        run: |
          gitlock_holmes hotspots --repo . --dir . --output hotspots.csv
          gitlock_holmes knowledge-silos --repo . --output silos.csv

      - name: Upload reports
        uses: actions/upload-artifact@v3
        with:
          name: code-health-reports
          path: "*.csv"
```

### Working with Remote Repositories

GitlockHolmes can analyze remote repositories directly:

```bash
# Clone and analyze a remote repository
gitlock_holmes hotspots --url https://github.com/user/repo.git --dir ./temp_dir

# Analyze a specific branch of a remote repository
gitlock_holmes hotspots --url https://github.com/user/repo.git --branch develop --dir ./temp_dir
```

### Analyzing Specific Time Periods

Use the prepare_git_log.sh script to focus on a specific time period:

```bash
# Generate a log for the last 90 days
./scripts/prepare_git_log.sh --repo ./my_project --days 90 --output recent_log.txt

# Or specify exact date ranges
./scripts/prepare_git_log.sh --repo ./my_project --since 2023-01-01 --until 2023-06-30 --output h1_2023_log.txt

# Analyze the filtered log
gitlock_holmes hotspots --repo recent_log.txt --dir ./my_project
```

## FAQ

**Q: How is cyclomatic complexity calculated?**  
A: GitlockHolmes uses language-specific analyzers to calculate cyclomatic complexity by counting decision points (if statements, loops, etc.). We support Elixir, JavaScript, Python, and more.

**Q: How many commits should I analyze?**  
A: For most repositories, analyzing 3-6 months of history provides a good balance between meaningful insights and performance. You can use the `--since` parameter or `prepare_git_log.sh` script to limit the history.

**Q: Are binary files included in the analysis?**  
A: GitlockHolmes identifies binary files and excludes them from complexity analysis, but still includes them in coupling and revision-based analyses.

**Q: How is the "risk score" calculated?**  
A: The risk score is a combination of complexity, change frequency, and size factors. The formula gives more weight to files that are both complex and frequently changed.

**Q: What thresholds should I use for my project?**  
A: Start with the defaults and adjust based on your project's characteristics. Smaller projects might benefit from lower thresholds, while larger projects might need higher ones.

**Q: How accurate are the "blast radius" predictions?**  
A: The accuracy depends on the quality of your commit history. Projects with clean, focused commits will yield more accurate predictions than those with large, mixed commits.

**Q: Can I analyze a specific branch or time period?**  
A: Yes, use the `--branch`, `--since` and `--until` parameters or the `prepare_git_log.sh` script to filter commits.

**Q: What's the difference between using `--repo` and `--log`?**  
A: The `--repo` option is more versatile and can handle local repositories, log files, or remote URLs. The `--log` option is maintained for backward compatibility but is deprecated.

**Q: Do I need to have Git installed to use GitlockHolmes?**  
A: Yes, GitlockHolmes requires Git to be installed when analyzing repositories directly. When analyzing pre-generated log files, Git is not required.

## Performance Considerations

GitlockHolmes analyzes Git history and performs complexity calculations, which can be resource-intensive for large repositories:

- **Memory usage**: Analyzing large repositories (10,000+ commits) can require 1-2GB of RAM
- **Execution time**: Full analysis might take 1-5 minutes for medium-sized repositories
- **File count**: Repositories with many files (10,000+) might need more memory

For very large repositories, consider:

- Analyzing a subset of the history (e.g., last 6 months)
- Focusing on a specific directory or component
- Running analyses separately instead of generating a full report

## Troubleshooting

### Common Issues

**Problem**: `Error: File not found: <path>`  
**Solution**: Verify the path is correct and the file exists.

**Problem**: Very slow analysis with large repositories  
**Solution**: Generate a focused Git log with `prepare_git_log.sh --days 90`

**Problem**: No results in coupling analysis  
**Solution**: Lower the thresholds with `--min-coupling 10 --min-windows 2`

**Problem**: "Git command failed" error  
**Solution**: Ensure Git is installed and the repository path is correct

**Problem**: "Invalid source" error  
**Solution**: Check that your input is a valid Git repository, log file, or URL

## Similar Tools

- **Code Maat**: Original command-line tool by Adam Tornhill
- **CodeClimate**: Quality analysis but less focus on historical patterns

## Why GitlockHolmes?

While other tools focus on static code analysis, GitlockHolmes looks at the evolution of your codebase over time, revealing patterns that aren't visible from looking at the code in isolation.

## Contributing

Contributions are welcome! Check out the [Contributing Guide](CONTRIBUTING.md) for details on how to get started.

### Development Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/gitlock_holmes.git
cd gitlock_holmes

# Install dependencies
mix deps.get

# Run tests
mix test

```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Adam Tornhill for the original concepts in "Your Code as a Crime Scene"
- The Elixir community for the excellent language and ecosystem
- All contributors who have helped improve this tool

---

<p align="center">
  Made with ❤️ by the GitlockHolmes team
</p>
