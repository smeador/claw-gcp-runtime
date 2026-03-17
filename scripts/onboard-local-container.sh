#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
bash ./scripts/prepare-local-docker.sh
docker compose --env-file config/docker.build.env -f docker/compose.local.yml run --rm openclaw-cli onboard --mode local --no-install-daemon --workspace /workspace
