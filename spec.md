# Claw Runtime GCP Infrastructure & Security Spec

## Overview

This project provisions a secure, isolated experimentation environment on Google Cloud Platform (GCP) for running OpenClaw (or equivalent agent runtime) using OpenTofu.

Open backlog items live in [backlog.md](/Users/sean/Repos/gcp-claw-lab/backlog.md). This spec describes the current intended architecture, operating model, and constraints.

Primary goals:

1. Isolate agent runtime from personal laptop
2. Follow GCP security best practices
3. Prevent secrets from leaking into OpenTofu state
4. Maintain strict least-privilege IAM
5. Enable controlled experimentation with web scraping + productivity workflows
6. Enforce cost controls from day one

This is a **single-user lab environment**, not a production multi-tenant deployment.

---

# Architecture

## High-Level Design

### Runtime Path

Laptop
  ↓
Local OpenClaw workspace and local test runtime
  ↓
IAP TCP Tunnel
  ↓
Private GCP VPC
  ↓
Compute Engine VM (no external IP)
  ↓
Cloud NAT (outbound internet only)
  ↓
Secret Manager
  ↓
OpenClaw runtime

### Control Path

Cloud Billing budget
  ↓
Budget Pub/Sub notifications
  ↓
Cloud Run shutdown function
  ↓
Compute Engine API
  ↓
Claw Runtime VM stop operation

No public inbound ports.
No SSH exposed to internet.
No external IP assigned to VM.

---

# Infrastructure Components

## 1. Networking

- Dedicated VPC: `agent-lab-vpc`
- Dedicated subnet: `agent-lab-subnet`
- Private Google Access enabled
- Cloud Router
- Cloud NAT for outbound internet access
- Explicit egress policy required:
    - Cloud NAT provides outbound connectivity, not egress filtering
    - Avoid relying on the implied allow-egress rule as the security boundary
    - Prefer deny-by-default egress with explicit allow rules where feasible
    - Enable firewall logging for any nontrivial egress allow rules
- Firewall rule:
    - Allow TCP:22
    - Source range: 35.235.240.0/20 (IAP TCP forwarding range)
    - Target tag: agent-lab-iap-ssh
- No public ingress rules
- No external IPs permitted by project policy unless explicitly exempted

## 2. Compute

- Compute Engine VM
- No external IP
- Shielded VM enabled:
    - vTPM enabled
    - Integrity Monitoring enabled
- Secure Boot enabled (if compatible)
- OS Login enabled
- Serial port access disabled
- Dedicated service account:
    - No default service account
    - No broad project roles
    - Only required roles:
        - Secret Manager Secret Accessor (scoped to specific secrets)
        - Logging/Monitoring minimal roles if required
        - Prefer `roles/logging.logWriter` and `roles/monitoring.metricWriter` only when telemetry agents are installed

Machine type: small (e2-small or e2-medium initially)
Region: configurable (default: us-central1)

## 3. Cost Control Automation

- Cloud Billing budget with alert thresholds
- Pub/Sub topic for budget notifications
- Cloud Run shutdown function subscribed to the budget topic
- Function stops the Claw Runtime VM when actual spend exceeds the configured budget threshold notification

Budget automation is intended to stop the VM, not disable billing for the entire project.

## 4. Secrets

Use Google Cloud Secret Manager.

OpenTofu will:
- Create secret containers (metadata only)
- Assign IAM permissions to VM service account

OpenTofu will NOT:
- Store secret payloads
- Create secret versions with secret_data

Secrets are injected via gcloud CLI or bootstrap script.
Secret access should be granted at the individual secret resource level, not with broad project-wide secret access.

Secrets include:
- LLM API key
- Gmail Workspace service-account material for `automation@example.com`
- Calendar token (if separate)
- Any scraping API credentials

---

# Secret Injection Model

## Rationale

OpenTofu state must not contain secret payloads.

We follow this pattern:

1. OpenTofu creates secret containers.
2. IAM binding grants VM SA access.
3. Secret payload added out-of-band using:

   gcloud secrets versions add SECRET_NAME --data-file=-

