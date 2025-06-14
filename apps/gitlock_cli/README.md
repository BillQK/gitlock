# Gitlock CLI

> Forensic code analysis tool for Git repositories

Gitlock analyzes Git repositories using forensic code analysis techniques inspired by Adam Tornhill's "Your Code as Crime Scene" methodology. It helps you identify hotspots, knowledge silos, temporal coupling, and other code health indicators to prioritize refactoring efforts and improve code quality.

## Features

- 🔍 **Hotspot Analysis** - Find frequently changed files with high complexity
- 🧠 **Knowledge Silo Detection** - Identify files owned primarily by one developer
- 🔗 **Temporal Coupling Analysis** - Discover files that tend to change together
- ⚡ **Coupled Hotspots** - Detect pairs of risky files that are also coupled
- 💥 **Blast Radius Analysis** - Assess the potential impact of changing specific files
- 📊 **Summary Statistics** - Get high-level repository health metrics
- 👥 **Team Communication** - Map team communication patterns
- 🏥 **Code Health Assessment** - Overall codebase health evaluation

## Installation

### Via Homebrew (Recommended)

```bash
# Add the tap
brew tap BillQK/gitlock

# Install gitlock
brew install gitlock
```

### Via GitHub Releases

```bash
# Download the latest binary
curl -L https://github.com/BillQK/gitlock/releases/latest/download/gitlock -o gitlock
chmod +x gitlock
sudo mv gitlock /usr/local/bin/
```

### From Source

```bash
# Clone the repository
git clone https://github.com/BillQK/gitlock.git
cd gitlock

# Install dependencies and build
mix deps.get
mix escript.build

# Copy to your PATH
cp bin/gitlock /usr/local/bin/
```

## Quick Start

```bash
# Analyze hotspots in current directory
gitlock hotspots --repo . --dir .

# Find knowledge silos
gitlock knowledge-silos --repo .

# Discover temporal coupling
gitlock couplings --repo .

# Get help
gitlock --help
```

## Usage

### Basic Syntax

```bash
gitlock [investigation] [options]
```

### Available Investigations

| Investigation        | Description                            | Key Metrics                              |
| -------------------- | -------------------------------------- | ---------------------------------------- |
| `hotspots`           | Find frequently changed complex files  | revisions, complexity, risk_score        |
| `knowledge-silos`    | Files owned primarily by one developer | main_author, ownership_ratio, risk_level |
| `couplings`          | Files that tend to change together     | coupled files, degree, windows           |
| `coupled-hotspots`   | Risky files that are also coupled      | combined risk analysis                   |
| `blast-radius`       | Impact assessment of changing files    | affected files, impact score             |
| `summary`            | General repository statistics          | commits, authors, entities               |
| `team-communication` | Team collaboration patterns            | communication metrics                    |
| `code-health`        | Overall codebase health assessment     | health indicators                        |

### Common Options

#### Repository Source

```bash
--repo, -r PATH     # Path to repository or log file (recommended)
--url,  -u URL      # URL to remote Git repository
--log,  -l PATH     # Path to log file (deprecated)
```

#### Output Control

```bash
--format, -f FORMAT  # Output format: csv, json, stdout (default: csv)
--output, -o FILE    # Write output to file (default: timestamped file)
--limit NUMBER       # Limit number of results (default: 20)
```

#### Analysis Options

```bash
--dir, -d PATH       # Directory for complexity analysis (required for hotspots)
--time-period PERIOD # Time period for temporal analysis
--min-coupling NUM   # Minimum coupling threshold
--min-windows NUM    # Minimum coupling windows
```

### Examples

#### Hotspot Analysis

```bash
# Basic hotspots analysis
gitlock hotspots --repo ./my_project --dir ./my_project

# Hotspots with custom output
gitlock hotspots --repo . --dir . --format json --output hotspots.json --limit 50

# Analyze specific directory
gitlock hotspots --repo . --dir ./src --format csv
```

#### Knowledge Silo Detection

```bash
# Find knowledge silos
gitlock knowledge-silos --repo .

# Export to CSV file
gitlock knowledge-silos --repo ./git_log.txt --output knowledge_silos.csv

# Limit results
gitlock knowledge-silos --repo . --limit 10
```

#### Temporal Coupling Analysis

```bash
# Basic coupling analysis
gitlock couplings --repo .

# With custom thresholds
gitlock couplings --repo . --min-coupling 50 --min-windows 5

# JSON output
gitlock couplings --repo . --format json --output couplings.json
```

#### Blast Radius Analysis

