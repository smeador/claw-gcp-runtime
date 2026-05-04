#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 SKILL_NAME" >&2
  exit 1
fi

test -n "${VM_NAME:-}"
test -n "${PROJECT_ID:-}"
test -n "${ZONE:-}"

SKILL_NAME="$1"
RUNNER_PATH="$(node ./scripts/runtime/resolve-skill-test-runner.mjs "${SKILL_NAME}")"
CONTAINER_RUNNER_PATH="/opt/agent-lab/integrations/${RUNNER_PATH#.runtime/integrations/}"

REMOTE_INNER="$(python3 - "$SKILL_NAME" "$CONTAINER_RUNNER_PATH" "${SKILL_TEST_MESSAGE:-}" "${SKILL_TEST_TIMEOUT_MS:-}" <<'PY'
import shlex
import sys

skill_name = sys.argv[1]
runner_path = sys.argv[2]
skill_test_message = sys.argv[3]
timeout_ms = sys.argv[4]
exec_parts = []
if skill_test_message:
    exec_parts.append("-e " + shlex.quote("SKILL_TEST_MESSAGE=" + skill_test_message))
if timeout_ms:
    exec_parts.append("-e " + shlex.quote("SKILL_TEST_TIMEOUT_MS=" + timeout_ms))
cmd = (
    "cd /opt/openclaw/app && "
    "docker-compose --env-file config/docker.build.env "
    "-f docker/compose.cloud.yml exec "
    + (" ".join(exec_parts) + " " if exec_parts else "")
    + "openclaw-gateway "
    "bash -lc "
    + shlex.quote("bash " + runner_path + " " + skill_name)
)
print(cmd)
PY
)"

gcloud compute ssh "$VM_NAME" \
  --project="$PROJECT_ID" \
  --zone="$ZONE" \
  --tunnel-through-iap \
  -- -t "sudo bash -lc $(printf '%q' "$REMOTE_INNER")"
