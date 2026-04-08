#!/bin/bash
set -euo pipefail

test -n "${VM_NAME:-}"
test -n "${PROJECT_ID:-}"
test -n "${ZONE:-}"

MESSAGE="${DIGEST_MESSAGE:-Run pip-newsletter-digest now in test mode.}"

REMOTE_INNER="$(python3 - "$MESSAGE" <<'PY'
import shlex
import sys

message = sys.argv[1]
cmd = (
    "cd /opt/openclaw/app && "
    "docker-compose --env-file config/docker.build.env "
    "-f docker/compose.cloud.yml exec openclaw-gateway "
    "openclaw agent --agent main --message "
    + shlex.quote(message)
)
print(cmd)
PY
)"

gcloud compute ssh "$VM_NAME" \
  --project="$PROJECT_ID" \
  --zone="$ZONE" \
  --tunnel-through-iap \
  -- -t "sudo bash -lc $(printf '%q' "$REMOTE_INNER")"
