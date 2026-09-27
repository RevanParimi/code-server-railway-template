# Deploy and Host VS Code (code-server) on Railway — Your Cloud Dev Box

Deploy **VS Code in your browser** on [Railway](https://railway.com) in about two minutes: [code-server](https://github.com/coder/code-server) with **password auth on by default**, a **persistent volume** for your code, settings and extensions, and a **real dev toolchain preinstalled** — git, Node.js 22 LTS, Python 3, build-essential and sudo — so the box is useful the moment it boots.

Code from an iPad, a Chromebook, a locked-down work laptop, or any machine with a browser. Your environment lives in the cloud and survives redeploys, restarts and image upgrades.

## Why this template (vs. other code-server templates)

Most existing code-server templates deploy the bare upstream image: no compilers, no Node, no Python, and a volume that isn't writable by the non-root code-server user. This template ships a thin custom Dockerfile that turns code-server into an actual dev box:

| | Bare code-server image | This template |
|---|---|---|
| Password auth | Optional / manual | **Always on**, auto-generated `${{ secret(24) }}` |
| Persistent home (`/home/coder`) | Volume mounts root-owned → breaks | **Entrypoint fixes ownership, then drops privileges** |
| git, curl, ssh | Yes | Yes |
| Node.js LTS + npm + corepack (yarn/pnpm) | No | **Node 22 LTS** |
| Python 3 + pip + venv + pipx | No | **Yes** |
| build-essential (gcc/make for node-gyp, native deps) | No | **Yes** |
| Telemetry | On | **Off** (`--disable-telemetry`) |
| Image tag | Often `latest` | **Pinned `4.129.0`** |

## Quickstart

1. Click **Deploy on Railway** for this template.
2. Railway generates a random 24-character `PASSWORD` for you (via `${{ secret(24) }}`). You can view it later under **service → Variables**.
3. Wait for the build (~2–4 min first time), then open the service's public URL.
4. Log in with the generated password. You're in VS Code. Open a terminal (`` Ctrl+` ``) — `git`, `node`, `npm`, `python3`, `pip`, `gcc`, `sudo` all work.
5. Your code goes in `/home/coder/project` (opened by default). Everything under `/home/coder` persists.

## What's preinstalled

From the official base image (`codercom/code-server:4.129.0`, Debian 13):

- `git` + `git-lfs`, `curl`, `wget`, `openssh-client`, `nano`, `vim-tiny`, `zsh`, `htop`
- Non-root user `coder` (uid 1000) with **passwordless sudo**

Added by this template's Dockerfile:

- **Node.js 22 LTS** (NodeSource) + `npm`, with **corepack enabled** — `yarn` and `pnpm` shims work immediately
- **Python 3** + `pip`, `venv`, `pipx` (Debian 13 is PEP 668 "externally managed": use `python3 -m venv .venv` per project, or `pipx install <tool>` for CLI apps)
- **build-essential** (`gcc`, `g++`, `make`) + `pkg-config` — required by `node-gyp`, source-built pip wheels, etc.
- `unzip`, `zip`, `jq`, `less`, `rsync`, `procps`

Need more? You have sudo: `sudo apt-get update && sudo apt-get install -y <pkg>`. Note apt-installed packages live **outside** the volume and disappear on redeploy — see FAQ below for how to make them stick.

## How persistence works

A Railway **volume is mounted at `/home/coder`** — the coder user's entire home directory. That single mount captures:

| Path | What it holds |
|---|---|
| `/home/coder/project` | Your code (default workspace) |
| `/home/coder/.local/share/code-server` | Installed **extensions**, user data |
| `/home/coder/.config/code-server` | code-server config |
| `/home/coder/.ssh`, `.gitconfig`, `.bashrc`, dotfiles | Your identity & shell setup |

Anything **outside** `/home/coder` (e.g. `sudo apt-get install`, files in `/tmp`) is part of the ephemeral container filesystem and resets on every deploy/restart.

Railway mounts volumes owned by root; the bundled entrypoint chowns the mount to uid 1000 (recursively on first boot only), then drops privileges before starting code-server.

> Volumes on Railway attach to a single service and grow with your plan limits. Back up anything irreplaceable with `git push` — a volume is persistence, not a backup strategy.

## Connecting your other tools

- **Settings Sync**: sign in with the built-in Settings Sync in code-server (Manage → Turn on Settings Sync) to share settings/keybindings/extensions with desktop VS Code. Extension availability comes from [Open VSX](https://open-vsx.org) rather than the Microsoft marketplace, so a few proprietary extensions (e.g. some Microsoft-published ones) aren't available.
- **vscode.dev / desktop VS Code Remote**: code-server is its own web UI — you don't need vscode.dev. If you prefer the Microsoft-marketplace ecosystem end to end, consider `openvscode-server` or VS Code tunnels instead; for a self-hosted browser IDE with password auth, code-server is the mature option.
- **git over SSH**: generate a key inside the box (`ssh-keygen -t ed25519`), add `~/.ssh/id_ed25519.pub` to GitHub/GitLab. The key persists on the volume.
- **Ports / previews**: run your dev server inside the box (e.g. `npm run dev` on port 3000) and use code-server's built-in port proxy at `https://<your-domain>/proxy/3000/` (auth-protected).

## Environment variables

| Variable | Default (template) | Purpose |
|---|---|---|
| `PASSWORD` | `${{ secret(24) }}` (auto-generated) | Login password for the web UI. Read by code-server itself ([source](https://github.com/coder/code-server/blob/main/src/node/cli.ts)). |
| `HASHED_PASSWORD` | *(unset)* | argon2 hash alternative — **takes precedence over `PASSWORD`** when set. Preferred once you're set up; see [SECURITY.md](SECURITY.md). |
| `WORKSPACE_DIR` | `/home/coder/project` | Folder code-server opens by default. |
| `PORT` | `8080` | Bind port. Leave as-is; the Railway domain's target port must match. |
| `CS_DISABLE_FILE_DOWNLOADS` | *(unset)* | Set `true` to block downloading files through the UI. |
| `CODE_SERVER_IDLE_TIMEOUT_SECONDS` | *(unset)* | Auto-shutdown code-server after N seconds idle (>60). |

**Changing your password:** service → Variables → edit `PASSWORD` → redeploy. Or switch to `HASHED_PASSWORD`: run `echo -n "newpassword" | npx argon2-cli -e` in the box's terminal, set the hash as `HASHED_PASSWORD`, delete `PASSWORD`, redeploy. ([upstream docs](https://github.com/coder/code-server/blob/main/docs/FAQ.md#can-i-store-my-password-hashed))

## FAQ

**How much does this cost / what resources does it need?**
code-server idles around 200–400 MB RAM; comfortable interactive use with a language server and a dev server running is ~1–2 GB RAM and 1–2 vCPU. Compiling large native projects wants more. On Railway's usage-based pricing an always-on 1 GB box is on the order of $10–15/month plus volume storage; you can cut that dramatically with **App Sleeping** (Serverless) so the box scales to zero when you're not connected, or by setting `CODE_SERVER_IDLE_TIMEOUT_SECONDS`. Check current prices at railway.com/pricing.

**Is my code safe on a public URL?**
The UI is password-gated with a generated 24-char secret, served over Railway's TLS. **Never disable auth** — see [SECURITY.md](SECURITY.md).

**Can I run Docker inside the box?**
No — Railway containers don't provide the privileges dockerd needs. Use Railway itself to run databases etc. as sibling services and reach them over the private network.

**How do I make `apt-get install` survive redeploys?**
Two options: (1) bake the package into `app/Dockerfile` (best), or (2) drop an executable script into `/home/coder/entrypoint.d/` — the entrypoint runs every executable there (as root) on each boot, so `apt-get install -y <pkg>` re-applies automatically.

**How do I upgrade code-server?**
Bump the pinned tag in `app/Dockerfile` (check [Docker Hub tags](https://hub.docker.com/r/codercom/code-server/tags)) and redeploy. Your volume (settings, extensions, code) is untouched.

**Where do extensions come from?**
[Open VSX](https://open-vsx.org). Most popular extensions are there; some Microsoft-proprietary ones (Pylance, Remote-SSH, Live Share) are not licensed for third-party builds.

**Can I get a plain web terminal too?**
This template is a full IDE (which includes a terminal). If you want a lightweight terminal-only sibling service, deploy a `ttyd` or Ubuntu web-terminal template alongside it — a good companion-template idea, intentionally not bundled here to keep this template single-purpose.

## Troubleshooting

| Symptom | Fix |
|---|---|
| Build succeeds but domain shows "Application failed to respond" | Domain target port must be **8080**. Service → Settings → Networking → edit domain → target port 8080. |
| Healthcheck failing | Healthcheck path must be `/healthz` (unauthenticated liveness endpoint, [docs](https://github.com/coder/code-server/blob/main/docs/FAQ.md#what-is-the-healthz-endpoint)). First boot can take longer — raise healthcheck timeout to 300s. |
| Container exits with `FATAL: neither PASSWORD nor HASHED_PASSWORD is set` | The password variable was deleted. Re-add `PASSWORD` (any strong value) or `HASHED_PASSWORD`. This is a deliberate guard, not a bug. |
| `EACCES` / read-only errors in `/home/coder` | Volume must be mounted at exactly `/home/coder`. Remounting elsewhere breaks persistence assumptions. |
| Extensions/settings gone after redeploy | Confirm the volume is attached and mounted at `/home/coder` (service → Settings → Volumes). Without a volume the home dir is ephemeral. |
| `pip install` says "externally-managed-environment" | Expected on Debian 13. Use `python3 -m venv .venv && . .venv/bin/activate`, or `pipx install <tool>`. |
| Login loop / password rejected after changing vars | Redeploy after editing variables; also clear the site's cookies. |
| Slow first load | The editor downloads web assets on first visit; subsequent loads are cached. |

## Repository layout

```
app/
  Dockerfile      # thin layer on codercom/code-server:4.129.0 (every layer commented)
  entrypoint.sh   # auth guard → volume ownership fix → privilege drop → code-server
services/
  code-server.env.template   # paste-ready variables for the Railway composer
README.md                    # this file
SECURITY.md                  # threat model, password rotation, hardening
RAILWAY-PUBLISH-GUIDE.md     # click-by-click template publishing guide
template-spec.json           # machine-readable service/volume/healthcheck spec
```

## About hosting VS Code (code-server) on Railway

code-server by Coder runs the open-source build of VS Code on a server and serves it to any browser. Railway supplies the pieces a personal cloud IDE actually needs — HTTPS domains, generated secrets, persistent volumes, vertical scaling and usage-based pricing — without you managing a VM, reverse proxy or TLS certificates. This template combines the two with the missing middle layer: a real toolchain, correct volume permissions, and safe-by-default auth.
