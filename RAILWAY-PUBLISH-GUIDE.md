# Railway Publish Guide — Cloud Dev Box (code-server)

Click-by-click instructions to turn this repo into a published Railway
template. Assumes the repo is pushed to GitHub with this layout (Dockerfile
under `app/`).

---

## 0. Prerequisites

- [ ] This repo pushed to a **public** GitHub repository (templates deploy
      from your repo; public avoids GitHub-auth friction for deployers).
- [ ] Railway account with GitHub connected.
- [ ] 10 minutes for the smoke test.

## 1. Compose the template

1. Go to **railway.com → Dashboard → Templates → New Template**
   (or `railway.com/compose`).
2. Click **+ Add New Service** → **GitHub Repo** → pick
   `<your-user>/codeserver-devbox`.
3. Rename the service to `code-server` (click the service name).
4. **Settings → Root Directory**: set to `/app`
   (the Dockerfile and entrypoint live there; Railway auto-detects the
   Dockerfile builder).

## 2. Variables (paste-ready)

Service → **Variables** → **Raw Editor**, paste:

```
PASSWORD=${{ secret(24) }}
WORKSPACE_DIR=/home/coder/project
```

Notes:
- `${{ secret(24) }}` is template-composer syntax: each deploy of the template
  generates a fresh 24-character secret. Do **not** replace it with a literal.
- Full optional set (idle timeout, download blocking, hashed password) is in
  [`services/code-server.env.template`](services/code-server.env.template).

## 3. Volume

1. Right-click the service (or Settings → Volumes) → **Attach Volume**.
2. **Mount path**: `/home/coder`  ← exactly this; it's the coder user's home
   and holds code, extensions, settings, SSH keys in one mount.

## 4. Networking

1. Service → **Settings → Networking → Public Networking → Generate Domain**.
2. **Target port**: `8080` (the entrypoint binds `0.0.0.0:${PORT:-8080}`).

## 5. Healthcheck & deploy settings

Service → **Settings → Deploy**:

- **Healthcheck Path**: `/healthz`
  (code-server's unauthenticated liveness endpoint — upstream docs:
  https://github.com/coder/code-server/blob/main/docs/FAQ.md#what-is-the-healthz-endpoint)
- **Healthcheck Timeout**: `300` seconds (first boot chowns the volume and
  cold-starts the editor).
- **Restart Policy**: `On Failure`.
- **Replicas**: `1` — never more; the volume and editor sessions are
  single-writer.

## 6. Publish metadata

Click **Publish** (top right) and fill in:

| Field | Paste this |
|---|---|
| **Name** | `Cloud Dev Box — VS Code (code-server)` |
| **Category** | Developer Tools |
| **Short description** | `VS Code in your browser with password auth, persistent storage, and git, Node 22 LTS, Python 3 & build tools preinstalled. A real cloud dev box, not a bare editor.` |
| **Tags** | `vscode, code-server, ide, cloud-ide, dev-environment` |
| **Overview / long description** | Copy the top sections of [`README.md`](README.md) (title through "How persistence works"). Railway renders Markdown. |
| **Demo/teaser image** | Screenshot of the editor at your deployed domain with a terminal open running `node --version && python3 --version && gcc --version`. |

Guidance on wording/SEO: Railway's template guidelines at
`docs.railway.com/reference/templates` — the "Deploy and Host X on Railway"
phrasing in the README title matches their recommended SEO structure.

## 7. Kickback checklist (earn the 15–25% kickback)

Railway pays template authors a share of usage their template generates
(Template Marketplace kickback program). To qualify and convert well:

- [ ] Template published under your Railway account (kickback accrues there).
- [ ] README in the repo — deployers see it; it reduces churn (churned
      projects don't generate usage).
- [ ] Pinned image tag — broken builds after an upstream `latest` change are
      the #1 silent template killer.
- [ ] Healthcheck configured — failed-at-boot deploys never become paying
      usage.
- [ ] Volume attached in the template itself — users who lose work churn
      immediately.
- [ ] Description mentions concrete keywords people search: "VS Code",
      "code-server", "cloud IDE", "browser IDE", "dev environment".
- [ ] After publishing, deploy your own template from the marketplace page
      once (verifies the exact flow a stranger gets).
- [ ] Share the template URL (`railway.com/deploy/<slug>`) in the repo README
      badge.

## 8. Smoke test (do this before sharing the link)

Deploy your just-published template into a scratch project, then:

1. **Build completes** (~2–4 min) with no red lines about apt or NodeSource.
2. **Healthcheck passes** — deploy goes green; `curl https://<domain>/healthz`
   returns `{"status":"alive"...}` or `{"status":"expired"...}`.
3. **Auth works** — visiting the domain shows the code-server login page;
   the `PASSWORD` value from service → Variables logs you in; a wrong
   password does not.
4. **Toolchain present** — in the IDE terminal:
   `git --version && node -v && npm -v && corepack --version && python3 -V && pip --version && gcc --version && sudo whoami`
   → `node -v` prints `v22.x`, `sudo whoami` prints `root`, no errors.
5. **Ownership correct** — `stat -c '%U' /home/coder` prints `coder`;
   `touch /home/coder/project/x` succeeds.
6. **Persistence** — create `/home/coder/project/hello.txt` and install an
   extension; **redeploy** the service; both are still there.
7. **Auth guard** — temporarily delete `PASSWORD`; redeploy; deploy fails
   with `FATAL: neither PASSWORD nor HASHED_PASSWORD is set` in logs.
   Restore `PASSWORD`, redeploy, confirm green again.
8. Delete the scratch project.

## 9. Post-publish maintenance

- Watch https://github.com/coder/code-server/releases; bump the tag in
  `app/Dockerfile` (both the `FROM` line and README references) for security
  releases. Tag verification one-liner:
  `curl -s https://hub.docker.com/v2/repositories/codercom/code-server/tags/<TAG>/ | jq .tag_last_pushed`
- Re-run the smoke test after every bump; push; Railway templates track your
  repo's default branch.
- Sibling-template idea (separate listing, don't bolt on here): a `ttyd`
  Ubuntu web terminal — same entrypoint pattern (secret password, volume at
  the user home, privilege drop), ~10x lighter image, targets the
  web-terminal niche (150–2.1K deploys per existing template).
