# syntax=docker/dockerfile:1
#
# Cloud Dev Box for Railway — VS Code in the browser (code-server) with a real
# dev toolchain preinstalled.
#
# Base image: codercom/code-server:4.129.0 (official upstream image)
#   - Pinned to an exact release tag (pushed 2026-07-17, VS Code 1.104.x era).
#     Verify/refresh at: https://hub.docker.com/r/codercom/code-server/tags
#   - Debian 13 ("trixie") base with a non-root user `coder` (uid/gid 1000)
#     that already has passwordless sudo, plus git, git-lfs, curl, wget,
#     openssh-client, nano, vim-tiny, zsh, htop, dumb-init and fixuid baked in.
#     See: https://github.com/coder/code-server/blob/main/ci/release-image/Dockerfile
#   - Auth via $PASSWORD / $HASHED_PASSWORD env vars (HASHED_PASSWORD wins):
#     https://github.com/coder/code-server/blob/main/src/node/cli.ts
#   - Unauthenticated liveness endpoint at /healthz:
#     https://github.com/coder/code-server/blob/main/docs/FAQ.md#what-is-the-healthz-endpoint
FROM codercom/code-server:4.129.0

# The base image ends with `USER 1000`. We need root for apt and for the
# volume-ownership fix at container start; our entrypoint drops back to
# uid 1000 (coder) before launching code-server.
USER root

# Layer 1: compilers + interpreters + everyday CLI tools.
#   build-essential      -> gcc/g++/make (needed by node-gyp, pip source builds, Rust crates, etc.)
#   pkg-config           -> lets builds locate system libraries
#   python3/pip/venv     -> Python toolchain; Debian 13 is PEP 668 "externally managed",
#                           so per-project `python3 -m venv` is the intended workflow
#   pipx                 -> install Python CLI apps (poetry, httpie, ...) in isolated venvs
#   unzip/zip            -> archive tools (also required by many SDK installers, e.g. bun, sdkman)
#   jq                   -> JSON wrangling in the terminal
#   less/rsync/procps    -> quality-of-life basics some slim bases miss
#   ca-certificates      -> refreshed CA bundle for TLS
# (git, curl, wget, openssh-client are already in the base image — not repeated.)
# --no-install-recommends + rm of apt lists keeps the layer lean.
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    build-essential \
    pkg-config \
    python3 \
    python3-pip \
    python3-venv \
    pipx \
    unzip \
    zip \
    jq \
    less \
    rsync \
    procps \
    ca-certificates \
  && rm -rf /var/lib/apt/lists/*

# Layer 2: Node.js LTS + corepack.
# Debian 13's own `nodejs` package is 20.19.x, and Node 20 reached end-of-life
# in April 2026 — not something to bake into a fresh dev box. NodeSource's
# node_22.x repo ships Node 22 "Jod" (LTS, maintained until April 2027) with
# npm included. Corepack is enabled so `yarn` and `pnpm` shims work out of the
# box (each project's packageManager field pins its own version).
# Repo setup script: https://github.com/nodesource/distributions
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
  && apt-get install -y --no-install-recommends nodejs \
  && corepack enable \
  && rm -rf /var/lib/apt/lists/*

# Layer 3: our entrypoint. It (a) fixes ownership of the Railway volume that
# gets mounted over /home/coder (Railway mounts volumes as root), (b) seeds
# the workspace folder on first boot, then (c) drops privileges to `coder`
# and execs code-server under dumb-init (proper PID 1 signal handling).
COPY entrypoint.sh /usr/local/bin/devbox-entrypoint.sh
RUN chmod 0755 /usr/local/bin/devbox-entrypoint.sh

# code-server listens on 8080 by default; the entrypoint honors Railway's
# $PORT if one is injected. Set your Railway domain's target port to 8080.
EXPOSE 8080

# NOTE: container starts as root (see USER root above) so the entrypoint can
# chown the freshly-mounted volume; it immediately drops to uid 1000.
ENTRYPOINT ["/usr/local/bin/devbox-entrypoint.sh"]
