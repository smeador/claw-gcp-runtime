#!/bin/bash
# Cloud deploys own this dedicated Docker daemon; never use this on local Docker.

runtime_cloud_free_kb() {
  df -Pk "${CLOUD_DOCKER_ROOT}" | awk 'NR == 2 {print $4}'
}

runtime_cloud_storage_cleanup() {
  # Keep tagged images (including rollback) and every container's image.
  # Legacy multi-stage builds retain images, not BuildKit cache records.
  docker image prune --force --filter until=24h || return $?
  docker builder prune --force --filter until=24h --keep-storage 2GB || return $?
  if [ "$(runtime_cloud_free_kb)" -lt "${CLOUD_MIN_FREE_KB}" ]; then
    echo "Cloud Docker disk space is low; reclaiming recent dangling images and unused build cache."
    docker image prune --force || return $?
    docker builder prune --all --force --keep-storage 1GB || return $?
  fi
  df -h "${CLOUD_DOCKER_ROOT}"
}

runtime_cloud_storage_finish() {
  local status="$?"
  trap - EXIT
  # Cleanup must not hide the build/deploy error that caused this exit.
  if ! (set -e; runtime_cloud_storage_cleanup); then
    echo "Cloud Docker cleanup failed; inspect disk usage before the next deploy." >&2
    if [ "${status}" -eq 0 ]; then status=1; fi
  fi
  exit "${status}"
}

runtime_cloud_storage_prepare() {
  # Serializes builds and pruning performed by this runtime.
  mkdir -p "${RUNTIME_DEPLOY_ROOT}/state/runtime"
  exec 9>"${RUNTIME_DEPLOY_ROOT}/state/runtime/deploy.lock"
  flock -n 9 || { echo "Another cloud deployment is running." >&2; return 1; }
  CLOUD_DOCKER_ROOT="$(docker info --format '{{.DockerRootDir}}')"
  CLOUD_MIN_FREE_KB="${OPENCLAW_BUILD_MIN_FREE_KB:-6291456}"
  if ! [[ "${CLOUD_MIN_FREE_KB}" =~ ^[1-9][0-9]*$ ]]; then
    echo "OPENCLAW_BUILD_MIN_FREE_KB must be a positive integer." >&2
    return 1
  fi
  runtime_cloud_storage_cleanup
  if [ "$(runtime_cloud_free_kb)" -lt "${CLOUD_MIN_FREE_KB}" ]; then
    echo "Insufficient Docker disk space for a cloud build (need ${CLOUD_MIN_FREE_KB} KiB free). Running gateway was not stopped." >&2
    return 1
  fi
  trap runtime_cloud_storage_finish EXIT
}

runtime_cloud_preserve_rollback() {
  local container previous current
  container="$(runtime_compose_cmd -f "${RUNTIME_COMPOSE_FILE}" ps -q openclaw-gateway)"
  [ -n "${container}" ] || return 0
  previous="$(docker inspect --format '{{.Image}}' "${container}")"
  current="$(docker image inspect --format '{{.Id}}' claw-runtime-openclaw:cloud)"
  # Repeated deploys of the same image must not erase the rollback candidate.
  if [ "${previous}" != "${current}" ]; then
    docker image tag "${previous}" claw-runtime-openclaw:cloud-rollback
  fi
}
