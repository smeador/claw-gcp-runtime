# OpenClaw GCP Runtime

This repo is an OpenClaw runtime and command set that works across local containers and Google Cloud (GCP).

It does three things:

- provisions the GCP infrastructure with OpenTofu
- manages the local and cloud OpenClaw runtime lifecycle
- composes sibling workflow/skill integrations into a reviewed workspace

The main active integration today is the sibling `newsletter-digest` repo.

## When To Use

Use this repo if you want:

- a Docker-local and Google Cloud OpenClaw runtime
- a simple runtime CLI for both local and cloud operations
- a declarative configuration system for managing OpenClaw setup
- a place to compose reviewed workspace skills and config from sibling repos

This repo focuses on providing a generic runtime. Specific workflows and agent usage can be composed from sibling repos or built directly in the workspace by forking this repo.

## Runtime Design

This runtime is designed so the important OpenClaw configuration stays defined in the repo, then gets rendered and composed at runtime for the target environment.

That means:

- repo-managed templates define the intended OpenClaw config, runtime behavior, and integration surface
- local and cloud secrets stay outside git, then get rendered into runtime artifacts at deploy time
- the live runtime is rebuilt from those repo-managed inputs, which makes configuration easier to inspect, change, and reproduce

This model is meant to improve both configurability and durability:

- configurability, because local and cloud behavior are controlled through clear repo inputs (in contrast to ad hoc setup)
- durability, because the runtime can be recreated from versioned config and staged integrations rather than depending on hand-edited machine state

## Supported Features

- provider auth and runtime secret rendering
- channel configuration, including Telegram
- `gog` bootstrap and Gmail workflow auth
- staged sibling integrations and reviewed workspace composition

## Repo Layout

- [`opentofu/`](opentofu): GCP infrastructure
- [`config/`](config): runtime templates, example secrets, rendered local config
- [`docker/`](docker): Docker image and compose files
- [`scripts/`](scripts): runtime, cloud, Gmail, and maintenance helpers
- [`workspace/`](workspace): reviewed composed workspace surface
- [`docs/`](docs): detailed architecture, troubleshooting, and backlog docs

## About the Workspace

`workspace/` is the user's OpenClaw workspace for this runtime. It is where reviewed runtime-facing files such as workspace policy, composed skills, cron config, and integration-owned config come together.

In the open source repo, the checked-in workspace files are intentionally generic placeholders:

- identity and persona files such as [`workspace/IDENTITY.md`](workspace/IDENTITY.md), [`workspace/SOUL.md`](workspace/SOUL.md), and [`workspace/USER.md`](workspace/USER.md) are starter templates
- [`workspace/AGENTS.md`](workspace/AGENTS.md) and [`workspace/TOOLS.md`](workspace/TOOLS.md) define the reviewed workspace policy surface
- [`workspace/skills`](workspace/skills) and some files under [`workspace/config`](workspace/config) are generated or composed during staging

In a real setup, you would typically fork this repo and update the checked-in workspace files to match your own OpenClaw usage, tone, workflows, and reviewed integrations.

## Prerequisites

- OpenTofu
- Google Cloud CLI (`gcloud`)
- Docker Desktop or OrbStack
- Node.js 22+
- `direnv` is recommended but optional

## Quick Start

### 1. Set up Google Cloud

You will need:

- a Google Cloud account
- a Google Cloud project
- billing enabled on that project
- Google Cloud CLI auth for that project

This repo's OpenTofu config creates the lab VM for you. You do not need to create the instance manually first.

If you are starting from scratch, Google’s setup docs are the right first stop:

