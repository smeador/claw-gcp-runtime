#!/bin/bash
set -euo pipefail

RUNTIME_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNTIME_SCRIPTS_DIR="$(cd "${RUNTIME_LIB_DIR}/.." && pwd)"
RUNTIME_REPO_ROOT="$(cd "${RUNTIME_SCRIPTS_DIR}/.." && pwd)"

runtime_compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    docker compose --env-file config/docker.build.env "$@"
  else
    docker-compose --env-file config/docker.build.env "$@"
  fi
}

runtime_init_env() {
  if [ $# -ne 1 ]; then
    echo "Usage: runtime_init_env ENV" >&2
    return 1
  fi

  RUNTIME_ENV="$1"

  case "${RUNTIME_ENV}" in
    local)
      RUNTIME_APP_ROOT="${OPENCLAW_APP_ROOT:-${RUNTIME_REPO_ROOT}}"
      RUNTIME_DEPLOY_ROOT=""
      RUNTIME_COMPOSE_FILE="docker/compose.local.yml"
      RUNTIME_DEFAULT_CRON_FILE="config/cron.local.json"
      RUNTIME_LABEL="Local"
      ;;
    cloud)
      RUNTIME_APP_ROOT="${OPENCLAW_APP_ROOT:-/opt/openclaw/app}"
      RUNTIME_DEPLOY_ROOT="${OPENCLAW_DEPLOY_ROOT:-/opt/openclaw}"
      RUNTIME_COMPOSE_FILE="docker/compose.cloud.yml"
      RUNTIME_DEFAULT_CRON_FILE="config/cron.cloud.json"
      RUNTIME_LABEL="Cloud"
      ;;
    *)
      echo "Unknown runtime environment: ${RUNTIME_ENV}" >&2
      return 1
      ;;
  esac

  export RUNTIME_ENV
  export RUNTIME_APP_ROOT
  export RUNTIME_DEPLOY_ROOT
  export RUNTIME_COMPOSE_FILE
  export RUNTIME_DEFAULT_CRON_FILE
  export RUNTIME_LABEL

  cd "${RUNTIME_APP_ROOT}"
}

runtime_prepare_local_artifacts() {
  cd "${RUNTIME_REPO_ROOT}"

  node ./scripts/stage-workspace-integrations.mjs
  node ./scripts/render-docker-build-env.mjs --output config/docker.build.env
  node ./scripts/render-runtime-env.mjs \
    --secrets config/secrets.local.json \
    --output config/docker.local.env
  node ./scripts/render-gog-service-account-key.mjs \
    --secrets config/secrets.local.json \
    --account "${GOG_ACCOUNT:-pip@meador.me}" \
    --output config/rendered/gog-service-account.json

  bash ./scripts/render-openclaw-local.sh
  mkdir -p workspace/.tmp
}

runtime_seed_local_state() {
  runtime_compose_cmd -f "${RUNTIME_COMPOSE_FILE}" run --rm --no-deps --user root --entrypoint bash openclaw-gateway -lc '
    set -euo pipefail
    mkdir -p \
      /home/node/.openclaw/identity \
      /home/node/.openclaw/agents/main/agent \
      /home/node/.openclaw/agents/main/sessions \
      /workspace/.openclaw \
      /workspace/memory
    chown -R node:node /home/node/.openclaw /workspace/.openclaw /workspace/memory
  '
}

runtime_prepare_cloud_state() {
  mkdir -p \
    "${RUNTIME_DEPLOY_ROOT}/state/home" \
    "${RUNTIME_DEPLOY_ROOT}/state/runtime" \
    "${RUNTIME_DEPLOY_ROOT}/state/workspace" \
    "${RUNTIME_DEPLOY_ROOT}/state/memory"
  chown -R 1000:1000 \
    "${RUNTIME_DEPLOY_ROOT}/state/home" \
    "${RUNTIME_DEPLOY_ROOT}/state/workspace" \
    "${RUNTIME_DEPLOY_ROOT}/state/memory"
}

runtime_render_cloud_artifacts() {
  if [ $# -ne 1 ]; then
    echo "Usage: runtime_render_cloud_artifacts SECRET_NAME" >&2
    return 1
  fi

  bash ./scripts/render-openclaw-cloud.sh "$1"
}

runtime_gateway_exec() {
  runtime_compose_cmd -f "${RUNTIME_COMPOSE_FILE}" exec -T openclaw-gateway "$@"
}

runtime_wait_for_gateway() {
  local attempts="${OPENCLAW_CRON_READY_ATTEMPTS:-30}"
  local sleep_seconds="${OPENCLAW_CRON_READY_SLEEP_SECONDS:-1}"

  for ((attempt = 1; attempt <= attempts; attempt += 1)); do
    if runtime_gateway_exec openclaw cron list --all --json >/dev/null 2>&1; then
      return 0
    fi
    sleep "${sleep_seconds}"
  done

  echo "${RUNTIME_LABEL} gateway did not become ready for cron operations after ${attempts} attempts." >&2
  return 1
}
