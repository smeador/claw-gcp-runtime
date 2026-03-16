#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../.."

ACCOUNT_EMAIL="${1:-automation@example.com}"
TMP_DIR="workspace/.tmp"
TOKEN_EXPORT="${TMP_DIR}/gog-token-export.json"
HOST_CREDENTIALS="${HOME}/Library/Application Support/gogcli/credentials.json"

if ! command -v gog >/dev/null 2>&1; then
  echo "gog CLI not found on PATH." >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI not found on PATH." >&2
  exit 1
fi

if [ ! -f "${HOST_CREDENTIALS}" ]; then
  echo "Host gog credentials file not found: ${HOST_CREDENTIALS}" >&2
  exit 1
fi

mkdir -p "${TMP_DIR}"
cleanup() {
  rm -f "${TOKEN_EXPORT}"
}
trap cleanup EXIT

gog auth tokens export "${ACCOUNT_EMAIL}" --out "${TOKEN_EXPORT}" --overwrite

CONTAINER_ID="$(docker compose -f docker/compose.local.yml ps -q openclaw-gateway)"
if [ -z "${CONTAINER_ID}" ]; then
  echo "openclaw-gateway container is not running." >&2
  exit 1
fi

docker cp "${HOST_CREDENTIALS}" "${CONTAINER_ID}:/home/node/.openclaw/gog-credentials.json"
docker cp "${TOKEN_EXPORT}" "${CONTAINER_ID}:/home/node/.openclaw/gog-token-export.json"

docker compose -f docker/compose.local.yml exec -T openclaw-gateway bash -lc '
  set -euo pipefail
  gog auth keyring file >/dev/null
  gog auth credentials set /home/node/.openclaw/gog-credentials.json >/dev/null
  gog auth tokens import /home/node/.openclaw/gog-token-export.json >/dev/null
  rm -f /home/node/.openclaw/gog-credentials.json /home/node/.openclaw/gog-token-export.json
  gog auth list --plain
'
