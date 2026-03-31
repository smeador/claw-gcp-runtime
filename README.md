# Agent Lab GCP Infrastructure

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
gcloud compute ssh agent-lab-vm --project agent-lab-488918 --zone us-central1-a --tunnel-through-iap
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

Check auto-managed latest versions without editing anything:

```bash
cd /Users/sean/Repos/gcp-claw-lab
npm run deps:check
```

Auto-bump the registry-backed entries in [versions.json](/Users/sean/Repos/gcp-claw-lab/versions.json):

```bash
cd /Users/sean/Repos/gcp-claw-lab
npm run deps:bump
```

`deps:bump` updates:

- `runtime.openclawVersion`
- `runtime.gogVersion`
- `cloudFunction.dependencies.*`

It intentionally does not auto-bump:

- `docker.goImage`
- `docker.nodeImage`
- `cloudFunction.node`

Those remain manual family pins so we do not silently jump Docker base-image tracks or Cloud Functions runtime majors.

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

### Local operator environment with direnv

For cloud commands, the easiest setup is `direnv`.

Install it on macOS with:

```bash
brew install direnv
```

Then hook it into your shell following the `direnv` install instructions for your shell, and in this repo create a local file:

```bash
cd /Users/sean/Repos/gcp-claw-lab
cp .envrc.example .envrc
cat > .envrc.local <<'EOF'
export VM_NAME=agent-lab-vm
export PROJECT_ID=agent-lab-488918
export ZONE=us-central1-a
export OPENCLAW_SECRET_NAME=REPLACE_ME
export CLOUD_SECRET_FILE=config/secrets.cloud.json
export GMAIL_TEST_TO=sean@meador.me
EOF
direnv allow
```

`.envrc` and `.envrc.local` are Git-ignored. Use them for operator defaults such as VM/project/zone/secret name, not for runtime secret payloads. Keep runtime secrets in [config/secrets.cloud.json](/Users/sean/Repos/gcp-claw-lab/config/secrets.cloud.json).

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
  - provider auth: local OAuth or local provider auth is fine
  - Gmail: user OAuth is fine
- Docker-local
  - provider API key: store under `auth.profiles.<profile>.apiKey` in `config/secrets.local.json`
  - OpenRouter is the recommended API-key provider for this repo
  - Gmail service account: store JSON object under `gog.serviceAccounts["pip@meador.me"]` in `config/secrets.local.json`
- cloud
  - config secrets come from Secret Manager via `config/secrets.cloud.json` shape
  - provider API key: store under `auth.profiles.<profile>.apiKey` in `config/secrets.cloud.json`
  - OpenRouter is the recommended API-key provider for this repo
  - Gmail service account: store JSON object under `gog.serviceAccounts["pip@meador.me"]` in `config/secrets.cloud.json`

Recommended default model/profile:

- auth profile: `openrouter:default`
- provider: `openrouter`
- model: `openrouter/openai/gpt-5.4`

The runtime env renderer will emit `OPENROUTER_API_KEY` automatically when the profile provider is `openrouter`.

Docker-local notes:

- `./scripts/prepare-local-docker.sh` renders:
  - `config/rendered/openclaw.json`
  - `config/docker.local.env`
  - `config/docker.build.env`
  - `config/rendered/gog-service-account.json` when Gmail service-account data is present
- Gmail Pub/Sub/webhook hooks should stay disabled in Docker-local unless you are explicitly testing realtime ingestion

Cloud notes:

- `./scripts/render-openclaw-cloud.sh` renders on the VM host:
  - `${OPENCLAW_DEPLOY_ROOT}/state/runtime/openclaw.json`
  - `${OPENCLAW_DEPLOY_ROOT}/state/runtime/runtime.env`
  - `${OPENCLAW_DEPLOY_ROOT}/state/runtime/gog-service-account.json` when Gmail service-account data is present
- the cloud host needs `node`, `npm`, Docker, `curl`, and `jq`; `deploy-cloud.sh` installs those through `scripts/install-cloud-host.sh`

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

- local Docker command list:
  ```bash
  npm run local:help
  ```
- prepare and start the local gateway:
  ```bash
  npm run local:deploy
  ```
- restart the local gateway after secret/runtime config changes without rebuilding:
  ```bash
  npm run local:restart
  ```
