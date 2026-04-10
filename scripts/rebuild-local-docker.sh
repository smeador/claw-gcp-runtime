#!/bin/bash
set -euo pipefail

compose_cmd() {
  docker compose --env-file config/docker.build.env "$@"
}

cd "$(dirname "$0")/.."

node ./scripts/render-docker-build-env.mjs --output config/docker.build.env
node ./scripts/render-runtime-env.mjs \
  --secrets config/secrets.local.json \
  --output config/docker.local.env
node ./scripts/render-gog-service-account-key.mjs \
  --secrets config/secrets.local.json \
  --account "${GOG_ACCOUNT:-pip@meador.me}" \
  --output config/rendered/gog-service-account.json
bash ./scripts/render-openclaw-local.sh
mkdir -p workspace/.tmp

compose_cmd -f docker/compose.local.yml build --no-cache openclaw-gateway openclaw-cli
compose_cmd -f docker/compose.local.yml run --rm --no-deps --user root --entrypoint bash openclaw-gateway -lc '
  set -euo pipefail
  mkdir -p \
    /home/node/.openclaw/identity \
    /home/node/.openclaw/agents/main/agent \
    /home/node/.openclaw/agents/main/sessions \
    /workspace/.openclaw \
    /workspace/memory
  chown -R node:node /home/node/.openclaw /workspace/.openclaw /workspace/memory
'
compose_cmd -f docker/compose.local.yml up -d --force-recreate openclaw-gateway
OPENCLAW_APP_ROOT="$(pwd)" bash ./scripts/apply-local-cron.sh "${LOCAL_CRON_FILE:-config/cron.local.json}"

echo "Pruning unused Docker images after successful rebuild..."
docker image prune -af >/dev/null || true
