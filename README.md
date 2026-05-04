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
cd /path/to/gcp-claw-lab/opentofu/environments/lab
tofu init
tofu fmt -recursive ../..
tofu validate
tofu plan
tofu apply
```

## Access

After apply, connect with:

```bash
gcloud compute ssh claw-runtime-vm --project your-gcp-project-id --zone us-central1-a --tunnel-through-iap
```

## Setup and Usage

This repo has three operating modes:

- native local: fastest iteration on your laptop
- Docker-local: local cloud-parity runtime
- cloud: Docker on the GCP VM

## Guides

- [OpenClaw Agent Guide](/path/to/gcp-claw-lab/docs/openclaw-agent-guide.md): general lessons and best practices for building reliable agent workflows in OpenClaw
- [Project Spec](/path/to/gcp-claw-lab/docs/spec.md): current architecture, operating model, and constraints for this lab
- [Skill Integration Options](/path/to/gcp-claw-lab/docs/skill-integration-options.md): when to use native OpenClaw skills, repo-managed workspace skills, plugin-shipped skills, or sibling integration repos
- [Backlog](/path/to/gcp-claw-lab/docs/backlog.md): prioritized open work and follow-up improvements

### Dependency management

Pinned runtime versions live in [versions.json](/path/to/gcp-claw-lab/versions.json).

Use:

```bash
cd /path/to/gcp-claw-lab
npm run deps:show
```

That reports:

- pinned repo versions
- installed local `openclaw`
- installed local `gog`
- local Docker / Node / npm / ripgrep versions

Check auto-managed latest versions without editing anything:

```bash
cd /path/to/gcp-claw-lab
npm run deps:check
```

Auto-bump the registry-backed entries in [versions.json](/path/to/gcp-claw-lab/versions.json):

```bash
cd /path/to/gcp-claw-lab
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

After editing [versions.json](/path/to/gcp-claw-lab/versions.json), regenerate derived files with:

```bash
cd /path/to/gcp-claw-lab
npm run deps:sync
npm run deps:lock:function
```

What this updates:

- `config/docker.build.env` for Docker build args
- Cloud Function `package.json` from the central version manifest
- Cloud Function `package-lock.json`

Native-local host tools are still operator-managed. The repo does not auto-upgrade your Homebrew-installed `openclaw`, `gog`, or `ripgrep`.

### Local operator environment with direnv

For operator commands in this repo, the easiest setup is `direnv`.

Install it on macOS with:

```bash
brew install direnv
```

Then hook it into your shell following the `direnv` install instructions for your shell, and in this repo create a local file:

```bash
cd /path/to/gcp-claw-lab
cp .envrc.example .envrc
cat > .envrc.local <<'EOF'
export VM_NAME=claw-runtime-vm
export PROJECT_ID=your-gcp-project-id
export ZONE=us-central1-a
export OPENCLAW_SECRET_NAME=REPLACE_ME
export CLOUD_SECRET_FILE=config/secrets.cloud.json
export GMAIL_TEST_TO=operator@example.com
EOF
direnv allow
```

The repo-managed `.envrc` now:

- loads `.envrc.local` if present
- adds [bin](/path/to/gcp-claw-lab/bin) to `PATH`

So after `direnv allow`, `agent-runtime ...` works directly while you are inside this repo.

`.envrc` and `.envrc.local` are Git-ignored. Use them for operator defaults such as VM/project/zone/secret name, not for runtime secret payloads. Keep runtime secrets in [config/secrets.cloud.json](/path/to/gcp-claw-lab/config/secrets.cloud.json).

### Authentication and secrets

Secrets are split by environment:

- [config/secrets.local.json](/path/to/gcp-claw-lab/config/secrets.local.json)
- [config/secrets.cloud.json](/path/to/gcp-claw-lab/config/secrets.cloud.json)

Start from:

- [config/secrets.local.example.json](/path/to/gcp-claw-lab/config/secrets.local.example.json)
- [config/secrets.cloud.example.json](/path/to/gcp-claw-lab/config/secrets.cloud.example.json)

Rules:

- repo templates under [config](/path/to/gcp-claw-lab/config) are the source of truth for managed behavior
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
  - Gmail service account: store JSON object under `gog.serviceAccounts["your-workflow-account@example.com"]` in `config/secrets.local.json`
  - set the configured workflow account under `gog.account`; the examples use `gmail-workflow@example.com` only as a neutral placeholder
