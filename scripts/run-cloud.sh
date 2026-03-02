#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 SECRET_NAME" >&2
  exit 1
fi

cd "$(dirname "$0")/.."
mkdir -p "${OPENCLAW_DEPLOY_ROOT:-/opt/openclaw}/state/home" "${OPENCLAW_DEPLOY_ROOT:-/opt/openclaw}/state/runtime" "${OPENCLAW_DEPLOY_ROOT:-/opt/openclaw}/state/workspace"
./scripts/render-openclaw-cloud.sh "$1"
docker compose -f docker/compose.cloud.yml up -d openclaw-gateway