- [Google Cloud setup guide](https://cloud.google.com/docs/get-started)
- [Compute Engine documentation](https://cloud.google.com/compute/docs)

Authenticate and select your project first:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project YOUR_PROJECT_ID
```

### 2. Provision GCP with this repo

```bash
cd opentofu/environments/lab
cp backend.gcs.hcl.example backend.gcs.hcl
cp terraform.tfvars.example terraform.tfvars
tofu init -backend-config=backend.gcs.hcl
tofu validate
tofu plan
tofu apply
```

Notes:
- OpenTofu and the Google provider use your local Google auth. You should not need to paste service-account keys into this repo just to provision infrastructure.
- This environment uses a GCS backend for OpenTofu state in [providers.tf](opentofu/environments/lab/providers.tf), so the backend bucket must already exist and your authenticated identity must be able to read and write it before `tofu init`.
- Use [`backend.gcs.hcl.example`](opentofu/environments/lab/backend.gcs.hcl.example) and your ignored local [`terraform.tfvars`](opentofu/environments/lab/terraform.tfvars) as the place for your deployment-specific bucket and naming choices.
- Detailed infrastructure and security notes live in [spec.md](docs/spec.md).

### 3. Start Local Docker Runtime

```bash
npm run deps:sync
install -m 600 config/secrets.local.example.json config/secrets.local.json
claw-runtime local deploy
```

### 4. Start Cloud Runtime

Set your operator env first, either in your shell or with `direnv`:

```bash
export VM_NAME=claw-runtime-vm
export PROJECT_ID=your-gcp-project-id
export ZONE=us-central1-a
export OPENCLAW_SECRET_NAME=your-secret-name
export CLOUD_SECRET_FILE=config/secrets.cloud.json
```

Then:

```bash
npm run deps:sync
install -m 600 config/secrets.cloud.example.json config/secrets.cloud.json
claw-runtime cloud push-secret
claw-runtime cloud deploy
```

## Common Commands

`claw-runtime` is the unified runtime CLI for this repo. It exists so local and cloud workflows use the same verbs and so the operational surface stays smaller than the underlying script set.

The executable lives under [`bin/claw-runtime`](bin/claw-runtime). With `direnv` enabled in this repo, you can just run `claw-runtime ...` directly. Without `direnv`, use `./bin/claw-runtime ...`.

Local:

```bash
claw-runtime local help
claw-runtime local deploy
claw-runtime local restart
claw-runtime local logs
claw-runtime local shell
claw-runtime local cron list
claw-runtime local test basic
claw-runtime local test core
claw-runtime local test integration
claw-runtime local test skill newsletter-digest
claw-runtime local test gmail-read
claw-runtime local test gmail-send
```

Cloud:

```bash
claw-runtime cloud help
claw-runtime cloud deploy
# ...same commands as local...
claw-runtime cloud tunnel
```

For the full command surface, run:

```bash
claw-runtime local help
claw-runtime cloud help
```

## Integrations

To keep generic runtime and specific workflows separate, this repo provides an integration technique for composing these specific workflows and skills from a sibling repo. This is an optional technique to aid in composability, and an alternative approach is to implement your workflows directly in a fork of this repo.

Sibling integrations are declared in [`workspace/integrations.json`](workspace/integrations.json).

The runtime stages them into:

- [`.runtime/integrations`](.runtime/integrations)

and then composes their reviewed workspace surface into:

- [`workspace/skills`](workspace/skills)
- [`workspace/config`](workspace/config)

Cloud deploys package the staged integration snapshot from your local checkout. The VM does not fetch sibling repos directly during deploy.

## Secrets and Auth

Start from:

- [`config/secrets.local.example.json`](config/secrets.local.example.json)
- [`config/secrets.cloud.example.json`](config/secrets.cloud.example.json)

Use:

- [`config/secrets.local.json`](config/secrets.local.json) for Docker-local secrets
- [`config/secrets.cloud.json`](config/secrets.cloud.json) for cloud secrets

Create real secret files with mode `0600`:

```bash
install -m 600 config/secrets.local.example.json config/secrets.local.json
install -m 600 config/secrets.cloud.example.json config/secrets.cloud.json
```

Current defaults:

- provider: OpenRouter
- model: `openrouter/openai/gpt-5.4`
- Gmail workflow account comes from `gog.account`

The runtime handles rendering and bootstrapping of:

- `openclaw.json`
- runtime env
- Gmail service-account key material when configured

Manual Gmail bootstrap scripts still exist for recovery, but they are not the normal setup path.

## Docs

Current source-of-truth docs:

- [spec.md](docs/spec.md): current architecture, security posture, setup model, and runtime conventions
- [runtime-operations.md](docs/runtime-operations.md): detailed local/cloud runtime commands, secret setup, and operator runbook
- [openclaw-agent-guide.md](docs/openclaw-agent-guide.md): operational lessons, troubleshooting guidance, and OpenClaw-specific heuristics
- [skill-integration-options.md](docs/skill-integration-options.md): when to use built-in skills, generated workspace skills, plugins, or sibling integrations
- [backlog.md](docs/backlog.md): prioritized follow-up work

## Notes

- `workspace/skills` and some integration-owned files under `workspace/config` are generated during staging and should be treated as composed state.
- Local cron is disabled by default to avoid duplicate sends when cloud cron is active.
- This repo is for a single-user lab, not a multi-tenant production platform.
