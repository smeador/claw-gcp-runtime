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
LOCAL_ARCHIVE="$(mktemp /tmp/agent-lab-cloud-sync.XXXXXX.tar.gz)"
REMOTE_ARCHIVE="/tmp/agent-lab-cloud-sync.tar.gz"

cleanup() {
  rm -f "${LOCAL_ARCHIVE}"
}

trap cleanup EXIT

cd "$(dirname "$0")/.."

node ./scripts/stage-workspace-integrations.mjs

export COPYFILE_DISABLE=1

EXCLUDES=(
  --exclude='./workspace/.openclaw'
  --exclude='./workspace/.tmp'
  --exclude='./workspace/tmp'
  --exclude='./config/secrets.local.json'
  --exclude='./config/secrets.cloud.json'
  --exclude='./config/docker.local.env'
  --exclude='./config/rendered'
  --exclude='__pycache__'
  --exclude='*.pyc'
  --exclude='.DS_Store'
  --exclude='._*'
)

tar \
  --no-xattrs \
  "${EXCLUDES[@]}" \
  -czf "${LOCAL_ARCHIVE}" \
  docker config workspace scripts .runtime versions.json package.json package-lock.json

gcloud compute ssh "${VM_NAME}" \
  --project "${PROJECT_ID}" \
  --zone "${ZONE}" \
  --tunnel-through-iap \
  --command "sudo install -d -m 0750 '${REMOTE_APP_ROOT}' && sudo chown \$USER:\$USER '${REMOTE_APP_ROOT}'"

gcloud compute scp \
  --project "${PROJECT_ID}" \
  --zone "${ZONE}" \
  --tunnel-through-iap \
  "${LOCAL_ARCHIVE}" "${VM_NAME}:${REMOTE_ARCHIVE}"

gcloud compute ssh "${VM_NAME}" \
  --project "${PROJECT_ID}" \
  --zone "${ZONE}" \
  --tunnel-through-iap \
  --command "sudo bash -lc 'set -euo pipefail; mkdir -p \"${REMOTE_APP_ROOT}\" && tar -xzf \"${REMOTE_ARCHIVE}\" -C \"${REMOTE_APP_ROOT}\" && rm -f \"${REMOTE_ARCHIVE}\" && mkdir -p \"${REMOTE_APP_ROOT}/workspace/.openclaw\" \"${REMOTE_APP_ROOT}/workspace/memory\"'"