- force a clean local image rebuild and recreate the gateway:
  ```bash
  npm run local:rebuild
  ```
- show local Docker status and logs:
  ```bash
  npm run local:ps
  npm run local:logs
  ```
- shell into the Docker-local gateway:
  ```bash
  npm run local:shell
  ```
- recreate the gateway after secret/config changes:
  ```bash
  npm run local:restart
  ```
- reset Docker-local state without touching native local:
  ```bash
  bash /Users/sean/Repos/gcp-claw-lab/scripts/reset-local-docker.sh
  ```
- local cron config is repo-managed in [config/cron.local.json](/Users/sean/Repos/gcp-claw-lab/config/cron.local.json) and disabled by default to avoid duplicate scheduled sends when cloud cron is active:
  ```bash
  npm run local:cron:apply
  npm run local:cron:list
  npm run local:cron:run:digest
  ```
- local Gmail and digest test commands:
  ```bash
  npm run local:test:gmail:read
  npm run local:test:gmail:send
  npm run local:test:digest
  ```

Optional local overrides:

- `LOCAL_CRON_FILE` to use a cron config file other than `config/cron.local.json`
- `TAIL_LINES` for `local:logs`
- `GMAIL_TEST_TO` and `GMAIL_TEST_SUBJECT` for `local:test:gmail:send`
- `DIGEST_MESSAGE` for `local:test:digest`

### Cloud

Cloud container flow:

```bash
cd /Users/sean/Repos/gcp-claw-lab
npm run deps:sync
cp config/secrets.cloud.json.example config/secrets.cloud.json
bash ./scripts/push-cloud-runtime-secret.sh OPENCLAW_SECRET_NAME PROJECT_ID [config/secrets.cloud.json]
bash ./scripts/sync-cloud-app.sh VM_NAME PROJECT_ID ZONE
bash ./scripts/deploy-cloud.sh VM_NAME PROJECT_ID ZONE OPENCLAW_SECRET_NAME
```

`deploy-cloud.sh` is the normal operator entrypoint. It syncs the app, installs cloud host prerequisites, renders runtime artifacts on the VM, and starts the cloud gateway container.

Convenience commands:

Set these once in your shell for the current session, or load them automatically with `direnv` as described above:

```bash
export VM_NAME=agent-lab-vm
export PROJECT_ID=agent-lab-488918
export ZONE=us-central1-a
export OPENCLAW_SECRET_NAME=REPLACE_ME
```

Then use:

```bash
npm run cloud:help
npm run cloud:push-secret
npm run cloud:deploy
npm run cloud:restart
npm run cloud:rebuild
npm run cloud:ps
npm run cloud:logs
npm run cloud:shell
npm run cloud:cron:apply
npm run cloud:cron:list
npm run cloud:cron:run:digest
npm run cloud:test:gmail:read
npm run cloud:test:gmail:send
npm run cloud:test:digest
```

Optional overrides:

- `CLOUD_SECRET_FILE` to use a secret file other than `config/secrets.cloud.json`
- `CLOUD_CRON_FILE` to use a cron config file other than `config/cron.cloud.json`
- `TAIL_LINES` for `cloud:logs`
- `GMAIL_TEST_TO` and `GMAIL_TEST_SUBJECT` for `cloud:test:gmail:send`
- `DIGEST_MESSAGE` for `cloud:test:digest`

Cloud command guidance:

- `npm run cloud:deploy`
  - normal safe default
  - syncs app files, installs host prerequisites, renders runtime artifacts, and rebuilds with Docker cache enabled
- `npm run cloud:restart`
  - fastest path when only the cloud secret payload or other runtime inputs changed
  - does not rebuild the image
- `npm run cloud:rebuild`
  - use when the image seems stale or suspicious, after Dockerfile/runtime build changes, or after odd image-content problems
  - forces a clean `--no-cache` image rebuild before recreating the gateway
- `npm run cloud:cron:apply`
  - reconcile repo-managed cloud cron jobs into the gateway by name
  - removes duplicate jobs with the same name and updates the surviving job to match config

Repo-managed cloud cron config lives in [config/cron.cloud.json](/Users/sean/Repos/gcp-claw-lab/config/cron.cloud.json).

Local Docker command guidance:

- `npm run local:deploy`
  - normal local operator entrypoint
  - renders runtime artifacts, builds with Docker cache enabled, seeds writable state paths, starts the local gateway, and reconciles local cron config
