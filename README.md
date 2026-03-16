# Claw Runtime GCP Infrastructure

This repository provisions a private GCP lab for OpenClaw using OpenTofu.

The configuration still uses HCL's standard `terraform {}` block name because OpenTofu preserves that syntax for provider and backend settings.

## Layout

- `opentofu/environments/lab`: root environment
- `opentofu/modules/network`: VPC, subnet, router, NAT, IAP SSH firewall
- `opentofu/modules/compute`: VM, service account, startup bootstrap
- `opentofu/modules/cost_controls`: budget Pub/Sub and shutdown automation
- `workspace`: reviewed OpenClaw workspace files and skills
- `config`: local and cloud OpenClaw config templates
- `docker`: container and compose assets
- `scripts`: local and cloud run helpers

## First Run

1. Install OpenTofu and Google Cloud SDK.
2. Create a locked-down GCS bucket for remote state.
3. Update `opentofu/environments/lab/providers.tf` to enable the `gcs` backend.
4. Copy `opentofu/environments/lab/terraform.tfvars.example` to `terraform.tfvars` and set `project_id`.
5. Run:

```bash
cd /Users/sean/Repos/gcp-claw-lab/opentofu/environments/lab
tofu init
tofu fmt -recursive ../..
tofu validate
tofu plan
tofu apply
```

## Access

After apply, connect with:

```bash
gcloud compute ssh claw-runtime-vm --project claw-runtime-example --zone us-central1-a --tunnel-through-iap
```

## OpenClaw App Layer

The repository now includes a first-pass local-first scaffold for OpenClaw:

- workspace policy in [AGENTS.md](/Users/sean/Repos/gcp-claw-lab/workspace/AGENTS.md) and [TOOLS.md](/Users/sean/Repos/gcp-claw-lab/workspace/TOOLS.md)
- reviewed starter skills under [skills](/Users/sean/Repos/gcp-claw-lab/workspace/skills)
- local and cloud config templates in [config](/Users/sean/Repos/gcp-claw-lab/config)
- Docker assets in [docker](/Users/sean/Repos/gcp-claw-lab/docker)
- helper scripts in [scripts](/Users/sean/Repos/gcp-claw-lab/scripts)

Current limitation:
- the container runtime is wired for `openclaw`, but the exact provider-specific cloud auth payload still needs to be finalized

## Local OpenClaw

Native local development remains the preferred fast path.
Use [openclaw.local.json5.example](/Users/sean/Repos/gcp-claw-lab/config/openclaw.local.json5.example) as the basis for `~/.openclaw/openclaw.json`.

Native local prerequisites:
- install `ripgrep` so agent/tool flows that prefer `rg` work reliably:
  ```bash
  brew install ripgrep
  ```

Config ownership model:
- repo templates in [config](/Users/sean/Repos/gcp-claw-lab/config) are the canonical source for managed behavior
- the live local-native config in `~/.openclaw/openclaw.json` remains the active runtime file on your laptop
- auth, tokens, wizard state, and other runtime-managed fields stay outside Git
- use [check-openclaw-local-sync.mjs](/Users/sean/Repos/gcp-claw-lab/scripts/check-openclaw-local-sync.mjs) to compare managed local-native fields against the repo template

Local Docker secret source:
- create `config/secrets.local.json` from [secrets.local.json.example](/Users/sean/Repos/gcp-claw-lab/config/secrets.local.json.example)
- this file is ignored by Git
- `./scripts/render-openclaw-local.sh` renders `config/rendered/openclaw.json`
- the secret payload contract is documented in [openclaw.runtime-secrets.schema.json](/Users/sean/Repos/gcp-claw-lab/config/openclaw.runtime-secrets.schema.json)
- local Docker publishes the gateway on `127.0.0.1:18790` so it does not collide with a native local gateway on `127.0.0.1:18789`
- `./scripts/prepare-local-docker.sh` performs the upstream-style Docker bootstrap pass: render config, build images, seed state directories, and fix ownership before runtime