- cloud
  - config secrets come from Secret Manager via `config/secrets.cloud.json` shape
  - provider API key: store under `auth.profiles.<profile>.apiKey` in `config/secrets.cloud.json`
  - OpenRouter is the recommended API-key provider for this repo
  - Gmail service account: store JSON object under `gog.serviceAccounts["your-workflow-account@example.com"]` in `config/secrets.cloud.json`
  - set the configured workflow account under `gog.account`; the examples use `gmail-workflow@example.com` only as a neutral placeholder

Recommended default model/profile:

- auth profile: `openrouter:default`
- provider: `openrouter`
- model: `openrouter/openai/gpt-5.4`

The runtime env renderer will emit `OPENROUTER_API_KEY` automatically when the profile provider is `openrouter`.

Docker-local notes:

- `agent-runtime local prepare` renders:
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
- the cloud host needs `node`, `npm`, Docker, `curl`, and `jq`; the cloud runtime action flow installs those through [scripts/cloud/install-host.sh](/path/to/gcp-claw-lab/scripts/cloud/install-host.sh)

### Native local

Use [config/openclaw.local.example.json5](/path/to/gcp-claw-lab/config/openclaw.local.example.json5) as the basis for `~/.openclaw/openclaw.json`.

Recommended prerequisite:

```bash
brew install ripgrep
```

### Docker-local

Initial setup:

```bash
cd /path/to/gcp-claw-lab
npm run deps:sync
cp config/secrets.local.example.json config/secrets.local.json
agent-runtime local prepare
agent-runtime local deploy
bash ./scripts/maintenance/print-local-docker-access.sh
```

Gateway addresses:

- native local: `http://127.0.0.1:18789`
- Docker-local: `http://127.0.0.1:18790`

Routine operations:

- preferred runtime CLI:
  ```bash
  agent-runtime local deploy
  agent-runtime cloud deploy
  agent-runtime local cron list
  agent-runtime cloud logs-download
  agent-runtime local test basic
  agent-runtime local test core
  agent-runtime local test integration
  agent-runtime local test skill pip-newsletter-digest
  ```
- local Docker command list:
  ```bash
  agent-runtime local help
  ```
- prepare and start the local gateway:
  ```bash
  agent-runtime local deploy
  ```
- restart the local gateway after secret/runtime config changes without rebuilding:
  ```bash
  agent-runtime local restart
  ```
- force a clean local image rebuild and recreate the gateway:
  ```bash
  agent-runtime local rebuild
  ```
- show local Docker status and logs:
  ```bash
  agent-runtime local ps
  agent-runtime local logs
  agent-runtime local agent-logs
  ```
- shell into the Docker-local gateway:
  ```bash
  agent-runtime local shell
  ```
- reset Docker-local state without touching native local:
  ```bash
  bash /path/to/gcp-claw-lab/scripts/maintenance/reset-local-docker.sh
  ```
- local cron config is composed from [workspace/config/cron.local.json](/Users/sean/Repos/gcp-claw-lab/workspace/config/cron.local.json) and disabled by default to avoid duplicate scheduled sends when cloud cron is active:
  ```bash
  agent-runtime local cron apply
  agent-runtime local cron list
  agent-runtime local cron run-digest
  ```
- local Gmail and skill test commands:
  ```bash
  agent-runtime local test gmail-read
  agent-runtime local test gmail-send
  agent-runtime local test skill pip-newsletter-digest
  ```

Optional local overrides:

- `LOCAL_CRON_FILE` to use a cron config file other than `workspace/config/cron.local.json`
- `TAIL_LINES` for `agent-runtime local logs`
- `AGENT_NAME` for `agent-runtime local agent-logs`
- `LOG_VIEW` for `agent-runtime local agent-logs` with `messages`, `replies`, `errors`, or `full`
- `SHOW_RUNTIME_LOG=1` for `agent-runtime local agent-logs` to append the raw runtime log tail
- `GMAIL_TEST_TO` and `GMAIL_TEST_SUBJECT` for `agent-runtime local test gmail-send`
- `SKILL_TEST_MESSAGE` and `SKILL_TEST_TIMEOUT_MS` for `agent-runtime local test skill ...`

### Digest workflow notes

Current Pip newsletter digest shape:

- run on `main` with an isolated session and an explicit reset/fresh-run prompt
- use `gog` for historical pull and issue selection
- use the extractor to turn selected Gmail messages into inspectable artifacts before summarization
- use a deterministic JSON-to-email renderer before send
- use an artifact-backed send helper for final delivery