Secrets are versioned.
Application should prefer an approved version number or controlled alias rather than implicitly reading `latest`.

## Runtime Access

At VM startup:
- Wrapper script retrieves required secrets via gcloud
- Writes secrets to a root-owned memory-backed file or other narrow handoff mechanism where possible
- Uses environment variable injection only when the application cannot avoid it
- Starts OpenClaw

Secrets are resolved on application startup.
Restart required to pick up updated secrets.
Old secret versions should be disabled before destruction when rotating credentials.

---

# Access Model

## SSH Access

Use IAP TCP forwarding:

gcloud compute ssh VM_NAME --tunnel-through-iap

Requirements:
- OS Login enforced
- User has roles/iap.tunnelResourceAccessor
- User has compute.osLogin or equivalent IAM
- Optional: require OS Login 2FA for human administrators

No SSH keys stored in metadata.
Project and instance metadata-based SSH keys should remain disabled.
SSH-in-browser should be disabled unless there is an operational need for it.

---

# Cost Controls

## 1. Budget Alerts

Create billing budget:
- 50% threshold
- 80% threshold
- 100% threshold

Email notifications enabled.
Pub/Sub notifications enabled.

## 1a. Automated Shutdown

Implement automated cost response:
- Billing budget publishes to Pub/Sub
- Pub/Sub triggers a Cloud Run shutdown function
- Shutdown function stops `claw-runtime-vm`

Constraints:
- Budget alerts are not a hard billing cap and may arrive after some delay
- The automation should stop the VM rather than disable billing for the project
- Quotas remain in place as a second control for accidental scale-out

## 2. Billing Export

Export billing data to BigQuery dataset for inspection.

## 3. Quotas

Limit:
- Max CPUs
- Max instances

## 4. Operational Discipline

VM should be stopped when not actively experimenting.

---

# Security Posture

## Agent Risk Model

OpenClaw is treated as:

- Tool-using autonomous runtime
- Executes instructions derived from external content

## Operational Learning

- For the Pip newsletter digest, the current reliable shape is: run on the `main` agent with an isolated session and an explicit reset/fresh-run prompt.
- A dedicated `digest` agent was attempted as a cost-control measure, but config-only registration was not enough in practice. The runtime rendered `agents.list`, but the live gateway still rejected `digest` as an unknown agent id.
- Digest reliability improved once raw Gmail JSON and raw HTML stopped being passed directly into the model conversation. The current pattern is: `gog` search/select -> extractor artifacts -> formatter -> artifact-backed send helper.
- The extractor should be treated as the source of truth for message-body cleanup. `clean.md`, `links.json`, and `metadata.json` are the normal model-facing inputs; `raw.html` and `raw.txt` are for inspection/debugging only.
- Native local, Docker-local, and cloud should all call the digest extractor and digest send helper through workspace-local wrapper scripts so the skill does not depend on environment-specific binary/script paths.
- Digest send success should be code-enforced instead of instruction-enforced: the helper writes final run artifacts, executes `gog gmail send`, and only reports success when a Gmail id is returned.
- Holds durable delegated credentials

Therefore:

- Runs in isolated private VM
- No unreviewed extension surface initially
- No exec permissions unless explicitly enabled
- Least privilege OAuth scopes
- Dedicated agent email account recommended
- Treat outbound network access as a data exfiltration path and constrain it accordingly

## Scraping Guidelines

- Prefer APIs or permitted endpoints
- Respect robots.txt where applicable
- Implement rate limiting
- Avoid bot-detection bypass techniques

---

# OpenTofu Structure

## OpenTofu State Security

OpenTofu state must be stored remotely in a locked-down GCS backend.

Requirements:
- Use a dedicated state bucket
- Enable bucket versioning
- Enforce public access prevention
- Enable uniform bucket-level access
- Grant minimal bucket IAM access
- Do not commit local state files
- Review `tofu plan` before apply

Recommended guardrails:
- Prevent service account key creation where possible
- Prevent automatic broad grants to default service accounts
- Use project or organization policies to deny VM external IPs by default

Recommended layout:
/opentofu
/modules
/network
/compute
/secrets
/iam
/environments
/lab
main.tf
variables.tf
outputs.tf

