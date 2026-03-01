#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p "${OPENCLAW_DEPLOY_ROOT:-/opt/openclaw}/state/home" "${OPENCLAW_DEPLOY_ROOT:-/opt/openclaw}/state/workspace"
docker compose -f docker/compose.cloud.yml run --rm openclaw-cli onboard --workspace /workspace