Extractor artifacts are written per message under:

- [workspace/memory/newsletters](/path/to/gcp-claw-lab/workspace/memory/newsletters)

Each selected message id gets a directory containing:

- `raw.html` when the source message has an HTML body
- `raw.txt`
- `clean.md`
- `links.json`
- `metadata.json`
- `extracted.json`

Normal digest runs should summarize from `clean.md`, `links.json`, and `metadata.json`, not from raw Gmail JSON or raw MIME/HTML payloads.

Final send artifacts are written per run under:

- [workspace/memory/digests](/path/to/gcp-claw-lab/workspace/memory/digests)

Each run writes:

- `digest.json`
- `email.html`
- `email.txt`
- `summary.json`
- `send-result.json`

`digest.json` is now the structured source of truth for the final digest content. The renderer generates `email.html` and `email.txt` deterministically from that JSON so HTML and plaintext stay aligned.

Integration note:

- this runtime repo no longer owns the newsletter implementation scripts
- the newsletter logic now lives in the sibling repo at [`/path/to/agent-newsletter-digest`](/path/to/agent-newsletter-digest)
- this repo stages declared integrations from [workspace/integrations.json](/path/to/gcp-claw-lab/workspace/integrations.json) into a composed runtime view under `.runtime/integrations`
- the reviewed workspace then exposes only the composed skill surface under [workspace/skills](/path/to/gcp-claw-lab/workspace/skills)
- cloud deploys package the sibling integration from the local checkout at deploy time; the VM does not fetch the integration repo from GitHub during deploy
- the Docker image installs the staged integration package and exposes its declared bins on `PATH`
- runtime-specific code should stay generic; workflow-specific commands should come from the integration package itself
- cron follows the same split:
  - [config/cron.example.json](/Users/sean/Repos/gcp-claw-lab/config/cron.example.json) documents the neutral runtime schema
  - real cron jobs for the current workspace live under [workspace/config](/Users/sean/Repos/gcp-claw-lab/workspace/config)
  - the runtime reconciles those files into OpenClaw cron state after the gateway starts; they are not rendered into `openclaw.json`

### Cloud

Cloud container flow:

```bash
cd /path/to/gcp-claw-lab
npm run deps:sync
cp config/secrets.cloud.example.json config/secrets.cloud.json
bash ./scripts/cloud/push-runtime-secret.sh OPENCLAW_SECRET_NAME PROJECT_ID [config/secrets.cloud.json]
bash ./scripts/cloud/sync-app.sh VM_NAME PROJECT_ID ZONE
bash ./scripts/cloud/runtime-action.sh deploy VM_NAME PROJECT_ID ZONE OPENCLAW_SECRET_NAME
```

`agent-runtime cloud deploy` and [scripts/cloud/runtime-action.sh](/path/to/gcp-claw-lab/scripts/cloud/runtime-action.sh) are the normal operator entrypoints. They sync the app, install cloud host prerequisites, render runtime artifacts on the VM, and start the cloud gateway container.

`agent-runtime cloud deploy` stages sibling integrations from the local filesystem before sync, so the cloud image always contains a concrete snapshot of the checked-out integration code used for that deploy.

Convenience commands:

Set these once in your shell for the current session, or load them automatically with `direnv` as described above:

```bash
export VM_NAME=claw-runtime-vm
export PROJECT_ID=your-gcp-project-id
export ZONE=us-central1-a
export OPENCLAW_SECRET_NAME=REPLACE_ME
```

Then use:

```bash
agent-runtime cloud deploy
agent-runtime cloud restart
agent-runtime cloud rebuild
agent-runtime cloud ps
agent-runtime cloud logs
agent-runtime cloud agent-logs
agent-runtime cloud shell
agent-runtime cloud tunnel
agent-runtime cloud cron apply
agent-runtime cloud cron list
agent-runtime cloud cron run-digest
agent-runtime cloud test gmail-read
agent-runtime cloud test gmail-send
agent-runtime cloud test skill pip-newsletter-digest
```

Cloud runtime commands:

```bash
agent-runtime cloud help
agent-runtime cloud push-secret
agent-runtime cloud sync
agent-runtime cloud deploy
agent-runtime cloud restart
agent-runtime cloud rebuild
agent-runtime cloud ps
agent-runtime cloud logs
agent-runtime cloud agent-logs
agent-runtime cloud logs-download
agent-runtime cloud shell
agent-runtime cloud tunnel
agent-runtime cloud cron apply
agent-runtime cloud cron list
agent-runtime cloud cron run-digest
agent-runtime cloud test gmail-read
agent-runtime cloud test gmail-send
```