Modules:

network:
  - VPC
  - Subnet
  - Router
  - NAT
  - Firewall

compute:
  - VM
  - Service Account
  - Shielded config
  - Metadata (OS Login)
  - Serial port disablement

cost_controls:
  - Pub/Sub topic for budget notifications
  - Cloud Run shutdown function
  - Function source packaging
  - Narrow IAM for VM stop permissions

secrets:
  - Secret containers
  - IAM bindings

iam:
  - IAP roles
  - OS Login roles
  - Org/project policy guardrails

---

# OpenClaw Deployment Strategy

## Development Model

Follow a local-first, cloud-parity workflow:
- Develop and test OpenClaw behavior locally first
- Keep local and cloud runtime inputs as similar as practical
- Use Docker as the cloud deployment target
- Keep the workspace and reviewed policy/configuration in the repository so local and cloud runs use the same source of truth

Local development:
- Prefer a local OpenClaw runtime for the fastest iteration loop
- Keep the active workspace in the repository
- Keep the local gateway bound to loopback only unless there is an explicit need for remote exposure
- Do not enable Tailscale or tailnet exposure initially

Cloud deployment:
- Run OpenClaw in Docker on the VM
- Mount the same reviewed workspace/configuration used for local development
- Fetch secrets on the VM at startup and inject them into the container runtime
- Keep the container image generic and keep agent behavior in mounted config and workspace files

Initial deployment:
- Docker container recommended
- Dedicated Linux user: openclaw
- Secrets fetched at container startup
- Container should run as a non-root user where possible
- Root filesystem should be read-only where practical
- Use only the minimum filesystem mounts required for the runtime

Do NOT:
- Mount entire filesystem
- Grant broad shell execution
- Add unreviewed extensions initially

## OpenClaw Runtime Configuration

OpenClaw configuration should be split between version-controlled non-secret files and Secret Manager-backed runtime secrets.

Configuration ownership model:
- Repository config templates define the canonical managed behavior
- The live local-native runtime is still driven from `~/.openclaw/openclaw.json`
- Container runtimes keep persisted state in their runtime volume/path, not in Git
- Runtime-managed fields such as onboarding metadata, auth state, and generated tokens are not the repository source of truth
- Container runtimes should consume an authoritative rendered config file derived from the repo template plus environment-specific secrets

Secret ownership model:
- A single JSON secret payload is used for OpenClaw runtime config secrets
- That payload currently contains `auth`, `gateway.auth`, optional channel secrets, and optional hook configuration such as `hooks.gmail`
- The payload is merged into the environment-specific OpenClaw template at render time
- The payload contract should be documented in the repository and treated as a security-sensitive interface
- Local and cloud environments should use separate secret payload files even when they share the same schema
- Platform identity such as the VM service account is not stored in the OpenClaw runtime secret payload
- The payload may include a `gog` branch for `automation@example.com`; that branch should render to separate Gmail bootstrap artifacts rather than appearing in rendered `openclaw.json`.
- Browser/session state and other runtime artifacts are persisted separately from the config secret payload
- `gateway.auth` should be treated as a rendered config secret
- Provider auth may also persist in OpenClaw runtime state files and should be treated as sensitive environment-local state
- `auth.profiles` in the config payload should define provider/profile metadata; for Docker-local and cloud, an `api_key` profile may additionally carry a raw `apiKey` in the environment secret overlay so bootstrap can emit a runtime env file while stripping the raw token out of the rendered config

Version control in Git:
- OpenClaw base configuration
- Reviewed workspace policy and instructions
- Container or systemd definitions
- Bootstrap and config-rendering scripts

Do not store in Git:
- API keys
- OAuth access or refresh tokens
- Secret payloads
- Live `.env` files
- Logs, caches, or session artifacts
- Rendered runtime config containing secrets

Recommended runtime layout on the VM:
- `/opt/openclaw/app/`
- `/opt/openclaw/config/`
- `/opt/openclaw/agents/`
- `/opt/openclaw/scripts/`
- `/opt/openclaw/logs/`
- `/opt/openclaw/state/home/`
- `/opt/openclaw/state/runtime/`
- `/opt/openclaw/state/workspace/`
- `/opt/openclaw/state/memory/`

