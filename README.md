# Claw Runtime GCP Infrastructure

This repository provisions a private GCP lab for OpenClaw using OpenTofu.

The configuration still uses HCL's standard `terraform {}` block name because OpenTofu preserves that syntax for provider and backend settings.

## Layout

- `opentofu/environments/lab`: root environment
- `opentofu/modules/network`: VPC, subnet, router, NAT, IAP SSH firewall
- `opentofu/modules/compute`: VM, service account, startup bootstrap
- `opentofu/modules/cost_controls`: budget Pub/Sub and shutdown automation
- `workspace`: reviewed OpenClaw workspace files
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

## Setup and Usage

This repo has three operating modes:

- native local: fastest iteration on your laptop
- Docker-local: local cloud-parity runtime
- cloud: Docker on the GCP VM

### Dependency management

Pinned runtime versions live in [versions.json](/Users/sean/Repos/gcp-claw-lab/versions.json).

Use:

```bash
cd /Users/sean/Repos/gcp-claw-lab
npm run deps:show
```

That reports:

- pinned repo versions
- installed local `openclaw`
- installed local `gog`
- local Docker / Node / npm / ripgrep versions

After editing [versions.json](/Users/sean/Repos/gcp-claw-lab/versions.json), regenerate derived files with:

```bash
cd /Users/sean/Repos/gcp-claw-lab
npm run deps:sync
npm run deps:lock:function
```

What this updates:

- `config/docker.build.env` for Docker build args
- Cloud Function `package.json` from the central version manifest
- Cloud Function `package-lock.json`

Native-local host tools are still operator-managed. The repo does not auto-upgrade your Homebrew-installed `openclaw`, `gog`, or `ripgrep`.

### Authentication and secrets

Secrets are split by environment:

- [config/secrets.local.json](/Users/sean/Repos/gcp-claw-lab/config/secrets.local.json)
- [config/secrets.cloud.json](/Users/sean/Repos/gcp-claw-lab/config/secrets.cloud.json)

Start from:

- [config/secrets.local.json.example](/Users/sean/Repos/gcp-claw-lab/config/secrets.local.json.example)
- [config/secrets.cloud.json.example](/Users/sean/Repos/gcp-claw-lab/config/secrets.cloud.json.example)

Rules:

- repo templates under [config](/Users/sean/Repos/gcp-claw-lab/config) are the source of truth for managed behavior
- secret overlay files are Git-ignored and hold config-bound secret values
- runtime auth state stays environment-local:
  - native local: `~/.openclaw`
  - Docker-local: `/home/node/.openclaw`
  - cloud: `/opt/openclaw/state/home`

Current auth model:

- native local
  - OpenAI/provider auth: local OAuth or local provider auth is fine
  - Gmail: user OAuth is fine
- Docker-local
  - OpenAI API key: store under `auth.profiles.<profile>.apiKey` in `config/secrets.local.json`
  - Gmail service account: store JSON object under `gog.serviceAccounts["automation@example.com"]` in `config/secrets.local.json`
- cloud
  - config secrets come from Secret Manager via `config/secrets.cloud.json` shape
  - Gmail service-account bootstrap remains explicit

Docker-local notes:

- `./scripts/prepare-local-docker.sh` renders:
  - `config/rendered/openclaw.json`
  - `config/docker.local.env`
  - `config/docker.build.env`
  - `config/rendered/gog-service-account.json` when Gmail service-account data is present
- Gmail Pub/Sub/webhook hooks should stay disabled in Docker-local unless you are explicitly testing realtime ingestion

### Native local

Use [config/openclaw.local.json5.example](/Users/sean/Repos/gcp-claw-lab/config/openclaw.local.json5.example) as the basis for `~/.openclaw/openclaw.json`.

Recommended prerequisite:

```bash
brew install ripgrep
```

### Docker-local

Initial setup:

```bash
cd /Users/sean/Repos/gcp-claw-lab
npm run deps:sync
cp config/secrets.local.json.example config/secrets.local.json
bash ./scripts/prepare-local-docker.sh
bash ./scripts/run-local.sh
bash ./scripts/print-local-docker-access.sh
```

Gateway addresses:

- native local: `http://127.0.0.1:18789`
- Docker-local: `http://127.0.0.1:18790`

Routine operations:

