#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
node ./scripts/render-docker-build-env.mjs --output config/docker.build.env >/dev/null

echo "Resetting Docker-local OpenClaw state..."

docker compose --env-file config/docker.build.env -f docker/compose.local.yml down --remove-orphans || true
docker volume rm docker_openclaw_home_local docker_openclaw_workspace_state_local docker_openclaw_memory_local 2>/dev/null || true
rm -f config/rendered/openclaw.json

cat <<'EOF'
Docker-local state reset complete.

This removed:
- Docker-local OpenClaw home state
- Docker-local workspace state
- Docker-local workspace memory state
- Rendered Docker-local runtime config

This did not remove:
- Native local OpenClaw state under ~/.openclaw
- config/secrets.local.json
- Repo-managed workspace/config files

Next steps:
1. agent-runtime local deploy
2. bash ./scripts/print-local-docker-access.sh
3. If Docker-local uses an API-key provider, confirm the key in config/secrets.local.json and rerun agent-runtime local deploy
EOF