Filesystem requirements for persisted runtime state:
- State paths must be owned by the dedicated `openclaw` user
- State paths should not be world-readable
- `/opt/openclaw/state/home/` should be treated as sensitive because it may contain live provider auth state
- `/opt/openclaw/state/runtime/` should be treated as sensitive because it contains rendered runtime config with secrets
- `/opt/openclaw/state/memory/` should be treated as sensitive because it contains persisted learned context
- OpenClaw agent/session subpaths created under persisted state must also remain owned by the runtime user so lockfiles and session metadata can be written during chat, onboarding, and device approval flows

Recommended repository layout:
- `/opentofu/`
- `/workspace/`
- `/config/`
- `/docker/`
- `/scripts/`

Recommended local gateway defaults:
- Bind mode: `loopback`
- Port: `18789`
- Shared auth enabled if the gateway is ever exposed beyond loopback
- No initial Tailscale or tailnet exposure

Recommended local Docker parity defaults:
- Internal gateway port: `18789`
- Host-published Docker-local gateway: `127.0.0.1:18790`
- Allowed Control UI origins: `http://127.0.0.1:18790` and `http://localhost:18790`
- Docker-local gateway state is separate from native local gateway state and should be treated as a distinct environment for provider auth and device pairing
- A repo-local Docker bootstrap step should render config, build images, seed state directories, and fix ownership before runtime start
- Hardened runtime containers should keep `/workspace` and `/runtime` read-only and use dedicated writable state mounts instead
- Required writable Docker-local state paths are `/home/node/.openclaw`, `/workspace/.openclaw`, and `/workspace/memory`
- A separate root-owned dev container may share the same state volumes for manual editing/debugging without loosening the runtime gateway container

Container runtime constraints:
- OpenClaw should not attempt to install or manage host daemons from inside the application container
- `systemd`, `launchd`, and similar host init integrations are not expected to be available inside Docker-local or Docker-cloud runtime containers
- Docker restart policy or host-level service management should be used for container lifecycle, not OpenClaw daemon installation inside the container
- Hook or service flows that assume host init availability should be skipped or handled outside the application container

Container operations guidance:
- Treat runtime onboarding as a bootstrap/recovery path, not a routine operational workflow
- Routine provider changes should use the environment-appropriate auth path:
  - native local may use targeted model auth commands such as `openclaw models auth login --provider openai`
  - Docker-local API-key providers should prefer env-based injection derived from the local secret overlay
  - interactive bootstrap should be reserved for auth flows that cannot be expressed as static secret input
- Routine gateway token rotation should happen by updating the environment-specific secret payload and restarting or redeploying the gateway
- Routine runtime behavior changes should happen in reviewed repository files and then be applied via local restart or cloud redeploy
- Device pairing for the dashboard is environment-local and must be approved against the same runtime environment that owns the gateway state
- Routine container administration should prefer shelling into the running `openclaw-gateway` container and running OpenClaw commands there, rather than relying on long one-off `docker compose ... run` invocations
- Telegram pairing should use the explicit pairing commands for that channel, e.g. `openclaw pairing list telegram` and `openclaw pairing approve telegram <CODE>`
- `boot-md` should be explicitly disabled in repo-managed templates unless there is a reviewed startup-automation need for it
- Provider auth established inside Docker should persist in the Docker-local or cloud state path across normal container redeploys, but not across state deletion
- Docker-local bootstrap should follow the upstream `docker-setup.sh` pattern conceptually while preserving the repository's local-first, shared-workspace, rendered-config model

Scheduling guidance:
- OpenClaw recurring jobs may run inside the long-lived gateway process if the gateway scheduler/cron features are enabled
- Containerized scheduling does not require `systemd` inside the application container
- Host-level schedulers such as `systemd` timers or cron may still be used outside the container for infrastructure lifecycle tasks
- The preferred model is Docker managing the service lifecycle and OpenClaw managing agent-native recurring work

