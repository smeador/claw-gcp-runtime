#!/bin/bash
set -euo pipefail

if [ $# -ne 3 ]; then
  echo "Usage: $0 VM_NAME PROJECT_ID ZONE" >&2
  exit 1
fi

VM_NAME="$1"
PROJECT_ID="$2"
ZONE="$3"

LOCAL_PORT="${LOCAL_PORT:-18789}"
REMOTE_PORT="${REMOTE_PORT:-18789}"

echo "Opening tunnel: http://127.0.0.1:${LOCAL_PORT} -> ${VM_NAME}:127.0.0.1:${REMOTE_PORT}"
echo "Keep this session open while using the remote gateway."

gcloud compute ssh "${VM_NAME}" \
  --project "${PROJECT_ID}" \
  --zone "${ZONE}" \
  --tunnel-through-iap \
  -- -N -L "${LOCAL_PORT}:127.0.0.1:${REMOTE_PORT}"
