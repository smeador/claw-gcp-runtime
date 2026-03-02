#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
bash ./scripts/prepare-local-docker.sh
docker compose -f docker/compose.local.yml up -d openclaw-gateway
