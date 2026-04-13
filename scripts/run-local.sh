#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
bash ./scripts/prepare-local-docker.sh
docker compose --env-file config/docker.build.env -f docker/compose.local.yml up -d openclaw-gateway
OPENCLAW_APP_ROOT="$(pwd)" bash ./scripts/apply-local-cron.sh "${LOCAL_CRON_FILE:-config/cron.local.json}"
bash ./scripts/prune-unused-docker-images.sh
