#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../.."

PROVIDER="${1:-openai}"

docker compose -f docker/compose.local.yml up -d openclaw-gateway >/dev/null

echo "Bootstrapping ${PROVIDER} auth inside Docker-local runtime state..."
echo "Paste the token when prompted. This updates /home/node/.openclaw for Docker-local only."

docker compose -f docker/compose.local.yml exec openclaw-gateway \
  openclaw models auth paste-token --provider "${PROVIDER}"
