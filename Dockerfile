# ── Build stage ──────────────────────────────────────────────────────────────
FROM elixir:1.18 AS build

# Install system build tools and Node.js
RUN apt-get update -y && \
    apt-get install -y build-essential git curl && \
    curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

# ── Dependency layer (cached unless mix.exs / mix.lock changes) ───────────────
COPY mix.exs mix.lock ./
COPY apps/wiki/mix.exs         apps/wiki/
COPY apps/deliberation/mix.exs apps/deliberation/
COPY apps/safety/mix.exs       apps/safety/
COPY apps/activitypub/mix.exs  apps/activitypub/
COPY apps/computation/mix.exs  apps/computation/
COPY apps/ai/mix.exs           apps/ai/
COPY config config/

RUN mix deps.get --only prod
RUN mix deps.compile

# ── npm layer (cached unless package.json / package-lock.json changes) ────────
COPY apps/wiki/assets/package.json \
     apps/wiki/assets/package-lock.json \
     apps/wiki/assets/

RUN cd apps/wiki/assets && npm ci

# Download esbuild and tailwind binaries (they are MIX_ENV-agnostic downloads)
RUN mix esbuild.install --if-missing
RUN mix tailwind.install --if-missing

# ── Application source & release overlays ────────────────────────────────────
COPY apps apps/
COPY rel rel/

# Build minified assets and generate cache manifest
RUN mix cmd --cd apps/wiki mix assets.deploy

# Compile all umbrella apps and assemble the release
RUN mix compile
RUN mix release && chmod +x _build/prod/rel/cms/bin/server \
                              _build/prod/rel/cms/bin/migrate

# ── Runtime stage ─────────────────────────────────────────────────────────────
FROM debian:bookworm-slim AS app

# Erlang runtime deps + locale support
RUN apt-get update -y && \
    apt-get install -y libssl3 libncurses6 locales ca-certificates && \
    apt-get clean && rm -rf /var/lib/apt/lists/* && \
    sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG=en_US.UTF-8
ENV LANGUAGE=en_US:en
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
RUN chown nobody:nogroup /app

# Copy the self-contained OTP release (includes ERTS — no Erlang needed in runtime image)
COPY --from=build --chown=nobody:nogroup /app/_build/prod/rel/cms ./

USER nobody

EXPOSE 4000

# `server` runs migrations then starts the Phoenix endpoint
CMD ["/app/bin/server"]
