#!/bin/bash
set -euo pipefail

if [ $# -ne 4 ]; then
  echo "Usage: $0 VM_NAME PROJECT_ID ZONE SECRET_NAME" >&2
  exit 1
fi

VM_NAME="$1"
PROJECT_ID="$2"
ZONE="$3"
SECRET_NAME="$4"
REMOTE_APP_ROOT="${OPENCLAW_APP_ROOT:-/opt/openclaw/app}"
REMOTE_DEPLOY_ROOT="${OPENCLAW_DEPLOY_ROOT:-/opt/openclaw}"

bash "$(dirname "$0")/sync-cloud-app.sh" "${VM_NAME}" "${PROJECT_ID}" "${ZONE}"

gcloud compute ssh "${VM_NAME}" \
  --project "${PROJECT_ID}" \
  --zone "${ZONE}" \
  --tunnel-through-iap \
  --command "cd '${REMOTE_APP_ROOT}' && bash ./scripts/install-cloud-host.sh && sudo OPENCLAW_APP_ROOT='${REMOTE_APP_ROOT}' OPENCLAW_DEPLOY_ROOT='${REMOTE_DEPLOY_ROOT}' bash ./scripts/run-cloud.sh '${SECRET_NAME}'"
