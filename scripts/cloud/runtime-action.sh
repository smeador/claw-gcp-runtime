#!/bin/bash
set -euo pipefail

if [ $# -ne 5 ]; then
  echo "Usage: $0 ACTION VM_NAME PROJECT_ID ZONE SECRET_NAME" >&2
  exit 1
fi

ACTION="$1"
VM_NAME="$2"
PROJECT_ID="$3"
ZONE="$4"
SECRET_NAME="$5"
REMOTE_APP_ROOT="${OPENCLAW_APP_ROOT:-/opt/openclaw/app}"
REMOTE_DEPLOY_ROOT="${OPENCLAW_DEPLOY_ROOT:-/opt/openclaw}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

case "${ACTION}" in
  deploy|rebuild)
    bash "${SCRIPT_DIR}/sync-app.sh" "${VM_NAME}" "${PROJECT_ID}" "${ZONE}"
    gcloud compute ssh "${VM_NAME}" \
      --project "${PROJECT_ID}" \
      --zone "${ZONE}" \
      --tunnel-through-iap \
      --command "sudo bash -lc 'cd \"${REMOTE_APP_ROOT}\" && bash ./scripts/cloud/install-host.sh'"
    ;;
  restart)
    ;;
  *)
    echo "Unsupported cloud runtime action: ${ACTION}" >&2
    exit 1
    ;;
esac

VM_NAME="${VM_NAME}" \
PROJECT_ID="${PROJECT_ID}" \
ZONE="${ZONE}" \
OPENCLAW_APP_ROOT="${REMOTE_APP_ROOT}" \
bash "${SCRIPT_DIR}/ssh-app.sh" \
  env \
  OPENCLAW_APP_ROOT="${REMOTE_APP_ROOT}" \
  OPENCLAW_DEPLOY_ROOT="${REMOTE_DEPLOY_ROOT}" \
  bash ./scripts/runtime/lifecycle.sh cloud "${ACTION}" "${SECRET_NAME}"
