#!/bin/bash
set -euo pipefail

if [ $# -ne 3 ]; then
  echo "Usage: $0 VM_NAME PROJECT_ID ZONE" >&2
  exit 1
fi

VM_NAME="$1"
PROJECT_ID="$2"
ZONE="$3"

gcloud compute ssh "${VM_NAME}" \
  --project "${PROJECT_ID}" \
  --zone "${ZONE}" \
  --tunnel-through-iap \
  -- -t "cd /opt/openclaw/app && sudo docker-compose --env-file config/docker.build.env -f docker/compose.cloud.yml exec openclaw-gateway bash"