Optional overrides:

- `CLOUD_SECRET_FILE` to use a secret file other than `config/secrets.cloud.json`
- `CLOUD_CRON_FILE` to use a cron config file other than `workspace/config/cron.cloud.json`
- `TAIL_LINES` for `agent-runtime cloud logs`
- `AGENT_NAME` for `agent-runtime cloud agent-logs`
- `LOG_VIEW` for `agent-runtime cloud agent-logs` with `messages`, `replies`, `errors`, or `full`
- `SHOW_RUNTIME_LOG=1` for `agent-runtime cloud agent-logs` to append the raw runtime log tail
- `GMAIL_TEST_TO` and `GMAIL_TEST_SUBJECT` for `agent-runtime cloud test gmail-send`

Cloud command guidance:

- `agent-runtime cloud deploy`
  - normal safe default
  - syncs app files, installs host prerequisites, renders runtime artifacts, and rebuilds with Docker cache enabled
- `agent-runtime cloud restart`
  - fastest path when only the cloud secret payload or other runtime inputs changed
  - does not rebuild the image
- `agent-runtime cloud rebuild`
  - use when the image seems stale or suspicious, after Dockerfile/runtime build changes, or after odd image-content problems
  - forces a clean `--no-cache` image rebuild before recreating the gateway
  - prunes stale Docker images after a successful rebuild to keep the VM disk from filling up with old build artifacts
- `agent-runtime cloud tunnel`
  - opens a local tunnel to the remote gateway so you can use the browser UI at `http://127.0.0.1:18789/overview`
- `agent-runtime cloud cron apply`
  - reconcile workspace-composed cloud cron jobs into the gateway by name
  - removes duplicate jobs with the same name and updates the surviving job to match config
- `agent-runtime cloud logs-download`
  - downloads cloud OpenClaw session logs locally for inspection/debugging

The neutral cron schema example lives in [config/cron.example.json](/Users/sean/Repos/gcp-claw-lab/config/cron.example.json). The concrete cloud composition file lives in [workspace/config/cron.cloud.json](/Users/sean/Repos/gcp-claw-lab/workspace/config/cron.cloud.json).

Local Docker command guidance:

- `agent-runtime local deploy`
  - normal local operator entrypoint
  - renders runtime artifacts, builds with Docker cache enabled, seeds writable state paths, starts the local gateway, and reconciles local cron config
- `agent-runtime local restart`
  - fastest path when only local secret payloads or runtime-rendered config changed
  - does not rebuild the image
- `agent-runtime local rebuild`
  - use when the local image seems stale or suspicious, after Dockerfile/runtime build changes, or after odd image-content problems
  - forces a clean `--no-cache` image rebuild before recreating the gateway
  - prunes stale Docker images after a successful rebuild to keep local Docker storage from filling up with old build artifacts
- `agent-runtime local cron apply`
  - reconcile workspace-composed local cron jobs into the gateway by name
  - local cron is disabled by default in [workspace/config/cron.local.json](/Users/sean/Repos/gcp-claw-lab/workspace/config/cron.local.json) to avoid duplicate scheduled sends

Cloud secret setup:

1. Create [config/secrets.cloud.json](/path/to/gcp-claw-lab/config/secrets.cloud.json) from the example:

   ```bash
   cd /path/to/gcp-claw-lab
   cp config/secrets.cloud.example.json config/secrets.cloud.json
   ```

2. Fill in the fields you need for the first cloud run:
   - `gateway.auth.token`
   - `auth.profiles.openrouter:default.apiKey`
   - `gog.serviceAccounts["your-workflow-account@example.com"]`
   - `gog.account`
   - keep `hooks.enabled` set to `false` unless you are explicitly setting up cloud Gmail hooks

3. Push the secret payload to Secret Manager:

   ```bash
   cd /path/to/gcp-claw-lab
   bash ./scripts/cloud/push-runtime-secret.sh OPENCLAW_SECRET_NAME PROJECT_ID config/secrets.cloud.json
   ```

4. Deploy the cloud runtime:

   ```bash
   cd /path/to/gcp-claw-lab
   npm run deps:sync
   bash ./scripts/cloud/runtime-action.sh deploy VM_NAME PROJECT_ID ZONE OPENCLAW_SECRET_NAME
   ```

