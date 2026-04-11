#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

MESSAGE="${DIGEST_MESSAGE:-Run pip-newsletter-digest now in test mode.}"
TIMEOUT_MS="${DIGEST_TEST_TIMEOUT_MS:-600000}"

docker compose --env-file config/docker.build.env -f docker/compose.local.yml exec openclaw-gateway \
  bash -lc "DIGEST_MESSAGE=$(printf '%q' "${MESSAGE}") DIGEST_TEST_TIMEOUT_MS=$(printf '%q' "${TIMEOUT_MS}") bash /workspace/scripts/run-digest-test-via-cron.sh"
