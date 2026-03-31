#!/bin/bash
set -euo pipefail

usage() {
  echo "Usage: $0 [DEST_DIR]" >&2
  echo "   or: $0 VM_NAME PROJECT_ID ZONE [DEST_DIR]" >&2
}

case $# in
  0)
    VM_NAME="${VM_NAME:-}"
    PROJECT_ID="${PROJECT_ID:-}"
    ZONE="${ZONE:-}"
    DEST_DIR="./workspace/.tmp/cloud-session-logs"
    ;;
  1)
    VM_NAME="${VM_NAME:-}"
    PROJECT_ID="${PROJECT_ID:-}"
    ZONE="${ZONE:-}"
    DEST_DIR="$1"
    ;;
  3)
    VM_NAME="$1"
    PROJECT_ID="$2"
    ZONE="$3"
    DEST_DIR="./workspace/.tmp/cloud-session-logs"
    ;;
  4)
    VM_NAME="$1"
    PROJECT_ID="$2"
    ZONE="$3"
    DEST_DIR="$4"
    ;;
  *)
    usage
    exit 1
    ;;
esac

if [ -z "${VM_NAME}" ] || [ -z "${PROJECT_ID}" ] || [ -z "${ZONE}" ]; then
  echo "Missing required cloud settings. Set VM_NAME, PROJECT_ID, and ZONE in your environment or pass them explicitly." >&2
  usage
  exit 1
fi

REMOTE_SESSIONS_DIR="/opt/openclaw/state/home/agents/main/sessions"
STAMP="$(date -u +%Y-%m-%dT%H-%M-%SZ)"
LOCAL_DIR="${DEST_DIR%/}/${STAMP}"
REMOTE_ARCHIVE="/tmp/openclaw-sessions-${STAMP}.tgz"

mkdir -p "${LOCAL_DIR}"

echo "Creating session archive on ${VM_NAME}..."
gcloud compute ssh "${VM_NAME}" \
  --project "${PROJECT_ID}" \
  --zone "${ZONE}" \
  --tunnel-through-iap \
  --command "sudo bash -lc 'tar -czf \"${REMOTE_ARCHIVE}\" -C \"${REMOTE_SESSIONS_DIR}\" . && chmod 644 \"${REMOTE_ARCHIVE}\"'"

echo "Downloading session archive to ${LOCAL_DIR}..."
gcloud compute scp \
  --project "${PROJECT_ID}" \
  --zone "${ZONE}" \
  --tunnel-through-iap \
  "${VM_NAME}:${REMOTE_ARCHIVE}" \
  "${LOCAL_DIR}/sessions.tgz"

echo "Extracting locally..."
tar -xzf "${LOCAL_DIR}/sessions.tgz" -C "${LOCAL_DIR}"

echo "Downloaded session logs to ${LOCAL_DIR}"
echo "Remote archive retained at ${REMOTE_ARCHIVE}"
echo "Files:"
find "${LOCAL_DIR}" -maxdepth 1 -type f | sort