5. Verify cloud Gmail read/send through the runtime CLI:

   ```bash
   agent-runtime cloud test gmail-read
   agent-runtime cloud test gmail-send
   ```

   If you need to inspect the gateway manually:

   ```bash
   agent-runtime cloud shell
   ```

   Then use the configured runtime account:

   ```bash
   gog gmail search "newer_than:1d" --account "$GOG_ACCOUNT" --plain
   ```

   ```bash
   printf 'Cloud Gmail send test\n' | gog gmail send --account "$GOG_ACCOUNT" --to "${GMAIL_TEST_TO:-operator@example.com}" --subject "${GMAIL_TEST_SUBJECT:-Pip Cloud Gmail send test}" --body-file=-
   ```

Cloud runtime artifacts rendered on the VM:

- `/opt/openclaw/state/runtime/openclaw.json`
- `/opt/openclaw/state/runtime/runtime.env`
- `/opt/openclaw/state/runtime/gog-service-account.json` when Gmail service-account data is present

For normal cloud operation, you should not need to run the manual Gmail bootstrap script if the service-account JSON is present in [config/secrets.cloud.json](/path/to/gcp-claw-lab/config/secrets.cloud.json).

Shell into the cloud gateway:

```bash
agent-runtime cloud shell
```

### Setup scripts

Primary scripts:

- local Docker
  - [lifecycle.sh](/path/to/gcp-claw-lab/scripts/runtime/lifecycle.sh)
  - [cron.sh](/path/to/gcp-claw-lab/scripts/runtime/cron.sh)
  - [reset-local-docker.sh](/path/to/gcp-claw-lab/scripts/maintenance/reset-local-docker.sh)
  - [print-local-docker-access.sh](/path/to/gcp-claw-lab/scripts/maintenance/print-local-docker-access.sh)
- cloud
  - [push-runtime-secret.sh](/path/to/gcp-claw-lab/scripts/cloud/push-runtime-secret.sh)
  - [sync-app.sh](/path/to/gcp-claw-lab/scripts/cloud/sync-app.sh)
  - [runtime-action.sh](/path/to/gcp-claw-lab/scripts/cloud/runtime-action.sh)
  - [ssh-app.sh](/path/to/gcp-claw-lab/scripts/cloud/ssh-app.sh)

Supporting scripts:

- Gmail service-account bootstrap
  - [bootstrap-gog-docker-local.sh](/path/to/gcp-claw-lab/scripts/gmail/bootstrap-gog-docker-local.sh)
  - [bootstrap-gog-cloud-service-account.sh](/path/to/gcp-claw-lab/scripts/gmail/bootstrap-gog-cloud-service-account.sh)
- legacy/manual model auth helper
  - [bootstrap-openai-cloud.sh](/path/to/gcp-claw-lab/scripts/models/bootstrap-openai-cloud.sh)
- local shutdown
  - [security-shutdown-local.sh](/path/to/gcp-claw-lab/scripts/maintenance/security-shutdown-local.sh)

### Gmail testing

Prefer the runtime CLI:

```bash
agent-runtime local test gmail-read
agent-runtime local test gmail-send
agent-runtime cloud test gmail-read
agent-runtime cloud test gmail-send
```

Host test:

```bash
printf 'Pip Gmail send test\n' | gog gmail send \
  --account "${GOG_ACCOUNT:-your-workflow-account@example.com}" \
  --to "${GMAIL_TEST_TO:-operator@example.com}" \
  --subject "${GMAIL_TEST_SUBJECT:-Pip Gmail send test}" \
  --body-file=-
```

Docker-local test:

```bash
docker compose --env-file /path/to/gcp-claw-lab/config/docker.build.env -f /path/to/gcp-claw-lab/docker/compose.local.yml exec -T openclaw-gateway \
  bash -lc 'printf "Docker gateway Gmail send test\n" | gog gmail send --account "$GOG_ACCOUNT" --to "${GMAIL_TEST_TO:-operator@example.com}" --subject "${GMAIL_TEST_SUBJECT:-Pip Docker Gmail send test}" --body-file=-'
```

Docker-local read test:

```bash
docker compose --env-file /path/to/gcp-claw-lab/config/docker.build.env -f /path/to/gcp-claw-lab/docker/compose.local.yml exec -T openclaw-gateway \
  bash -lc 'gog gmail search "newer_than:1d" --account "$GOG_ACCOUNT" --plain'
```
