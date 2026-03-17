#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

echo "Resetting Docker-local OpenClaw state..."

docker compose -f docker/compose.local.yml down --remove-orphans || true
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
1. bash ./scripts/prepare-local-docker.sh
2. bash ./scripts/run-local.sh
3. bash ./scripts/print-local-docker-access.sh
4. Re-register provider auth with:
   bash ./scripts/models/bootstrap-openai-docker-local.sh
EOF
