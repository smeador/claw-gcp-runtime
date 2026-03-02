#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
./scripts/render-openclaw-local.sh
docker compose -f docker/compose.local.yml run --rm openclaw-cli onboard --workspace /workspace