Cloud secret source:
- create `config/secrets.cloud.json` from [secrets.cloud.json.example](/Users/sean/Repos/gcp-claw-lab/config/secrets.cloud.json.example)
- this file is ignored by Git
- keep cloud gateway tokens and any cloud-specific secret values separate from local Docker

Telegram channel defaults:
- Telegram is the first recommended messaging platform for this lab
- keep Telegram disabled by default in the shared templates until a bot token is added
- use DM pairing only, with groups disabled
- keep `configWrites` disabled so the live instance cannot rewrite repo-managed behavior through the channel
- inject the bot token through `channels.telegram.botToken` in `config/secrets.local.json` or `config/secrets.cloud.json`
- Telegram DM pairing state persists under `~/.openclaw/credentials/` and is distinct from node device pairing state under `~/.openclaw/devices/`

## Docker Workflow

Local Docker parity check:

```bash
cd /Users/sean/Repos/gcp-claw-lab
cp config/secrets.local.json.example config/secrets.local.json
./scripts/prepare-local-docker.sh
./scripts/run-local.sh
./scripts/print-local-docker-access.sh
```

To reset Docker-local OpenClaw to a fresh state without touching native local OpenClaw:

```bash
cd /Users/sean/Repos/gcp-claw-lab
./scripts/reset-local-docker.sh
```

Cloud VM container flow:

```bash
cd /Users/sean/Repos/gcp-claw-lab
cp config/secrets.cloud.json.example config/secrets.cloud.json
./scripts/push-cloud-runtime-secret.sh OPENCLAW_SECRET_NAME PROJECT_ID [config/secrets.cloud.json]
./scripts/sync-cloud-app.sh VM_NAME PROJECT_ID ZONE
./scripts/deploy-cloud.sh VM_NAME PROJECT_ID ZONE OPENCLAW_SECRET_NAME
./scripts/run-cloud.sh OPENCLAW_CONFIG_SECRET_NAME
```

Steady-state operator actions:

- Shell into Docker-local for routine operations:
  ```bash
  cd /Users/sean/Repos/gcp-claw-lab
  bash ./scripts/shell-local-gateway.sh
  ```
- Then run inside the Docker-local container:
  ```bash
  openclaw pairing list telegram
  openclaw pairing approve telegram <CODE>
  openclaw models auth login --provider openai
  # or
  openclaw models auth paste-token --provider openai
  ```
- Shell into cloud for routine operations:
  ```bash
  cd /Users/sean/Repos/gcp-claw-lab
  bash ./scripts/shell-cloud-gateway.sh claw-runtime-vm claw-runtime-example us-central1-a
  ```
- Then run inside the cloud container:
  ```bash
  openclaw pairing list telegram
  openclaw pairing approve telegram <CODE>
  openclaw models auth login --provider openai
  # or
  openclaw models auth paste-token --provider openai
  ```
- Rotate the Docker-local gateway token:
  1. edit `config/secrets.local.json`
  2. run `./scripts/prepare-local-docker.sh`
  3. run `docker compose -f docker/compose.local.yml up -d --force-recreate openclaw-gateway`
- Rotate the cloud gateway token:
  1. edit `config/secrets.cloud.json`
  2. run `./scripts/push-cloud-runtime-secret.sh OPENCLAW_SECRET_NAME PROJECT_ID`
  3. run `./scripts/deploy-cloud.sh VM_NAME PROJECT_ID ZONE OPENCLAW_SECRET_NAME`
- Add or update skills:
  1. edit files under [workspace/skills](/Users/sean/Repos/gcp-claw-lab/workspace/skills)
  2. test locally
  3. rerun `./scripts/prepare-local-docker.sh` and restart Docker-local, or redeploy cloud
- Add or update hooks:
  1. edit the relevant repo-managed config template under [config](/Users/sean/Repos/gcp-claw-lab/config)
  2. rerender/restart locally with `./scripts/prepare-local-docker.sh`
  3. push/redeploy for cloud with `./scripts/push-cloud-runtime-secret.sh` and `./scripts/deploy-cloud.sh`
