FROM erlang:27 AS builder

ENV ELIXIR_VERSION="v1.18.4" \
    LANG=C.UTF-8

# Install build dependencies
RUN apt-get update -y && apt-get install -y \
    build-essential git curl unzip \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Install Node.js 20 (for esbuild/tailwind if needed)
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

# Build Phoenix assets (without npm if no package.json)
WORKDIR /app/apps/gitlock_phx

# Only run npm if package.json exists
RUN if [ -f "assets/package.json" ]; then \
      echo "Installing npm dependencies..." && \
      npm install --prefix assets; \
    else \
      echo "No package.json - using Phoenix built-in assets"; \
    fi

# Use Phoenix mix task to build assets (handles esbuild/tailwind)
RUN mix assets.deploy

WORKDIR /app

# Create release
COPY rel rel
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

CMD ["/app/bin/server"]

EXPOSE 4000
