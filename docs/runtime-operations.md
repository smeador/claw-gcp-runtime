# Runtime Operations

This document is the detailed operator runbook for the local and cloud runtime.

Use [README.md](../README.md) as the front door. Use this file when you need the heavier operational detail.

## Operator Environment

Recommended local setup:

- install `direnv`
- create `.envrc.local`
- let the repo-managed `.envrc` expose `claw-runtime` on `PATH`

Example:

```bash
cd /path/to/claw-gcp-runtime
cp .envrc.example .envrc
cat > .envrc.local <<'EOF'
export VM_NAME=claw-runtime-vm
export PROJECT_ID=your-gcp-project-id
export ZONE=us-central1-a
export OPENCLAW_SECRET_NAME=your-secret-name
export CLOUD_SECRET_FILE=config/secrets.cloud.json
export GMAIL_TEST_TO=operator@example.com
EOF
direnv allow
```

OpenTofu also expects a local backend config file and a local deployment config:

- copy [`opentofu/environments/lab/backend.gcs.hcl.example`](../opentofu/environments/lab/backend.gcs.hcl.example) to `opentofu/environments/lab/backend.gcs.hcl`
- copy [`opentofu/environments/lab/terraform.tfvars.example`](../opentofu/environments/lab/terraform.tfvars.example) to `opentofu/environments/lab/terraform.tfvars`

Those files are ignored and are the right place for your real bucket name, VM name, and other deployment-specific identifiers.

## Secret Files

Start from:

- [`config/secrets.local.example.json`](../config/secrets.local.example.json)
- [`config/secrets.cloud.example.json`](../config/secrets.cloud.example.json)

Local runtime secrets live in:

- `config/secrets.local.json`

Cloud runtime secrets live in:

- `config/secrets.cloud.json`

Create real secret files with mode `0600` so only the local owner can read or edit them:

```bash
install -m 600 config/secrets.local.example.json config/secrets.local.json
install -m 600 config/secrets.cloud.example.json config/secrets.cloud.json
```

## Local Runtime

Initial setup:

```bash
cd /path/to/claw-gcp-runtime
npm run deps:sync
install -m 600 config/secrets.local.example.json config/secrets.local.json
claw-runtime local deploy
```

Common commands:

```bash
claw-runtime local help
claw-runtime local deploy
claw-runtime local restart
claw-runtime local rebuild
claw-runtime local prune
claw-runtime local ps
claw-runtime local logs
claw-runtime local agent-logs
claw-runtime local shell
claw-runtime local cron apply
claw-runtime local cron list
claw-runtime local cron run-digest
claw-runtime local test basic
claw-runtime local test core
claw-runtime local test integration
claw-runtime local test skill newsletter-digest
claw-runtime local test gmail-read
claw-runtime local test gmail-send
```

Useful maintenance helpers:

```bash
bash scripts/maintenance/reset-local-docker.sh
bash scripts/maintenance/print-local-docker-access.sh
node scripts/maintenance/check-native-local-sync.mjs
```

## Cloud Runtime

Initial setup:

```bash
cd /path/to/claw-gcp-runtime
npm run deps:sync
install -m 600 config/secrets.cloud.example.json config/secrets.cloud.json
claw-runtime cloud push-secret
claw-runtime cloud deploy
```

Common commands:

```bash
claw-runtime cloud help
claw-runtime cloud push-secret
claw-runtime cloud sync
claw-runtime cloud deploy
claw-runtime cloud restart
claw-runtime cloud rebuild
claw-runtime cloud prune
claw-runtime cloud ps
claw-runtime cloud logs
claw-runtime cloud agent-logs
claw-runtime cloud logs-download
claw-runtime cloud shell
claw-runtime cloud tunnel
claw-runtime cloud cron apply
claw-runtime cloud cron list
claw-runtime cloud cron run-digest
claw-runtime cloud test skill newsletter-digest
claw-runtime cloud test gmail-read
claw-runtime cloud test gmail-send
```

Direct VM shell:

```bash
bash scripts/cloud/ssh-app.sh bash
```

## Deploy, Restart, and State Migration

| Command | Behavior |
| --- | --- |
| `local deploy` / `cloud deploy` | Build with cache, stop the gateway for doctor migration, recreate it, and reconcile cron. Cloud also uploads the app and runs automatic storage cleanup before building and on exit. |
| `local rebuild` / `cloud rebuild` | Same lifecycle with a no-cache image build. |
| `local restart` / `cloud restart` | Re-render config and recreate the gateway using the existing image. No build or doctor migration. Cloud uses the app already on the VM; it does not upload local changes. |
| `cloud sync` | Upload the app bundle; does not by itself apply it to a running gateway. |
| `cloud prune` | Explicit broad image pruning; can remove tagged rollback images. Not required after normal deploy/rebuild. |

Use deploy/rebuild for runtime version upgrades. OpenClaw 2026.9.2 migrates state to SQLite; do not recreate legacy auth/approval files or downgrade against migrated state. See [upgrade and rollback steps](openclaw-2026.9.2-upgrade.md) and [storage retention](cloud-docker-storage.md). Native OpenClaw is operator-managed and separate from `claw-runtime local`, which targets Docker.

`agent-logs` currently searches legacy JSONL session files; after SQLite migration it can show no transcript or an old archived transcript. Use workflow artifacts, `openclaw sessions --json`, `openclaw sessions tail --agent main`, and `claw-runtime local logs` / `cloud logs` for current diagnosis until that helper is migrated.

## Gmail Bootstrap and Testing

Normal path:

- store service-account material in the local/cloud secret overlay
- let the runtime render the key and bootstrap `gog`
- verify with the runtime test commands

`gmail-read` reads mail. `gmail-send`, the newsletter skill test, and `cron run-digest` can send real email; choose those only when delivery is intended.

Verification commands:

```bash
claw-runtime local test gmail-read
claw-runtime local test gmail-send
claw-runtime cloud test gmail-read
claw-runtime cloud test gmail-send
```

Manual recovery scripts still exist for break-glass recovery:

- [`scripts/gmail/bootstrap-gog-docker-local.sh`](../scripts/gmail/bootstrap-gog-docker-local.sh)
- [`scripts/gmail/bootstrap-gog-cloud-service-account.sh`](../scripts/gmail/bootstrap-gog-cloud-service-account.sh)

## Runtime Notes

- `workspace/skills` is generated composed state
- some integration-owned files under `workspace/config` are also generated composed state
- local cron is disabled by default to avoid duplicate sends when cloud cron is active
- cloud deploy packages sibling integrations from the local checkout at deploy time
- the VM does not fetch sibling integration repos directly during deploy
