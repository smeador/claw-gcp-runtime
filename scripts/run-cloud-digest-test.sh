#!/bin/bash
set -euo pipefail

test -n "${VM_NAME:-}"
test -n "${PROJECT_ID:-}"
test -n "${ZONE:-}"

MESSAGE="${DIGEST_MESSAGE:-Run pip-newsletter-digest now in test mode.}"
TIMEOUT_MS="${DIGEST_TEST_TIMEOUT_MS:-600000}"

REMOTE_INNER="$(python3 - "$MESSAGE" "$TIMEOUT_MS" <<'PY'
import shlex
import sys

message = sys.argv[1]
timeout_ms = sys.argv[2]
cmd = (
    "cd /opt/openclaw/app && "
    "docker-compose --env-file config/docker.build.env "
    "-f docker/compose.cloud.yml exec openclaw-gateway "
    "bash -lc "
    + shlex.quote(
        "DIGEST_MESSAGE="
        + shlex.quote(message)
        + " DIGEST_TEST_TIMEOUT_MS="
        + shlex.quote(timeout_ms)
        + " bash /workspace/scripts/run-digest-test-via-cron.sh"
    )
)
print(cmd)
PY
)"

gcloud compute ssh "$VM_NAME" \
  --project="$PROJECT_ID" \
  --zone="$ZONE" \
  --tunnel-through-iap \
  -- -t "sudo bash -lc $(printf '%q' "$REMOTE_INNER")"