- Enable Telegram:
  1. create a bot token with BotFather
  2. set `channels.telegram.enabled` to `true` and `channels.telegram.botToken` in the relevant secrets file
  3. local Docker: run `./scripts/prepare-local-docker.sh` and restart the gateway
  4. cloud: run `./scripts/push-cloud-runtime-secret.sh` and `./scripts/deploy-cloud.sh`
  5. shell into `openclaw-gateway` and approve the Telegram pairing with:
     `openclaw pairing list telegram` then `openclaw pairing approve telegram <CODE>`
  6. Telegram messaging is now confirmed working in Docker-local; cloud should follow the same pairing/state model because `/home/node/.openclaw` persists on the host-mounted state path

Notes:
- local Docker uses named volumes for `~/.openclaw`, `workspace/.openclaw`, and `workspace/memory`
- local Docker bootstrap is intentionally modeled on upstream `docker-setup.sh`, but preserves this repo's rendered-config and shared-workspace approach
- the Docker image installs `ripgrep` so `rg` is available inside Docker-local and cloud containers
- cloud Docker persists runtime state under `/opt/openclaw/state`
- the runtime gateway mounts the reviewed repository workspace read-only and only writable state paths remain mutable
- the writable runtime paths are `/home/node/.openclaw`, `/workspace/.openclaw`, and `/workspace/memory`
- the optional `openclaw-dev` container is a separate root-owned dev shell for VS Code and experiments; it shares the same runtime volumes but does not run a second gateway
- container startup treats the rendered config as authoritative for managed fields and preserves runtime metadata in persisted state
- rendered config is the right place for `gateway.auth` and other config-bound secrets
- provider auth is established inside each environment and persists in runtime state under `~/.openclaw` or `/opt/openclaw/state/home`
- redeploying a container preserves provider auth only if the persistent state path or volume is preserved
- persisted runtime state should be treated as sensitive because it may contain live provider credentials
- steady-state operations should use targeted commands such as `openclaw models auth ...` and `openclaw devices ...`; avoid `onboard`/`configure` for routine container administration
- for routine container administration, shell into `openclaw-gateway` and run OpenClaw commands there rather than relying on long one-off `docker compose ... run` commands
- `boot-md` is explicitly disabled in the repo-managed templates; the allowed bundled internal hooks are `bootstrap-extra-files`, `command-logger`, and `session-memory`
- Telegram DM pairing approvals live under `~/.openclaw/credentials/`; OpenClaw node/app device pairing approvals live under `~/.openclaw/devices/`

Email integration starter:
- A Gmail `gog` integration skill is available at [pip-gmail-gog](/Users/sean/Repos/gcp-claw-lab/workspace/skills/pip-gmail-gog/SKILL.md)
- A Gmail send skill is available at [pip-gmail-send](/Users/sean/Repos/gcp-claw-lab/workspace/skills/pip-gmail-send/SKILL.md)
- Local-first Gmail webhook setup helper:
  ```bash
  bash ./scripts/gmail/setup-gog-local.sh automation@example.com [PROJECT_ID]
  ```
- Manual local watcher helper (only if not using gateway-managed watcher):
  ```bash
  bash ./scripts/gmail/run-gog-local.sh
  ```
- Local send helper:
  ```bash
  printf 'This is a test from Pip.\n' | bash ./scripts/gmail/send-gog-local.sh automation@example.com user@example.com "Pip test" -
  ```
- Docker Gmail bootstrap helper:
  ```bash
  bash ./scripts/gmail/bootstrap-gog-docker-local.sh automation@example.com
  ```
  This command starts the Docker-local gateway if needed, installs Gmail OAuth client credentials into the container, tries to import an existing host `gog` token, and if no exportable host token exists falls back to an interactive Gmail consent flow inside the container.
- Local HTML send helper:
  ```bash
  printf 'This is a test from Pip.\n' | bash ./scripts/gmail/send-gog-local.sh \
    automation@example.com \
    user@example.com \
    "Pip HTML test" \
    - \
    /Users/sean/Repos/gcp-claw-lab/workspace/.tmp/pip-test.html
  ```
