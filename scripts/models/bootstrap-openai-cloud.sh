#!/bin/bash
set -euo pipefail

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  echo "Usage: $0 VM_NAME PROJECT_ID ZONE [PROVIDER]" >&2
  exit 1
fi

VM_NAME="$1"
PROJECT_ID="$2"
ZONE="$3"
PROVIDER="${4:-openai}"
REMOTE_APP_ROOT="${OPENCLAW_APP_ROOT:-/opt/openclaw/app}"

echo "Bootstrapping ${PROVIDER} auth inside cloud runtime state..."
echo "Paste the token when prompted. This updates cloud /home/node/.openclaw only."

gcloud compute ssh "${VM_NAME}" \
  --project "${PROJECT_ID}" \
  --zone "${ZONE}" \
  --tunnel-through-iap \
  --command "cd '${REMOTE_APP_ROOT}' && docker compose -f docker/compose.cloud.yml exec openclaw-gateway openclaw models auth paste-token --provider '${PROVIDER}'"