Cloud deployment guidance:
- The VM should keep a synced application bundle under `/opt/openclaw/app`
- Docker should be installed on the VM host and managed by the host OS, not by OpenClaw inside the application container
- The cloud runtime secret should live in Secret Manager as a single JSON payload and be rendered on the VM host into `/opt/openclaw/state/runtime/openclaw.json`
- The VM service account should receive secret-level access only to the OpenClaw runtime secret
- Cloud container deploys should update repo-managed workspace/config files while preserving `/opt/openclaw/state/{home,workspace,memory}`

Recommended workflow:
1. Update reviewed configuration in Git.
2. Keep the live local-native config in `~/.openclaw` aligned with the repository template for managed fields.
3. Test the change locally against the repository workspace.
4. Smoke test cloud-parity container behavior locally when needed.
5. Render local or cloud runtime config from the repo template plus the appropriate secret source.
6. For local Docker, use a Git-ignored local secret file with the same payload shape as cloud.
7. For cloud Docker, fetch the single JSON secret payload from Secret Manager at startup and render both `openclaw.json` and any required runtime env/bootstrap artifacts on the VM host.
8. Deploy or sync configuration to the VM.
9. Start or restart the OpenClaw service.

Dependency/version workflow:
- Repository-pinned runtime versions should live in a single checked-in manifest.
- Docker build args for local and cloud should be rendered from that manifest rather than hardcoded ad hoc in shell scripts.
- Node/Cloud Function dependencies should be pinned exactly and accompanied by a lockfile.
- Routine dependency updates should follow:
  1. edit the central version manifest
  2. regenerate derived build files and package manifests
  3. refresh lockfiles
  4. rebuild/test locally

Authentication guidance by environment:
- Native local should prefer direct interactive OAuth/provider login when that is the cleanest local operator workflow.
- Docker-local and cloud should prefer non-interactive auth for server-style integrations where possible.
- Native-local runtime state must not be treated as an implicit config source for Docker-local or cloud.
- Gmail for Docker-local and cloud should prefer Google Workspace service-account auth with domain-wide delegation for `automation@example.com`.
- OpenAI for Docker-local and cloud should prefer env-based API-key injection rendered from the environment secret overlay rather than interactive runtime bootstrap.
- Gmail for native local may continue using user OAuth if that remains the simplest local-native operator path.
- Docker-local digest/read-send workflows should not require Gmail Pub/Sub, webhook setup, or Tailscale Funnel.
- OpenAI/model auth should keep the same profile names across environments.
- Native local may use OAuth or other local runtime-managed auth when that is the cleaner operator path.
- Docker-local may derive API-key provider secrets from the same local secret overlay used for config rendering, but the rendered config should omit the raw key and rely on the injected provider env var.
- Cloud may derive API-key provider secrets from the cloud secret overlay into a VM-rendered runtime env file, while keeping native-local auth state separate.

Messaging platform guidance:
- Start with Telegram as the first and only messaging platform for phase 1
- Use a token-based Telegram bot instead of a QR-paired channel for the initial rollout
- Keep Telegram limited to DM pairing first and leave group access disabled
- Keep channel-driven config writes disabled so the live instance cannot mutate reviewed repository behavior through the messaging surface
- Add the bot token through the environment-specific secret payload under `channels.telegram.botToken`
- Treat Telegram DM pairing state under `~/.openclaw/credentials/` as distinct from node device pairing state under `~/.openclaw/devices/`
- Persist both pairing stores with the rest of `~/.openclaw` across normal container redeploys