- Current daily digest default is 24-hour historical pull from email using sender/title/content matching; Pub/Sub/webhook ingestion is kept configured as optional context/future realtime enhancement.
- `pip-newsletter-digest` now sends the completed digest by default as an HTML email with a plain-text fallback from `automation@example.com` to `user@example.com` with subject `Pip Newsletter Digest - YYYY-MM-DD`.

Gmail + gog + Tailscale runbook (local-native):
- Preconditions:
  - `gcloud`, `openclaw`, `tailscale`, and `gog` are installed
  - Google OAuth/Gmail setup is completed for `automation@example.com`
  - GCP project is `claw-runtime-example`
- If org policy requires an environment tag, bind it on project `707779566246` before setup.
- Keep gateway Tailscale mode off:
  ```bash
  openclaw config set gateway.tailscale.mode off
  ```
- Bring up Tailscale:
  ```bash
  tailscale up
  tailscale status
  ```
- Configure Gmail webhook setup with Tailscale Funnel:
  ```bash
  openclaw webhooks gmail setup \
    --account automation@example.com \
    --project claw-runtime-example \
    --tailscale funnel
  ```
- Run watcher when needed:
  ```bash
  openclaw webhooks gmail run
  ```

Decisions captured:
- Newsletter digest source of truth is Gmail API historical backfill over rolling 24 hours.
- Pub/Sub/webhook ingestion remains configured as optional context/future realtime use.
- Current newsletter digest behavior is defined in [pip-newsletter-digest](/Users/sean/Repos/gcp-claw-lab/workspace/skills/pip-newsletter-digest/SKILL.md).
- Telegram pairing workflow uses:
  - `openclaw pairing list telegram`
  - `openclaw pairing approve telegram <CODE>`

Reading workflow starter skills:
- [pip-newsletter-digest](/Users/sean/Repos/gcp-claw-lab/workspace/skills/pip-newsletter-digest/SKILL.md) for newsletter-only daily digest (email input only)
- Default behavior for [pip-newsletter-digest](/Users/sean/Repos/gcp-claw-lab/workspace/skills/pip-newsletter-digest/SKILL.md):
  1. generate the digest
  2. email it to `user@example.com`
  3. if send fails, still return the digest and report the delivery failure

Local security shutdown helper:
- Stop local OpenClaw runtime (Docker + native service/processes), bring Tailscale down, and quit the Tailscale app UI:
  ```bash
  bash ./scripts/security-shutdown-local.sh
  ```
- Keep the Tailscale app UI running:
  ```bash
  bash ./scripts/security-shutdown-local.sh --keep-tailscale-app
  ```

Cloud operator notes:
- OpenTofu creates the Secret Manager secret container and grants the VM service account secret accessor on that secret
- Push a secret version with [push-cloud-runtime-secret.sh](/Users/sean/Repos/gcp-claw-lab/scripts/push-cloud-runtime-secret.sh) before first cloud runtime start
- Sync the app bundle to `/opt/openclaw/app` on the VM with [sync-cloud-app.sh](/Users/sean/Repos/gcp-claw-lab/scripts/sync-cloud-app.sh)
- [deploy-cloud.sh](/Users/sean/Repos/gcp-claw-lab/scripts/deploy-cloud.sh) installs Docker on the VM if needed, renders the cloud runtime config on the host, and starts the gateway container
- Cloud runtime state persists under `/opt/openclaw/state/{home,runtime,workspace,memory}`

Cloud secret payload shape:
- the GCP secret should contain a JSON object shaped like [secrets.cloud.json.example](/Users/sean/Repos/gcp-claw-lab/config/secrets.cloud.json.example)
- the payload contract is documented in [openclaw.runtime-secrets.schema.json](/Users/sean/Repos/gcp-claw-lab/config/openclaw.runtime-secrets.schema.json)
- that JSON is merged into [openclaw.cloud.json5.example](/Users/sean/Repos/gcp-claw-lab/config/openclaw.cloud.json5.example) to produce `/opt/openclaw/state/runtime/openclaw.json`
