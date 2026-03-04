# Claw Runtime GCP Infrastructure & Security Spec

## Overview

This project provisions a secure, isolated experimentation environment on Google Cloud Platform (GCP) for running OpenClaw (or equivalent agent runtime) using OpenTofu.

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
- Gmail OAuth refresh token
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
Restart required to pick up updated secrets (initial model).
Old secret versions should be disabled before destruction when rotating credentials.

Future improvement:
- TTL-based refresh
- Version alias switching
- Automated rotation

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

Optional future enhancement:
- Scheduled shutdown via Cloud Scheduler

---

# Security Posture

## Agent Risk Model

OpenClaw is treated as:

- Tool-using autonomous runtime
- Executes instructions derived from external content
- Holds durable delegated credentials

Therefore:

- Runs in isolated private VM
- No marketplace skills initially
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
- Keep the workspace, skills, and agent policy in the repository so local and cloud runs use the same reviewed source of truth

Local development:
- Prefer a local OpenClaw runtime for the fastest iteration loop
- Keep the active workspace in the repository
- Test new skills locally before deploying them to the VM
- Keep the local gateway bound to loopback only unless there is an explicit need for remote exposure
- Do not enable Tailscale or tailnet exposure initially

Cloud deployment:
- Run OpenClaw in Docker on the VM
- Mount the same reviewed workspace/configuration used for local development
- Fetch secrets on the VM at startup and inject them into the container runtime
- Keep the container image generic and keep agent behavior in mounted config and skills

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
- Install third-party skills initially

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
- That payload currently contains `auth` and `gateway.auth`
- The payload is merged into the environment-specific OpenClaw template at render time
- The payload contract should be documented in the repository and treated as a security-sensitive interface
- Local and cloud environments should use separate secret payload files even when they share the same schema
- Platform identity such as the VM service account is not stored in the OpenClaw runtime secret payload
- Browser/session state and other runtime artifacts are persisted separately from the config secret payload
- `gateway.auth` should be treated as a rendered config secret
- Provider auth may also persist in OpenClaw runtime state files and should be treated as sensitive environment-local state

Version control in Git:
- OpenClaw base configuration
- Agent instruction files such as `AGENTS.md`
- Tool policy files such as `TOOLS.md`
- Approved workspace skills
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
- `/workspace/skills/`
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
- Hardened runtime containers should keep `/workspace`, `/config`, and `/runtime` read-only and use dedicated writable state mounts instead
- Required writable Docker-local state paths are `/home/node/.openclaw`, `/workspace/.openclaw`, and `/workspace/memory`
- A separate root-owned dev container may share the same state volumes for manual editing/debugging without loosening the runtime gateway container

Container runtime constraints:
- OpenClaw should not attempt to install or manage host daemons from inside the application container
- `systemd`, `launchd`, and similar host init integrations are not expected to be available inside Docker-local or Docker-cloud runtime containers
- Docker restart policy or host-level service management should be used for container lifecycle, not OpenClaw daemon installation inside the container
- Hook or service flows that assume host init availability should be skipped or handled outside the application container

Container operations guidance:
- Treat runtime onboarding as a bootstrap/recovery path, not a routine operational workflow
- Routine provider changes should use targeted model auth commands such as `openclaw models auth login --provider openai` or `openclaw models auth paste-token --provider openai`
- Routine gateway token rotation should happen by updating the environment-specific secret payload and restarting or redeploying the gateway
- Routine skills and hooks changes should happen in reviewed repository files and then be applied via local restart or cloud redeploy
- Device pairing for the dashboard is environment-local and must be approved against the same runtime environment that owns the gateway state
- Routine container administration should prefer shelling into the running `openclaw-gateway` container and running OpenClaw commands there, rather than relying on long one-off `docker compose ... run` invocations
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
7. For cloud Docker, fetch the single JSON secret payload from Secret Manager at startup.
8. Deploy or sync configuration to the VM.
9. Start or restart the OpenClaw service.

Operational guidance:
- Git is the source of truth for non-secret configuration
- Secret Manager is the source of truth for secret material
- The VM should hold only rendered runtime state
- Runtime-managed config fields should persist locally or in container state, but should not replace the repo-managed template as the source of truth
- Local Docker should use a Git-ignored local secret file for parity testing rather than storing important credentials only in container state
- OpenClaw config secrets should be rendered to a private runtime file and mounted read-only into the container
- Environment variables may still be used for narrowly scoped bootstrap logic, but the preferred long-lived secret handoff is a private runtime config file
- Treat `auth` as outbound service/provider credentials and `gateway.auth` as inbound gateway access control
- Treat persisted provider auth state as environment-local sensitive data that survives normal container redeploys when the state path is preserved
- Treat paired-device state as environment-local sensitive runtime state that survives normal redeploys when the state path is preserved
- Keep source-of-truth workspace files harder to mutate than runtime state so compromise of the runtime does not automatically allow persistent policy or skill rewrites
- Avoid hand-editing live configuration on the VM except for short-lived break-glass debugging
- Any emergency VM-side config change must be back-ported into Git immediately

## Skill Governance

Skills must be treated as code and reviewed before use.

Phase 1 policy:
- Allow only workspace-local reviewed skills
- Do not enable third-party marketplace or community skills
- Do not rely on user-global skill directories such as `~/.openclaw/skills` as a primary source
- Disable or avoid bundled skills unless explicitly approved for the lab

Skill storage model:
- Store approved skills under the workspace `skills/` directory
- Version control each skill definition in Git
- Keep the active skill set minimal and task-specific

Each skill should define:
- Purpose and expected behavior
- Allowed tools
- Allowed filesystem paths
- Allowed external domains or APIs
- Required secrets or environment variables
- Refusal conditions and safety limits

Skill review checklist:
- Verify the skill has a narrow scope
- Verify it does not request unnecessary shell or filesystem access
- Verify any external network access is intentional and allowlisted
- Verify secret requirements are minimal
- Verify the skill cannot silently broaden agent permissions

Task model:
- Persistent behavior and global safety constraints belong in `AGENTS.md`
- Tool restrictions and execution policy belong in `TOOLS.md`
- Reusable workflows belong in reviewed workspace skills
- Ad hoc shell access should not be the default mechanism for recurring tasks

Initial recommended skills:
- `gmail-triage`
- `calendar-brief`
- `allowed-web-research`
- `report-daily-summary`
- `opentofu-readonly-review`

Future enhancements:
- Add skill auditing pipeline
- Add monitoring dashboard
- Add log-based alerts
- Improve local developer experience with a clearer steady-state playbook and fewer commands for provider registration, token rotation, and device pairing

---

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

# Future Phases

Phase 2:
- Add monitoring dashboards
- Add structured log export
- Introduce secret rotation schedule
- Smooth the cloud operator flow further so first deploy, secret push, and app sync require fewer manual steps

Phase 3:
- Explore autonomous coding workflows
- Refine local and cloud operator tooling so provider registration, token rotation, skill updates, and device pairing are less clunky