Operational guidance:
- Git is the source of truth for non-secret configuration
- Secret Manager is the source of truth for secret material
- The VM should hold only rendered runtime state
- Runtime-managed config fields should persist locally or in container state, but should not replace the repo-managed template as the source of truth
- Local Docker should use a Git-ignored local secret file for parity testing rather than storing important credentials only in container state
- Local Docker may use that same Git-ignored local secret file to carry `gog` service-account bootstrap material for `automation@example.com`, but that material should render to a separate bootstrap file rather than appearing in `openclaw.json`
- OpenClaw config secrets should be rendered to a private runtime file and mounted read-only into the container
- Environment variables may still be used for narrowly scoped bootstrap logic, but the preferred long-lived secret handoff is a private runtime config file
- Treat `auth` as outbound service/provider credentials and `gateway.auth` as inbound gateway access control
- Treat persisted provider auth state as environment-local sensitive data that survives normal container redeploys when the state path is preserved
- Treat paired-device state as environment-local sensitive runtime state that survives normal redeploys when the state path is preserved
- For OpenAI/API-key style providers, standardize on:
  - `auth.profiles` in the rendered config declaring the profile and mode
  - for Docker-local and cloud, the environment secret overlay may hold `auth.profiles.<profile>.apiKey`, which is written to a runtime env file during bootstrap and removed from the rendered OpenClaw config
  - reserve interactive `paste-token` flows for providers or environments that cannot use static key injection cleanly
- Treat Telegram DM approval files in `credentials/` with the same sensitivity as node/app device approval files in `devices/`
- Keep source-of-truth workspace files harder to mutate than runtime state so compromise of the runtime does not automatically allow persistent policy rewrites
- Avoid hand-editing live configuration on the VM except for short-lived break-glass debugging
- Any emergency VM-side config change must be back-ported into Git immediately

## Dependency Management Approach

The dependency model is intentionally split by ecosystem.

Cross-ecosystem runtime versions:
- Keep a single checked-in version manifest for:
  - OpenClaw runtime version
  - Gog version
  - Docker base images
  - Cloud Function Node runtime
  - Cloud Function package versions
- Render Docker build args from that manifest into an environment file consumed by local and cloud compose flows.

Node-managed dependencies:
- Use exact versions plus a lockfile for the Cloud Function package.
- Prefer `npm ci`-style reproducibility for Node packages over floating installs.

Host-native tools:
- Treat native-local tools such as `openclaw`, `gog`, `ripgrep`, Docker Desktop/OrbStack, `gcloud`, and `tofu` as operator-managed.
- The repository should report required/tested versions clearly, but it does not need to own workstation package installation.

Update flow:
1. Edit the central version manifest.
2. Regenerate derived Docker build env and package manifests.
3. Refresh lockfiles where applicable.
4. Rebuild Docker-local and cloud images.
5. Validate local-native and Docker-local tool/runtime parity.

## Authentication and Secret Management Approach

Authentication is split between config-bound secrets and runtime auth state.

Config-bound secrets:
- Environment-specific secret overlays define:
  - gateway auth token
  - provider profile metadata
  - channel tokens
  - optional hook configuration
- Local and cloud should use separate secret payloads with the same schema.

Runtime auth state:
- Runtime-issued auth artifacts stay environment-local:
  - native local: `~/.openclaw`
  - Docker-local: `/home/node/.openclaw`
  - cloud: `/opt/openclaw/state/home`
- Native-local runtime state must not be used as an implicit configuration source for Docker-local or cloud.

Recommended auth model by environment:
- Native local:
  - interactive OAuth/provider login is acceptable when it is the cleanest operator path
- Docker-local:
  - prefer non-interactive auth
  - API-key providers may be sourced from the local secret overlay and emitted into Docker env
  - Gmail should prefer Workspace service-account auth for `automation@example.com`
- Cloud:
  - prefer non-interactive auth and Secret Manager-backed config
  - API-key providers may be sourced from the cloud secret overlay and emitted into a VM-rendered runtime env file
  - Gmail should prefer Workspace service-account auth for `automation@example.com`

Cloud runtime lifecycle guidance:
- Cloud app-tree sync and cloud runtime state should be treated as separate concerns.
- The synced app tree may be replaced or re-synced during deploys, while `/opt/openclaw/state` is the durable runtime boundary.
- Cloud startup should assume the VM may restart with durable host state but without a fresh image rebuild.
- Host-mounted state paths must be writable by the container user on every startup:
  - `/opt/openclaw/state/home`
  - `/opt/openclaw/state/workspace`
  - `/opt/openclaw/state/memory`
- Rendered runtime artifacts must also be readable by the container user:
  - `/opt/openclaw/state/runtime/openclaw.json`
  - `/opt/openclaw/state/runtime/runtime.env`
  - `/opt/openclaw/state/runtime/gog-service-account.json`