```bash
# Analyze impact of changing specific files
gitlock blast-radius --repo . --dir . --target-files lib/core.ex,src/main.ex

# With custom threshold
gitlock blast-radius --repo . --dir . --target-files lib/core.ex --blast-threshold 0.5

# Multiple target files
gitlock blast-radius --repo . --dir . \
  --target-files lib/core.ex \
  --target-files src/api.ex \
  --max-radius 3
```

#### Summary Statistics

```bash
# Basic repository summary
gitlock summary --repo .

# Summary with custom output
gitlock summary --repo . --format json --output summary.json
```

### Advanced Usage

#### Using Remote Repositories

```bash
# Analyze remote repository
gitlock hotspots --url https://github.com/user/repo.git --dir ./cloned_repo
```

#### Using Git Log Files

```bash
# Generate git log
git log --all --numstat --date=short --pretty=format:'--%h--%ad--%aN' --no-renames > git_log.txt

# Analyze from log file
gitlock hotspots --repo git_log.txt --dir ./source_code
gitlock knowledge-silos --repo git_log.txt
```

#### Legacy Style (Backward Compatibility)

```bash
# Old style syntax still supported
gitlock --investigation hotspots --log ./git_log.txt --vcs git
gitlock -i knowledge-silos -l git_log.txt
```

## Output Formats

### CSV (Default)

Clean, structured data perfect for spreadsheets and further analysis.

### JSON

Structured data for programmatic processing:

```bash
gitlock hotspots --repo . --dir . --format json
```

### Stdout

Human-readable output for terminal viewing:

```bash
gitlock summary --repo . --format stdout
```

## Understanding the Results

### Hotspots Output

```csv
entity,revisions,complexity,loc,risk_score,risk_factor
src/core.ex,45,28,650,89.2,high
lib/api.ex,32,15,420,65.8,high
```

- **entity**: File path
- **revisions**: Number of times changed
- **complexity**: Cyclomatic complexity
- **risk_score**: Combined risk metric (0-100)
- **risk_factor**: Risk level (low/medium/high)

### Knowledge Silos Output

```csv
entity,main_author,ownership_ratio,num_authors,num_commits,risk_level
src/core.ex,john.doe,96.4,2,45,high
```

- **ownership_ratio**: Percentage of commits by main author
- **risk_level**: Knowledge concentration risk

### Coupling Output

```csv
entity,coupled,degree,windows,trend
src/main.ex,lib/core.ex,92,15,positive
```

- **degree**: Coupling strength (0-100)
- **windows**: Number of time periods both files changed

## Requirements

- Git repository with commit history
- Elixir/Erlang runtime (for source installation)
- For hotspot analysis: Access to source code directory

## Tips & Best Practices

1. **Start with Summary**: Get an overview before diving into specific analyses

   ```bash
   gitlock summary --repo .
   ```

2. **Focus on High-Risk Items**: Use the risk scores to prioritize attention

   ```bash
   gitlock hotspots --repo . --dir . --limit 10
   ```

3. **Combine Analyses**: Use multiple investigation types for comprehensive insights

   ```bash
   gitlock hotspots --repo . --dir . --output hotspots.csv
   gitlock knowledge-silos --repo . --output silos.csv
   ```

4. **Regular Monitoring**: Run analyses periodically to track code health trends

5. **Team Discussions**: Use results to guide architecture and refactoring decisions

## Troubleshooting

### Common Issues

**Error: Directory option (--dir) is required**

- Hotspot analysis needs access to source code for complexity calculation
- Solution: Add `--dir /path/to/source/code`

**Error: Repository directory does not exist**

- Check the path provided to `--repo`
- Ensure it's a valid Git repository or log file

**No results returned**

- Check if repository has sufficient commit history
- Try lowering thresholds (e.g., `--min-coupling 10`)

### Getting Help

```bash
# General help
gitlock --help

# Investigation-specific help
gitlock --help hotspots
gitlock --help knowledge-silos

# Version information
gitlock --version
```

## Contributing

Contributions are welcome! Please read our [Contributing Guide](../../CONTRIBUTING.md) for details on how to get started.

### Development

```bash
# Setup development environment
git clone https://github.com/yourusername/gitlock.git
cd gitlock
mix deps.get

# Run tests
mix test

# Build CLI
mix escript.build
```

## License

This project is licensed under the MIT License - see the [LICENSE](../../LICENSE) file for details.

## Acknowledgments

- Inspired by Adam Tornhill's "Your Code as a Crime Scene"
- Built with the Elixir programming language
- Part of the Gitlock forensic code analysis suite

---

> **"Your code is a crime scene. Let Gitlock be your forensic detective."**

For more information, visit the [project homepage](https://github.com/BillQK/gitlock) or check out the [web interface](https://gitlock.fly.app).
