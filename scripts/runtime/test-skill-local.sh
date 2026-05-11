#!/bin/bash
set -euo pipefail

SKILL_NAME="${1:-}"

if [ -z "${SKILL_NAME}" ]; then
  echo "Usage: $0 SKILL_NAME" >&2
  exit 1
fi

cd "$(dirname "$0")/../.."
RUNNER_PATH="$(node ./scripts/runtime/resolve-skill-test-runner.mjs "${SKILL_NAME}")"
CONTAINER_RUNNER_PATH="/opt/claw-runtime/integrations/${RUNNER_PATH#.runtime/integrations/}"

compose_args=(
  --env-file config/docker.build.env
  -f docker/compose.local.yml
  exec
)

if [ -n "${SKILL_TEST_MESSAGE:-}" ]; then
  compose_args+=(-e "SKILL_TEST_MESSAGE=${SKILL_TEST_MESSAGE}")
fi

if [ -n "${SKILL_TEST_TIMEOUT_MS:-}" ]; then
  compose_args+=(-e "SKILL_TEST_TIMEOUT_MS=${SKILL_TEST_TIMEOUT_MS}")
fi

compose_args+=(
  openclaw-gateway
  bash
  -lc
  "bash ${CONTAINER_RUNNER_PATH} $(printf '%q' "${SKILL_NAME}")"
)

docker compose "${compose_args[@]}"
