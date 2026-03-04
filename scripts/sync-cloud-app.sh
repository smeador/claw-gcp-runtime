#!/bin/bash
set -euo pipefail

if [ $# -ne 3 ]; then
  echo "Usage: $0 VM_NAME PROJECT_ID ZONE" >&2
  exit 1
fi

VM_NAME="$1"
PROJECT_ID="$2"
ZONE="$3"
REMOTE_APP_ROOT="${OPENCLAW_APP_ROOT:-/opt/openclaw/app}"

gcloud compute ssh "${VM_NAME}" \
  --project "${PROJECT_ID}" \
  --zone "${ZONE}" \
  --tunnel-through-iap \
  --command "sudo install -d -o \$USER -g \$USER -m 0750 '${REMOTE_APP_ROOT}'"

gcloud compute scp --recurse \
  --project "${PROJECT_ID}" \
  --zone "${ZONE}" \
  --tunnel-through-iap \
  docker config workspace scripts "${VM_NAME}:${REMOTE_APP_ROOT}/"
