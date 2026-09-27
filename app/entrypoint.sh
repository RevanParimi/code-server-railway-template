#!/bin/sh
# Cloud Dev Box entrypoint for Railway.
#
# What this script does, in order:
#   1. Refuses to start with authentication disabled (defense in depth — this
#      service sits on a public domain).
#   2. Fixes ownership of /home/coder. Railway mounts volumes owned by root;
#      code-server runs as the non-root user `coder` (uid 1000) and must be
#      able to write its config, extensions and your code there.
#   3. Seeds a workspace folder on first boot.
#   4. Drops privileges from root to `coder` and execs code-server under
#      dumb-init (correct PID 1 signal handling / zombie reaping).
#
# POSIX sh — the base image's /bin/sh is dash.
set -eu

HOME_DIR=/home/coder
DEVBOX_UID=1000
DEVBOX_GID=1000
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME_DIR/project}"
PORT="${PORT:-8080}"

# --- 1. Never allow auth to be turned off on a public domain. ----------------
# code-server only disables auth when explicitly passed `--auth none`. We never
# pass it, and we also refuse the env-var route so a stray variable can't
# silently expose the box.
if [ "${CODE_SERVER_AUTH:-password}" = "none" ] || [ "${AUTH:-password}" = "none" ]; then
  echo "FATAL: refusing to start with authentication disabled." >&2
  echo "This container is reachable from the public internet on Railway." >&2
  echo "Unset CODE_SERVER_AUTH/AUTH or set them to 'password'." >&2
  exit 1
fi

if [ -z "${PASSWORD:-}" ] && [ -z "${HASHED_PASSWORD:-}" ]; then
  echo "FATAL: neither PASSWORD nor HASHED_PASSWORD is set." >&2
  echo "Set PASSWORD (Railway template generates one via \${{ secret(24) }})" >&2
  echo "or HASHED_PASSWORD (argon2 hash — see SECURITY.md)." >&2
  exit 1
fi

# --- 2. Fix volume ownership. -------------------------------------------------
# Railway mounts the volume at /home/coder owned by root. Fix the mountpoint
# itself every boot (cheap, non-recursive). Do ONE recursive pass on first
# boot only — recursive chown over a large, already-correct volume would slow
# every restart for no benefit. Files created afterwards are owned by coder
# anyway because code-server runs as coder.
if [ "$(id -u)" = "0" ]; then
  chown "$DEVBOX_UID:$DEVBOX_GID" "$HOME_DIR"

  if [ ! -f "$HOME_DIR/.devbox-initialized" ]; then
    echo "devbox: first boot — initializing volume at $HOME_DIR"
    chown -R "$DEVBOX_UID:$DEVBOX_GID" "$HOME_DIR"
    date -u +"%Y-%m-%dT%H:%M:%SZ" > "$HOME_DIR/.devbox-initialized"
    chown "$DEVBOX_UID:$DEVBOX_GID" "$HOME_DIR/.devbox-initialized"
  fi
fi

# --- 3. Seed the workspace folder. -------------------------------------------
# code-server opens this folder by default (last positional argument below).
mkdir -p "$WORKSPACE_DIR"
[ "$(id -u)" = "0" ] && chown "$DEVBOX_UID:$DEVBOX_GID" "$WORKSPACE_DIR"

# Optional user hook dir on the persistent volume: any executable file in
# ~/entrypoint.d runs (as root, before privilege drop) on every boot. Use it
# to apt-get install extra packages that must survive redeploys being re-run.
if [ -d "$HOME_DIR/entrypoint.d" ]; then
  find "$HOME_DIR/entrypoint.d" -type f -perm -u+x -print -exec {} \;
fi

# --- 4. Drop privileges and exec code-server. ---------------------------------
# --bind-addr 0.0.0.0:$PORT  -> Railway routes external traffic to this port
#                               (set the domain's target port to match; 8080
#                               unless you override PORT).
# --disable-telemetry        -> no usage metrics leave your box.
# Auth comes from $PASSWORD / $HASHED_PASSWORD which code-server reads itself;
# HASHED_PASSWORD takes precedence when both are set.
# setpriv ships with util-linux in the base image — no extra su-exec/gosu dep.
if [ "$(id -u)" = "0" ]; then
  exec setpriv --reuid="$DEVBOX_UID" --regid="$DEVBOX_GID" --init-groups \
    env HOME="$HOME_DIR" USER=coder \
    dumb-init /usr/bin/code-server \
      --bind-addr "0.0.0.0:$PORT" \
      --disable-telemetry \
      "$WORKSPACE_DIR"
else
  # Already non-root (e.g. someone set a start command with a user override).
  exec dumb-init /usr/bin/code-server \
    --bind-addr "0.0.0.0:$PORT" \
    --disable-telemetry \
    "$WORKSPACE_DIR"
fi