- shell into the Docker-local gateway:
  ```bash
  bash /Users/sean/Repos/gcp-claw-lab/scripts/shell-local-gateway.sh
  ```
- recreate the gateway after secret/config changes:
  ```bash
  docker compose --env-file /Users/sean/Repos/gcp-claw-lab/config/docker.build.env -f /Users/sean/Repos/gcp-claw-lab/docker/compose.local.yml up -d --force-recreate openclaw-gateway
  ```
- reset Docker-local state without touching native local:
  ```bash
  bash /Users/sean/Repos/gcp-claw-lab/scripts/reset-local-docker.sh
  ```

### Cloud

Cloud container flow:

```bash
cd /Users/sean/Repos/gcp-claw-lab
npm run deps:sync
cp config/secrets.cloud.json.example config/secrets.cloud.json
bash ./scripts/push-cloud-runtime-secret.sh OPENCLAW_SECRET_NAME PROJECT_ID [config/secrets.cloud.json]
bash ./scripts/sync-cloud-app.sh VM_NAME PROJECT_ID ZONE
bash ./scripts/deploy-cloud.sh VM_NAME PROJECT_ID ZONE OPENCLAW_SECRET_NAME
bash ./scripts/run-cloud.sh OPENCLAW_CONFIG_SECRET_NAME
```

Shell into the cloud gateway:

```bash
bash /Users/sean/Repos/gcp-claw-lab/scripts/shell-cloud-gateway.sh VM_NAME PROJECT_ID ZONE
```

### Setup scripts

Primary scripts:

- local Docker
  - [prepare-local-docker.sh](/Users/sean/Repos/gcp-claw-lab/scripts/prepare-local-docker.sh)
  - [run-local.sh](/Users/sean/Repos/gcp-claw-lab/scripts/run-local.sh)
  - [reset-local-docker.sh](/Users/sean/Repos/gcp-claw-lab/scripts/reset-local-docker.sh)
  - [print-local-docker-access.sh](/Users/sean/Repos/gcp-claw-lab/scripts/print-local-docker-access.sh)
- cloud
  - [push-cloud-runtime-secret.sh](/Users/sean/Repos/gcp-claw-lab/scripts/push-cloud-runtime-secret.sh)
  - [sync-cloud-app.sh](/Users/sean/Repos/gcp-claw-lab/scripts/sync-cloud-app.sh)
  - [deploy-cloud.sh](/Users/sean/Repos/gcp-claw-lab/scripts/deploy-cloud.sh)
  - [run-cloud.sh](/Users/sean/Repos/gcp-claw-lab/scripts/run-cloud.sh)

Supporting scripts:

- Gmail service-account bootstrap
  - [bootstrap-gog-docker-local.sh](/Users/sean/Repos/gcp-claw-lab/scripts/gmail/bootstrap-gog-docker-local.sh)
  - [bootstrap-gog-cloud-service-account.sh](/Users/sean/Repos/gcp-claw-lab/scripts/gmail/bootstrap-gog-cloud-service-account.sh)
- Gmail send helper
  - [send-gog-local.sh](/Users/sean/Repos/gcp-claw-lab/scripts/gmail/send-gog-local.sh)
- local shutdown
  - [security-shutdown-local.sh](/Users/sean/Repos/gcp-claw-lab/scripts/security-shutdown-local.sh)

### Gmail testing

Host test:

```bash
printf 'Pip Gmail send test\n' | gog gmail send \
  --account automation@example.com \
  --to user@example.com \
  --subject "Pip Gmail send test" \
  --body-file=-
```

Docker-local test:

```bash
docker compose --env-file /Users/sean/Repos/gcp-claw-lab/config/docker.build.env -f /Users/sean/Repos/gcp-claw-lab/docker/compose.local.yml exec -T openclaw-gateway \
  bash -lc 'printf "Docker gateway Gmail send test\n" | gog gmail send --account automation@example.com --to user@example.com --subject "Pip Docker Gmail send test" --body-file=-'
```

Docker-local read test:

```bash
docker compose --env-file /Users/sean/Repos/gcp-claw-lab/config/docker.build.env -f /Users/sean/Repos/gcp-claw-lab/docker/compose.local.yml exec -T openclaw-gateway \
  gog gmail search "newer_than:1d" --account automation@example.com --plain
```
