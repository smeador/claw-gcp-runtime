#!/bin/bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 ENV ACTION [SECRET_NAME]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/lib/runtime-common.sh"

ENV_NAME="$1"
ACTION="$2"
SECRET_NAME="${3:-}"

runtime_init_env "${ENV_NAME}"

ensure_cloud_secret() {
  if [ -z "${SECRET_NAME}" ]; then
    echo "Usage: $0 cloud ${ACTION} SECRET_NAME" >&2
    exit 1
  fi
}

apply_cron() {
  bash "${SCRIPT_DIR}/runtime-cron.sh" "${ENV_NAME}" apply "${RUNTIME_DEFAULT_CRON_FILE}"
}

case "${ENV_NAME}:${ACTION}" in
  local:prepare)
    runtime_prepare_local_artifacts
    runtime_compose_cmd -f "${RUNTIME_COMPOSE_FILE}" build openclaw-gateway openclaw-cli
    runtime_seed_local_state
    ;;
  local:deploy)
    bash "${SCRIPT_DIR}/runtime-lifecycle.sh" local prepare
    runtime_compose_cmd -f "${RUNTIME_COMPOSE_FILE}" up -d openclaw-gateway
    apply_cron
    bash "${SCRIPT_DIR}/prune-unused-docker-images.sh"
    ;;
  local:restart)
    runtime_prepare_local_artifacts
    runtime_seed_local_state
    runtime_compose_cmd -f "${RUNTIME_COMPOSE_FILE}" up -d openclaw-gateway
    apply_cron
    ;;
  local:rebuild)
    runtime_prepare_local_artifacts
    runtime_compose_cmd -f "${RUNTIME_COMPOSE_FILE}" build --no-cache openclaw-gateway openclaw-cli
    runtime_seed_local_state
    runtime_compose_cmd -f "${RUNTIME_COMPOSE_FILE}" up -d --force-recreate openclaw-gateway
    apply_cron
    bash "${SCRIPT_DIR}/prune-unused-docker-images.sh"
    ;;
  cloud:deploy)
    ensure_cloud_secret
    runtime_prepare_cloud_state
    runtime_render_cloud_artifacts "${SECRET_NAME}"
    runtime_compose_cmd -f "${RUNTIME_COMPOSE_FILE}" up -d --build openclaw-gateway
    apply_cron
    bash "${SCRIPT_DIR}/prune-unused-docker-images.sh"
    ;;
  cloud:restart)
    ensure_cloud_secret
    runtime_prepare_cloud_state
    runtime_render_cloud_artifacts "${SECRET_NAME}"
    runtime_compose_cmd -f "${RUNTIME_COMPOSE_FILE}" up -d openclaw-gateway
    apply_cron
    ;;
  cloud:rebuild)
    ensure_cloud_secret
    runtime_prepare_cloud_state
    runtime_render_cloud_artifacts "${SECRET_NAME}"
    runtime_compose_cmd -f "${RUNTIME_COMPOSE_FILE}" build --no-cache openclaw-gateway
    runtime_compose_cmd -f "${RUNTIME_COMPOSE_FILE}" up -d --force-recreate openclaw-gateway
    apply_cron
    bash "${SCRIPT_DIR}/prune-unused-docker-images.sh"
    ;;
  *)
    echo "Unknown runtime lifecycle: ${ENV_NAME} ${ACTION}" >&2
    exit 1
    ;;
esac
