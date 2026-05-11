# Runtime Operations

This document is the detailed operator runbook for the local and cloud runtime.

Use [README.md](/Users/sean/Repos/gcp-claw-lab/README.md) as the front door. Use this file when you need the heavier operational detail.

## Operator Environment

Recommended local setup:

- install `direnv`
- create `.envrc.local`
- let the repo-managed `.envrc` expose `agent-runtime` on `PATH`

Example:

```bash
cd /Users/sean/Repos/gcp-claw-lab
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

## Secret Files

Start from:

- [`/Users/sean/Repos/gcp-claw-lab/config/secrets.local.example.json`](/Users/sean/Repos/gcp-claw-lab/config/secrets.local.example.json)
- [`/Users/sean/Repos/gcp-claw-lab/config/secrets.cloud.example.json`](/Users/sean/Repos/gcp-claw-lab/config/secrets.cloud.example.json)

Local runtime secrets live in:

- [`/Users/sean/Repos/gcp-claw-lab/config/secrets.local.json`](/Users/sean/Repos/gcp-claw-lab/config/secrets.local.json)

Cloud runtime secrets live in:

- [`/Users/sean/Repos/gcp-claw-lab/config/secrets.cloud.json`](/Users/sean/Repos/gcp-claw-lab/config/secrets.cloud.json)

## Local Runtime

Initial setup:

```bash
cd /Users/sean/Repos/gcp-claw-lab
npm run deps:sync
cp config/secrets.local.example.json config/secrets.local.json
agent-runtime local deploy
```

Common commands:

```bash
agent-runtime local help
agent-runtime local deploy
agent-runtime local restart
agent-runtime local rebuild
agent-runtime local prune
agent-runtime local ps
agent-runtime local logs
agent-runtime local agent-logs
agent-runtime local shell
agent-runtime local cron apply
agent-runtime local cron list
agent-runtime local cron run-digest
agent-runtime local test basic
agent-runtime local test core
agent-runtime local test integration
agent-runtime local test skill newsletter-digest
agent-runtime local test gmail-read
agent-runtime local test gmail-send
```

Useful maintenance helpers:

```bash
bash /Users/sean/Repos/gcp-claw-lab/scripts/maintenance/reset-local-docker.sh
bash /Users/sean/Repos/gcp-claw-lab/scripts/maintenance/print-local-docker-access.sh
node /Users/sean/Repos/gcp-claw-lab/scripts/maintenance/check-native-local-sync.mjs
```

## Cloud Runtime

Initial setup:

```bash
cd /Users/sean/Repos/gcp-claw-lab
npm run deps:sync
cp config/secrets.cloud.example.json config/secrets.cloud.json
agent-runtime cloud push-secret
agent-runtime cloud deploy
```

Common commands:

```bash
agent-runtime cloud help
agent-runtime cloud push-secret
agent-runtime cloud sync
agent-runtime cloud deploy
agent-runtime cloud restart
agent-runtime cloud rebuild
agent-runtime cloud prune
agent-runtime cloud ps
agent-runtime cloud logs
agent-runtime cloud agent-logs
agent-runtime cloud logs-download
agent-runtime cloud shell
agent-runtime cloud tunnel
agent-runtime cloud cron apply
agent-runtime cloud cron list
agent-runtime cloud cron run-digest
agent-runtime cloud test skill newsletter-digest
agent-runtime cloud test gmail-read
agent-runtime cloud test gmail-send
```

Direct VM shell:

```bash
bash /Users/sean/Repos/gcp-claw-lab/scripts/cloud/ssh-app.sh bash
```

## Gmail Bootstrap and Testing

Normal path:

- store service-account material in the local/cloud secret overlay
- let the runtime render the key and bootstrap `gog`
- verify with the runtime test commands

Preferred verification:

```bash
agent-runtime local test gmail-read
agent-runtime local test gmail-send
agent-runtime cloud test gmail-read
agent-runtime cloud test gmail-send
```

Manual recovery scripts still exist for break-glass recovery:

- [`/Users/sean/Repos/gcp-claw-lab/scripts/gmail/bootstrap-gog-docker-local.sh`](/Users/sean/Repos/gcp-claw-lab/scripts/gmail/bootstrap-gog-docker-local.sh)
- [`/Users/sean/Repos/gcp-claw-lab/scripts/gmail/bootstrap-gog-cloud-service-account.sh`](/Users/sean/Repos/gcp-claw-lab/scripts/gmail/bootstrap-gog-cloud-service-account.sh)

## Runtime Notes

- `workspace/skills` is generated composed state
- some integration-owned files under `workspace/config` are also generated composed state
- local cron is disabled by default to avoid duplicate sends when cloud cron is active
- cloud deploy packages sibling integrations from the local checkout at deploy time
- the VM does not fetch sibling integration repos directly during deploy
