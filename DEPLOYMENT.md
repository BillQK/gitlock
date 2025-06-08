# Complete Fly.io Phoenix/Elixir Deployment Guide

## Table of Contents

1. [Initial Setup](#initial-setup)
2. [App Creation & Basic Deployment](#app-creation--basic-deployment)
3. [Dockerfile Configuration](#dockerfile-configuration)
4. [Database Setup](#database-setup)
5. [Environment Variables & Secrets](#environment-variables--secrets)
6. [Common Issues & Solutions](#common-issues--solutions)
7. [Automated Migrations](#automated-migrations)
8. [GitHub Actions Integration](#github-actions-integration)
9. [Essential Commands Reference](#essential-commands-reference)
10. [Troubleshooting Checklist](#troubleshooting-checklist)

---

## Initial Setup

### Authentication

```bash
# Login to Fly.io
fly auth login

# Check current user
fly auth whoami

# Generate API token (for CI/CD)
fly auth token
```

### Project Structure

Ensure your Phoenix app has this structure:

```
your-project/
├── fly.toml
├── Dockerfile
├── mix.exs
├── config/
├── lib/
└── priv/repo/migrations/
```

---

## App Creation & Basic Deployment

### Create Fly App

```bash
# Create new app
fly apps create gitlock

# List all apps
fly apps list

# Check app status
fly status -a gitlock
```

### Basic fly.toml Configuration

```toml
app = 'gitlock'
primary_region = 'bos'

[build]

[env]
  MIX_ENV = "prod"
  ECTO_IPV6 = "true"
  PORT = "4000"
  PHX_SERVER = "true"

[http_service]
  internal_port = 4000
  force_https = true
  auto_stop_machines = true
  auto_start_machines = true
  min_machines_running = 0

  [http_service.concurrency]
    type = "connections"
    hard_limit = 1000
    soft_limit = 500

[[http_service.checks]]
  grace_period = "10s"
  interval = "30s"
  method = "GET"
  timeout = "5s"
  path = "/health"

[machine]
  memory = '512mb'
  cpu_kind = 'shared'
  cpus = 1

# Automated migrations (add this)
[deploy]
  release_command = "/app/bin/gitlock_phx eval 'GitlockPhx.Release.migrate'"

```

---

## Dockerfile Configuration

### Complete Working Dockerfile

```dockerfile
FROM erlang:27 AS builder
ENV ELIXIR_VERSION="v1.18.4" \
    LANG=C.UTF-8

# Install build dependencies
RUN apt-get update -y && apt-get install -y \
    build-essential git curl unzip \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Install Node.js 20
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Build Elixir from source
RUN set -xe \
    && ELIXIR_DOWNLOAD_URL="https://github.com/elixir-lang/elixir/archive/${ELIXIR_VERSION}.tar.gz" \
    && ELIXIR_DOWNLOAD_SHA256="8e136c0a92160cdad8daa74560e0e9c6810486bd232fbce1709d40fcc426b5e0" \
    && curl -fSL -o elixir-src.tar.gz $ELIXIR_DOWNLOAD_URL \
    && echo "$ELIXIR_DOWNLOAD_SHA256  elixir-src.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/local/src/elixir \
    && tar -xzC /usr/local/src/elixir --strip-components=1 -f elixir-src.tar.gz \
    && rm elixir-src.tar.gz \
    && cd /usr/local/src/elixir \
    && make install clean

WORKDIR /app
RUN mix local.hex --force && mix local.rebar --force
ENV MIX_ENV="prod"

# Copy umbrella project
COPY mix.exs mix.lock ./
COPY config config
COPY apps apps

# Build project
RUN mix deps.get --only $MIX_ENV
RUN mix deps.compile
RUN mix compile

# Build Phoenix assets
WORKDIR /app/apps/gitlock_phx
RUN if [ -f "assets/package.json" ]; then \
      echo "Installing npm dependencies..." && \
      npm install --prefix assets; \
    else \
      echo "No package.json - using Phoenix built-in assets"; \
    fi

RUN mix assets.deploy
WORKDIR /app

# Create release
RUN mix release gitlock_phx

# Runtime stage
FROM erlang:27-slim
RUN apt-get update -y && apt-get install -y \
    libstdc++6 openssl libncurses5 locales curl build-essential \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Install Elixir runtime
ENV ELIXIR_VERSION="v1.18.4"
RUN set -xe \
    && ELIXIR_DOWNLOAD_URL="https://github.com/elixir-lang/elixir/archive/${ELIXIR_VERSION}.tar.gz" \
    && ELIXIR_DOWNLOAD_SHA256="8e136c0a92160cdad8daa74560e0e9c6810486bd232fbce1709d40fcc426b5e0" \
    && curl -fSL -o elixir-src.tar.gz $ELIXIR_DOWNLOAD_URL \
    && echo "$ELIXIR_DOWNLOAD_SHA256  elixir-src.tar.gz" | sha256sum -c - \
    && mkdir -p /usr/local/src/elixir \
    && tar -xzC /usr/local/src/elixir --strip-components=1 -f elixir-src.tar.gz \
    && rm elixir-src.tar.gz \
    && cd /usr/local/src/elixir \
    && make install clean \
    && apt-get purge -y curl build-essential \
    && apt-get autoremove -y

WORKDIR "/app"
RUN chown nobody /app
ENV MIX_ENV="prod"
COPY --from=builder --chown=nobody:root /app/_build/prod/rel/gitlock_phx ./

USER nobody
CMD ["/app/bin/gitlock_phx", "start"]
EXPOSE 4000
```

### Key Dockerfile Points

- Use multi-stage build (builder + runtime)
- Install Elixir from source for consistency
- Build assets in the builder stage
- Use correct release name in CMD: `gitlock_phx` (not `server`)
- Expose port 4000
- Run as `nobody` user for security

---

## Database Setup

### Create PostgreSQL Database

```bash
# Create PostgreSQL cluster
fly postgres create --name gitlock-db

# Check database status
fly status -a gitlock-db

# List database apps
fly apps list | grep db
```

### Attach Database to App

```bash
# Attach database to app
fly postgres attach --app gitlock gitlock-db

# If user already exists, specify different user
fly postgres attach --app gitlock gitlock-db --database-user gitlock_user

# Detach if needed
fly postgres detach --app gitlock gitlock-db
```

### Database Information Commands

```bash
# List databases
fly postgres db list -a gitlock-db

# List users
fly postgres users list -a gitlock-db

# Connect to database
fly postgres connect -a gitlock-db --database postgres

# Check database machines
fly machine list -a gitlock-db
```

---

## Environment Variables & Secrets

### Required Secrets

```bash
# Generate and set SECRET_KEY_BASE
fly secrets set SECRET_KEY_BASE="$(mix phx.gen.secret)" -a gitlock

# Set DATABASE_URL (format: postgresql://user:pass@host:port/database)
fly secrets set DATABASE_URL="postgresql://postgres:PASSWORD@gitlock-db.flycast:5432/postgres" -a gitlock

# Enable IPv6 for database connections (CRITICAL for Fly.io)
fly secrets set ECTO_IPV6=true -a gitlock

# Set Phoenix host
fly secrets set PHX_HOST=gitlock.fly.dev -a gitlock

# Optional: Other environment variables
fly secrets set IP="0.0.0.0" -a gitlock
fly secrets set PORT="4000" -a gitlock
fly secrets set PHX_SERVER="true" -a gitlock
```

### Managing Secrets

```bash
# List all secrets
fly secrets list -a gitlock

# Remove a secret
fly secrets unset SECRET_NAME -a gitlock

# Import from .env file
fly secrets import -a gitlock < .env
```

---

## Common Issues & Solutions

### Issue 1: "No such file or directory" - Binary Not Found

**Error**: `failed to spawn command: /app/bin/server: No such file or directory`

**Solution**: Use correct binary name in Dockerfile CMD

```dockerfile
# Wrong
CMD ["/app/bin/server"]

# Correct (match your release name)
CMD ["/app/bin/gitlock_phx", "start"]
```

### Issue 2: Binary Shows Usage Instead of Starting

**Error**: Binary runs but shows help/usage message

**Solution**: Add the `start` command

```dockerfile
# Add "start" command
CMD ["/app/bin/gitlock_phx", "start"]
```

### Issue 3: Missing SECRET_KEY_BASE

**Error**: `environment variable SECRET_KEY_BASE is missing`

**Solution**: Generate and set the secret

```bash
fly secrets set SECRET_KEY_BASE="$(mix phx.gen.secret)" -a gitlock
```

### Issue 4: Database Connection NXDOMAIN

**Error**: `tcp connect (gitlock-db.flycast:5432): non-existing domain - :nxdomain`

**Solution**: Enable IPv6 for Ecto

```bash
fly secrets set ECTO_IPV6=true -a gitlock
```

### Issue 5: Phoenix Socket Origin Check Failed

**Error**: `Could not check origin for Phoenix.Socket transport`

**Solution**: Set the correct host

```bash
fly secrets set PHX_HOST=gitlock.fly.dev -a gitlock
```

### Issue 6: App Not Listening on 0.0.0.0

**Error**: `is your app listening on 0.0.0.0:4000? make sure it is not only listening on 127.0.0.1`

**Solution**: Set IP binding

```bash
fly secrets set IP="0.0.0.0" -a gitlock
fly secrets set PHX_SERVER="true" -a gitlock
```

### Issue 7: Database URL Missing Database Name

**Error**: `invalid URL postgres://postgres:pass@host:5432, path should be a database name`

**Solution**: Add database name to URL

```bash
# Wrong
DATABASE_URL="postgres://postgres:pass@host:5432"

# Correct
DATABASE_URL="postgres://postgres:pass@host:5432/postgres"
```

### Issue 8: Relation "users" Does Not Exist

**Error**: `ERROR 42P01 (undefined_table) relation "users" does not exist`

**Solution**: Run database migrations

```bash
fly ssh console -a gitlock -C "/app/bin/gitlock_phx eval 'GitlockPhx.Release.migrate'"
```

---

## Automated Migrations

### Create Release Module

Create `lib/gitlock_phx/release.ex`:

```elixir
defmodule GitlockPhx.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :gitlock_phx

  def migrate do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(GitlockPhx.Repo, &Ecto.Migrator.run(&1, :up, all: true))
  end

  def rollback(version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(GitlockPhx.Repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp load_app do
    Application.load(@app)
  end
end
```

### Add Release Command to fly.toml

```toml
[deploy]
  release_command = "/app/bin/gitlock_phx eval 'GitlockPhx.Release.migrate'"
```

### Manual Migration Commands

```bash
# Run migrations manually
fly ssh console -a gitlock -C "/app/bin/gitlock_phx eval 'GitlockPhx.Release.migrate'"

# Alternative direct Ecto command
fly ssh console -a gitlock -C "/app/bin/gitlock_phx eval 'Ecto.Migrator.with_repo(GitlockPhx.Repo, fn repo -> Ecto.Migrator.run(repo, :up, all: true) end)'"

# Check if migrations exist
fly ssh console -a gitlock -C "ls -la /app/priv/repo/migrations/"
```

---

## GitHub Actions Integration

### Generate Fly API Token

```bash
fly auth token
```

### Add Secret to GitHub

1. Go to Repository Settings → Secrets and variables → Actions
2. Add new secret: `FLY_API_TOKEN`
3. Paste the token value

### GitHub Action Workflow

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Fly.io
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: superfly/flyctl-actions/setup-flyctl@master

      - run: flyctl deploy --remote-only
        env:
          FLY_API_TOKEN: ${{ secrets.FLY_API_TOKEN }}
```

---

## Essential Commands Reference

### Deployment

```bash
# Deploy app
fly deploy --remote-only -a gitlock

# Build and deploy locally
fly deploy -a gitlock

# Deploy specific app
fly deploy --app gitlock
```

### Monitoring & Debugging

```bash
# View logs
fly logs -a gitlock

# Follow logs in real-time
fly logs -a gitlock --follow

# SSH into app
fly ssh console -a gitlock

# Run command via SSH
fly ssh console -a gitlock -C "your-command"

# Check app status
fly status -a gitlock

# List machines
fly machine list -a gitlock
```

### Secrets Management

```bash
# List secrets
fly secrets list -a gitlock

# Set secret
fly secrets set KEY=value -a gitlock

# Remove secret
fly secrets unset KEY -a gitlock

# Import from file
fly secrets import -a gitlock < secrets.env
```

### Machine Management

```bash
# List machines
fly machine list -a gitlock

# Start/stop machines
fly machine start MACHINE_ID -a gitlock
fly machine stop MACHINE_ID -a gitlock

# Scale machines
fly scale count 2 -a gitlock
```

### Networking

```bash
# List IP addresses
fly ips list -a gitlock

# Allocate IPv4/IPv6
fly ips allocate-v4 -a gitlock
fly ips allocate-v6 -a gitlock

# DNS checks
fly ssh console -a gitlock -C "nslookup gitlock-db.flycast"
```

---

## Troubleshooting Checklist

### Pre-Deployment Checklist

- [ ] `fly.toml` has correct app name
- [ ] Dockerfile uses correct binary name in CMD
- [ ] Phoenix app has health check endpoint
- [ ] Migration files exist in `priv/repo/migrations/`
- [ ] Release module created for migrations

### Post-Deployment Checklist

- [ ] `SECRET_KEY_BASE` secret is set
- [ ] `DATABASE_URL` secret is set with correct format
- [ ] `ECTO_IPV6=true` is set
- [ ] `PHX_HOST` matches your domain
- [ ] Database is created and accessible
- [ ] Migrations have been run
- [ ] App is listening on `0.0.0.0:4000`

### Debug Commands

```bash
# Check all secrets
fly secrets list -a gitlock

# Verify database connection
fly ssh console -a gitlock -C "nslookup gitlock-db.flycast"

# Check app environment
fly ssh console -a gitlock -C "printenv | grep -E '(DATABASE|SECRET|PHX)'"

# Test database connectivity
fly postgres connect -a gitlock-db --database postgres

# Check startup logs
fly logs -a gitlock | grep -E "(Starting|Running|ERROR|WARN)"
```

### Common Error Patterns

1. **Binary not found** → Check CMD in Dockerfile
2. **Secret missing** → Check `fly secrets list`
3. **Database connection** → Check `ECTO_IPV6` and `DATABASE_URL`
4. **Socket origin** → Check `PHX_HOST`
5. **Binding issues** → Check `IP` and `PHX_SERVER` env vars
6. **Migrations** → Run migrations manually or add release command

---

## Best Practices

1. **Always use `--remote-only`** for consistent builds
2. **Set `ECTO_IPV6=true`** for database connections
3. **Use release commands** for automated migrations
4. **Monitor logs** during and after deployment
5. **Test with health checks** to ensure app readiness
6. **Use secrets** for sensitive data, env vars for non-sensitive
7. **Keep Dockerfile** lean with multi-stage builds
8. **Version your releases** for easy rollbacks

---

_This guide covers the complete Phoenix app deployment process on Fly.io, including all commands that were tested and confirmed working._
