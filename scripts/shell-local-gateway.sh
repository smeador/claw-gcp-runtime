#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

node ./scripts/render-docker-build-env.mjs --output config/docker.build.env >/dev/null
docker compose --env-file config/docker.build.env -f docker/compose.local.yml exec openclaw-gateway bash
