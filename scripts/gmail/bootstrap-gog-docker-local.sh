#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../.."

ACCOUNT_EMAIL="${1:-${GOG_ACCOUNT:-pip@meador.me}}"
SERVICE_ACCOUNT_KEY_PATH="${2:-}"
COMPOSE_FILE="docker/compose.local.yml"

if [ -z "${SERVICE_ACCOUNT_KEY_PATH}" ]; then
  echo "Usage: $0 ACCOUNT_EMAIL SERVICE_ACCOUNT_KEY_PATH" >&2
  exit 1
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "docker CLI not found on PATH." >&2
  exit 1
fi

if [ ! -f "${SERVICE_ACCOUNT_KEY_PATH}" ]; then
  echo "Service account key not found: ${SERVICE_ACCOUNT_KEY_PATH}" >&2
  exit 1
fi

echo "Ensuring local Docker gateway is running..."
docker compose -f "${COMPOSE_FILE}" up -d openclaw-gateway >/dev/null

CONTAINER_ID="$(docker compose -f "${COMPOSE_FILE}" ps -q openclaw-gateway)"
if [ -z "${CONTAINER_ID}" ]; then
  echo "openclaw-gateway container is not running." >&2
  exit 1
fi

echo "Copying Gmail service account key into the container..."
docker cp "${SERVICE_ACCOUNT_KEY_PATH}" "${CONTAINER_ID}:/home/node/.openclaw/gog-service-account-bootstrap.json"

docker compose -f "${COMPOSE_FILE}" exec -T --user root openclaw-gateway bash -lc '
  set -euo pipefail
  chown node:node /home/node/.openclaw/gog-service-account-bootstrap.json
  chmod 600 /home/node/.openclaw/gog-service-account-bootstrap.json
'

docker compose -f "${COMPOSE_FILE}" exec -T openclaw-gateway bash -lc "
  set -euo pipefail
  gog auth service-account set '${ACCOUNT_EMAIL}' --key /home/node/.openclaw/gog-service-account-bootstrap.json >/dev/null
  rm -f /home/node/.openclaw/gog-service-account-bootstrap.json
  gog auth service-account status '${ACCOUNT_EMAIL}' --plain
"

echo
echo "Docker Gmail service-account bootstrap complete for ${ACCOUNT_EMAIL}."
echo "Next tests:"
echo "docker compose -f ${COMPOSE_FILE} exec openclaw-gateway gog gmail search 'newer_than:1d' --account ${ACCOUNT_EMAIL}"
echo "docker compose -f ${COMPOSE_FILE} exec openclaw-gateway openclaw agent --agent main --message 'Run pip-newsletter-digest now in test mode.'"
