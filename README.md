# Agent Lab GCP Infrastructure

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
gcloud compute ssh agent-lab-vm --project agent-lab-488918 --zone us-central1-a --tunnel-through-iap
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

## Docker Workflow

Local Docker parity check:

```bash
cd /Users/sean/Repos/gcp-claw-lab
cp config/secrets.local.json.example config/secrets.local.json
./scripts/onboard-local-container.sh
./scripts/run-local.sh
```

Cloud VM container flow:

```bash
cd /Users/sean/Repos/gcp-claw-lab
./scripts/onboard-cloud-container.sh OPENCLAW_CONFIG_SECRET_NAME
./scripts/run-cloud.sh OPENCLAW_CONFIG_SECRET_NAME
```

Notes:
- local Docker uses named volumes for `~/.openclaw` and `workspace/.openclaw`
- cloud Docker persists runtime state under `/opt/openclaw/state`
- both container flows mount the reviewed repository workspace read-only
- container startup treats the rendered config as authoritative for managed fields and preserves runtime metadata in persisted state
- rendered config is the right place for `gateway.auth` and other config-bound secrets
- provider auth is established inside each environment and persists in runtime state under `~/.openclaw` or `/opt/openclaw/state/home`
- redeploying a container preserves provider auth only if the persistent state path or volume is preserved
- persisted runtime state should be treated as sensitive because it may contain live provider credentials

Cloud secret payload shape:
- the GCP secret should contain a JSON object shaped like [secrets.local.json.example](/Users/sean/Repos/gcp-claw-lab/config/secrets.local.json.example)
- the payload contract is documented in [openclaw.runtime-secrets.schema.json](/Users/sean/Repos/gcp-claw-lab/config/openclaw.runtime-secrets.schema.json)
- that JSON is merged into [openclaw.cloud.json5.example](/Users/sean/Repos/gcp-claw-lab/config/openclaw.cloud.json5.example) to produce `/opt/openclaw/state/runtime/openclaw.json`