- `npm run local:restart`
  - fastest path when only local secret payloads or runtime-rendered config changed
  - does not rebuild the image
- `npm run local:rebuild`
  - use when the local image seems stale or suspicious, after Dockerfile/runtime build changes, or after odd image-content problems
  - forces a clean `--no-cache` image rebuild before recreating the gateway
- `npm run local:cron:apply`
  - reconcile repo-managed local cron jobs into the gateway by name
  - local cron is disabled by default in [config/cron.local.json](/Users/sean/Repos/gcp-claw-lab/config/cron.local.json) to avoid duplicate scheduled sends

Cloud secret setup:

1. Create [config/secrets.cloud.json](/Users/sean/Repos/gcp-claw-lab/config/secrets.cloud.json) from the example:

   ```bash
   cd /Users/sean/Repos/gcp-claw-lab
   cp config/secrets.cloud.json.example config/secrets.cloud.json
   ```

2. Fill in the fields you need for the first cloud run:
   - `gateway.auth.token`
   - `auth.profiles.openrouter:default.apiKey`
   - `gog.serviceAccounts["pip@meador.me"]`
   - optional `channels.telegram.botToken`
   - keep `hooks.enabled` set to `false` unless you are explicitly setting up cloud Gmail hooks

3. Push the secret payload to Secret Manager:

   ```bash
   cd /Users/sean/Repos/gcp-claw-lab
   bash ./scripts/push-cloud-runtime-secret.sh OPENCLAW_SECRET_NAME PROJECT_ID config/secrets.cloud.json
   ```

4. Deploy the cloud runtime:

   ```bash
   cd /Users/sean/Repos/gcp-claw-lab
   npm run deps:sync
   bash ./scripts/deploy-cloud.sh VM_NAME PROJECT_ID ZONE OPENCLAW_SECRET_NAME
   ```

5. Verify the rendered cloud runtime from inside the gateway container:

   ```bash
   bash /Users/sean/Repos/gcp-claw-lab/scripts/shell-cloud-gateway.sh VM_NAME PROJECT_ID ZONE
   ```

   Then test Gmail read/send:

   ```bash
   gog gmail search "newer_than:1d" --account pip@meador.me --plain
   ```

   ```bash
   printf 'Cloud Gmail send test\n' | gog gmail send --account pip@meador.me --to sean@meador.me --subject "Pip Cloud Gmail send test" --body-file=-
   ```

Cloud runtime artifacts rendered on the VM:

- `/opt/openclaw/state/runtime/openclaw.json`
- `/opt/openclaw/state/runtime/runtime.env`
- `/opt/openclaw/state/runtime/gog-service-account.json` when Gmail service-account data is present

For normal cloud operation, you should not need to run the manual Gmail bootstrap script if the service-account JSON is present in [config/secrets.cloud.json](/Users/sean/Repos/gcp-claw-lab/config/secrets.cloud.json).

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
- legacy/manual model auth helper
  - [bootstrap-openai-cloud.sh](/Users/sean/Repos/gcp-claw-lab/scripts/models/bootstrap-openai-cloud.sh)
- local shutdown
  - [security-shutdown-local.sh](/Users/sean/Repos/gcp-claw-lab/scripts/security-shutdown-local.sh)

### Gmail testing

Host test:

```bash
printf 'Pip Gmail send test\n' | gog gmail send \
  --account pip@meador.me \
  --to sean@meador.me \
  --subject "Pip Gmail send test" \
  --body-file=-
```

Docker-local test:

```bash
docker compose --env-file /Users/sean/Repos/gcp-claw-lab/config/docker.build.env -f /Users/sean/Repos/gcp-claw-lab/docker/compose.local.yml exec -T openclaw-gateway \
  bash -lc 'printf "Docker gateway Gmail send test\n" | gog gmail send --account pip@meador.me --to sean@meador.me --subject "Pip Docker Gmail send test" --body-file=-'
```

Docker-local read test:

```bash
docker compose --env-file /Users/sean/Repos/gcp-claw-lab/config/docker.build.env -f /Users/sean/Repos/gcp-claw-lab/docker/compose.local.yml exec -T openclaw-gateway \
  gog gmail search "newer_than:1d" --account pip@meador.me --plain
```
