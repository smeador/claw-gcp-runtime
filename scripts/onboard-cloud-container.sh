#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 SECRET_NAME" >&2
  exit 1
fi

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    docker compose --env-file config/docker.build.env "$@"
  else
    docker-compose --env-file config/docker.build.env "$@"
  fi
}

APP_ROOT="${OPENCLAW_APP_ROOT:-/opt/openclaw/app}"
DEPLOY_ROOT="${OPENCLAW_DEPLOY_ROOT:-/opt/openclaw}"

cd "${APP_ROOT}"
mkdir -p "${DEPLOY_ROOT}/state/home" "${DEPLOY_ROOT}/state/runtime" "${DEPLOY_ROOT}/state/workspace" "${DEPLOY_ROOT}/state/memory"
bash ./scripts/render-openclaw-cloud.sh "$1"
compose_cmd -f docker/compose.cloud.yml run --rm openclaw-cli onboard --mode local --no-install-daemon --workspace /workspace
