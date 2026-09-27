# Security Notes — Cloud Dev Box (code-server on Railway)

This service is a **full development environment behind a single password on a
public URL**. Read this once before you put anything sensitive in it.

## Threat model in one paragraph

Anyone who can guess or obtain your password gets a shell with sudo in your
container, your source code, your SSH keys and any tokens stored in the box.
The container is isolated from other Railway tenants and from Railway's
infrastructure — sudo inside it only affects *your* box — but the box's
contents are exactly as safe as your password and the secrets you place inside.

## Defaults this template enforces

- **Auth is always on.** The template generates a random 24-character
  `PASSWORD` via Railway's `${{ secret(24) }}` at deploy time. The entrypoint
  **refuses to start** if both `PASSWORD` and `HASHED_PASSWORD` are unset, or
  if an env var tries to set auth to `none`.
- **Telemetry off** (`--disable-telemetry`).
- **Pinned image tag** (`codercom/code-server:4.129.0`) — no surprise
  upstream changes on rebuild.
- **Privilege drop**: the container starts as root only long enough to chown
  the volume, then execs code-server as the non-root `coder` user (uid 1000)
  via `setpriv`.
- **TLS** is terminated by Railway on your `RAILWAY_PUBLIC_DOMAIN` — traffic
  is HTTPS end-user-to-edge with no extra setup.

## Never disable auth

code-server supports `--auth none`. **Do not use it here.** On Railway your
service has a public domain; auth-off means anyone on the internet gets an
interactive shell in your container within minutes of the URL being crawled.
The entrypoint blocks the env-var route (`CODE_SERVER_AUTH=none` /
`AUTH=none`) deliberately. If you must expose an unauthenticated preview of an
app you're building, expose *that app* as its own Railway service — never the
IDE.

## Changing / rotating your password

Plain password (simplest):

1. Railway → your service → **Variables** → edit `PASSWORD`.
2. Redeploy. Old sessions are invalidated on restart.

Hashed password (**preferred** once you're set up — the plaintext never sits in
your Railway variables):

1. In the dev box terminal: `echo -n "your-new-password" | npx argon2-cli -e`
2. Copy the `$argon2i$...` output. In Railway Variables, add it as
   `HASHED_PASSWORD` (paste raw — Railway does not do docker-compose-style
   `$$` escaping; if the value is mangled, use the Raw Editor).
3. Delete the `PASSWORD` variable, redeploy.

code-server reads both from the environment; `HASHED_PASSWORD` takes
precedence over `PASSWORD` when both are set.
Source: [cli.ts](https://github.com/coder/code-server/blob/main/src/node/cli.ts) ·
[FAQ — hashed passwords](https://github.com/coder/code-server/blob/main/docs/FAQ.md#can-i-store-my-password-hashed)

## About sudo inside the container

The `coder` user has passwordless sudo (inherited from the official upstream
image). This is intentional and honest: **it is your own isolated container** —
sudo lets you `apt-get install` toolchains, which is what makes a dev box
useful. It does not grant access to the host, other Railway services, or other
tenants. The blast radius of a compromised password already includes
everything valuable in the box (code, keys, tokens); removing sudo would
inconvenience you without meaningfully shrinking that blast radius.

## Practical hardening checklist

- [ ] Switch to `HASHED_PASSWORD` and delete `PASSWORD` (above).
- [ ] Use a password manager; never reuse this password.
- [ ] Set `CS_DISABLE_FILE_DOWNLOADS=true` if the box holds data that
      shouldn't be exfiltrated casually via the UI.
- [ ] Prefer fine-grained, short-lived tokens inside the box (GitHub
      fine-grained PATs scoped to specific repos, not classic PATs).
- [ ] Keep secrets in Railway **service variables**, not files in
      `/home/coder`, where practical.
- [ ] Rebuild periodically after bumping the pinned tag in `app/Dockerfile`
      to pick up code-server + Debian security fixes.
- [ ] Set `CODE_SERVER_IDLE_TIMEOUT_SECONDS` (e.g. `7200`) so an abandoned
      box stops serving.
- [ ] `/healthz` is intentionally unauthenticated (liveness only, leaks no
      data) — that is upstream behavior and required for Railway healthchecks.

## Reporting

Issues in code-server itself: https://github.com/coder/code-server/security.
Issues in this template's Dockerfile/entrypoint: open an issue on the template
repository.
