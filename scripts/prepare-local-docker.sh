#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

node ./scripts/render-docker-local-env.mjs \
  --secrets config/secrets.local.json \
  --output config/docker.local.env
node ./scripts/render-gog-service-account-key.mjs \
  --secrets config/secrets.local.json \
  --account "${GOG_ACCOUNT:-automation@example.com}" \
  --output config/rendered/gog-service-account.json

bash ./scripts/render-openclaw-local.sh
mkdir -p workspace/.tmp
docker compose -f docker/compose.local.yml build openclaw-gateway openclaw-cli

# Match upstream docker-setup.sh behavior: eagerly seed OpenClaw state paths
# and fix ownership before onboarding or starting the gateway.
docker compose -f docker/compose.local.yml run --rm --no-deps --user root --entrypoint bash openclaw-gateway -lc '
  set -euo pipefail
  mkdir -p \
    /home/node/.openclaw/identity \
    /home/node/.openclaw/agents/main/agent \
    /home/node/.openclaw/agents/main/sessions \
    /workspace/.openclaw \
    /workspace/memory
  chown -R node:node /home/node/.openclaw /workspace/.openclaw /workspace/memory
'