- The cloud workspace sync should create mount-point directories expected by nested writable binds:
  - `/opt/openclaw/app/workspace/.openclaw`
  - `/opt/openclaw/app/workspace/memory`
- Normal cloud deploys should rebuild with cache; a separate clean rebuild path should exist for stale-image recovery and deep runtime image changes.
- Durable automation schedules such as the morning Pip digest should be treated as deployable desired config, then reconciled into gateway runtime state idempotently.
- Cron reconciliation should key off stable job names so repeated deploy/apply runs update existing jobs instead of creating duplicate scheduled sends.

Gmail approach:
- Gmail historical pull is sufficient for digest/read workflows.
- Pub/Sub/webhook ingestion is not a prerequisite for digest coverage.
- Docker-local should keep Gmail Pub/Sub/webhook ingestion disabled by default unless realtime ingestion is being tested intentionally.

## Setup and Bootstrap Approach

Bootstrap scripts should do three things consistently:
- render environment-specific runtime config from repo templates plus secret overlays
- render any additional bootstrap artifacts needed by Docker or helper tools
- start or update the runtime without depending on hidden local state

Local Docker:
- A single preparation step should:
  - render Docker build env
  - render Docker runtime config
  - render Docker-local secret/bootstrap artifacts
  - build the image
  - initialize writable state paths
- Docker-local should remain cloud-parity oriented, with a separate gateway port and separate runtime state from native local.
- Docker-local should expose the same operator lifecycle shape as cloud where practical:
  - deploy
  - restart without rebuild
  - clean rebuild
  - ps/logs/shell helpers
  - repo-managed cron reconciliation
- Repo-managed local cron config should default to disabled for durable jobs that are already scheduled in cloud, to avoid duplicate sends while preserving parity of tooling and config shape.

Cloud:
- Cloud deploy should:
  - sync the repo-managed application bundle
  - fetch the cloud secret payload from Secret Manager
  - render runtime config on the VM host
  - start or restart Docker services
- Cloud deploy should preserve persisted runtime state under `/opt/openclaw/state`.

Operational stance:
- Repo-managed templates and scripts are the source of truth for reviewed behavior.
- Secret overlays are the source of truth for config-bound secret values.
- Runtime state is durable but environment-local and not authoritative for reviewed configuration.

## Digest Design Direction

- Keep retrieval, extraction, artifact staging, and final delivery code-owned wherever practical.
- Keep skills focused on source-selection rules, synthesis rules, and output shape rather than filesystem choreography.
- The preferred digest pipeline is:
  1. select messages with `gog`
  2. extract each selected message into inspectable artifacts
  3. summarize from cleaned artifacts rather than raw Gmail payloads
  4. write final delivery artifacts
  5. send through a helper-backed `gog gmail send` path

Bounded synthesis direction:
- If the digest moves to parallel synthesis later, use bounded per-newsletter workers rather than delegating the whole workflow.
- Each worker should receive only cleaned, source-specific artifacts such as:
  - `metadata.json`
  - `links.json`
  - `clean.md`
- Each worker should return only a structured section result for its assigned source.
- Message selection, extraction, run-directory creation, artifact staging, and final send should remain centralized and deterministic.
- Subagent-style parallelism should be treated as a synthesis optimization only after the deterministic runner path exists, not as a substitute for code-owned orchestration.

# Non-Goals (For Now)

- Multi-user support
- Production hardening
- Enterprise compliance
- Automated secret rotation
- CI/CD pipeline

This is a personal secure experimentation lab.

---

# Success Criteria

Environment is considered correctly provisioned when:

- VM has no external IP
- SSH only works via IAP
- VM can reach internet outbound
- Egress behavior matches explicit firewall policy and is logged where needed
- Secrets are retrievable by VM
- Secrets are NOT present in OpenTofu state
- Budget alerts are active
- Budget Pub/Sub notifications reach the shutdown function
- Shutdown automation can stop the VM on threshold breach
- OpenClaw starts and can access scoped integrations

---
