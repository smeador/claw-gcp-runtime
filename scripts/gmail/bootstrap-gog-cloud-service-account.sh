#!/bin/bash
set -euo pipefail

if [ $# -lt 4 ] || [ $# -gt 5 ]; then
  echo "Usage: $0 VM_NAME PROJECT_ID ZONE SERVICE_ACCOUNT_KEY_PATH [ACCOUNT_EMAIL]" >&2
  exit 1
fi

VM_NAME="$1"
PROJECT_ID="$2"
ZONE="$3"
SERVICE_ACCOUNT_KEY_PATH="$4"
ACCOUNT_EMAIL="${5:-${GOG_ACCOUNT:-gmail-workflow@example.com}}"
REMOTE_APP_ROOT="${OPENCLAW_APP_ROOT:-/opt/openclaw/app}"
REMOTE_DEPLOY_ROOT="${OPENCLAW_DEPLOY_ROOT:-/opt/openclaw}"
REMOTE_TMP_KEY="/tmp/gog-service-account-bootstrap.json"

if [ ! -f "${SERVICE_ACCOUNT_KEY_PATH}" ]; then
  echo "Service account key not found: ${SERVICE_ACCOUNT_KEY_PATH}" >&2
  exit 1
fi

gcloud compute scp "${SERVICE_ACCOUNT_KEY_PATH}" "${VM_NAME}:${REMOTE_TMP_KEY}" \
  --project "${PROJECT_ID}" \
  --zone "${ZONE}" \
  --tunnel-through-iap

gcloud compute ssh "${VM_NAME}" \
  --project "${PROJECT_ID}" \
  --zone "${ZONE}" \
  --tunnel-through-iap \
  --command "set -euo pipefail; cd '${REMOTE_APP_ROOT}' && sudo mkdir -p '${REMOTE_DEPLOY_ROOT}/state/home' && sudo cp '${REMOTE_TMP_KEY}' '${REMOTE_DEPLOY_ROOT}/state/home/gog-service-account-bootstrap.json' && sudo chown 1000:1000 '${REMOTE_DEPLOY_ROOT}/state/home/gog-service-account-bootstrap.json' && sudo chmod 600 '${REMOTE_DEPLOY_ROOT}/state/home/gog-service-account-bootstrap.json' && docker compose --env-file config/docker.build.env -f docker/compose.cloud.yml exec -T openclaw-gateway bash -lc \"set -euo pipefail; gog auth service-account set '${ACCOUNT_EMAIL}' --key /home/node/.openclaw/gog-service-account-bootstrap.json >/dev/null; rm -f /home/node/.openclaw/gog-service-account-bootstrap.json; gog auth service-account status '${ACCOUNT_EMAIL}' --plain\" && rm -f '${REMOTE_TMP_KEY}'"

echo
echo "Cloud Gmail service-account bootstrap complete for ${ACCOUNT_EMAIL}."
