#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../.."

ACCOUNT_EMAIL="${1:-${GOG_ACCOUNT:-automation@example.com}}"
TMP_DIR="workspace/.tmp"
TOKEN_EXPORT="${TMP_DIR}/gog-token-export.json"
HOST_CREDENTIALS="${HOME}/Library/Application Support/gogcli/credentials.json"
NORMALIZED_CREDENTIALS="${TMP_DIR}/gog-credentials.normalized.json"
COMPOSE_FILE="docker/compose.local.yml"

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
  rm -f "${NORMALIZED_CREDENTIALS}"
}
trap cleanup EXIT

echo "Ensuring local Docker gateway is running..."
docker compose -f "${COMPOSE_FILE}" up -d openclaw-gateway >/dev/null

CONTAINER_ID="$(docker compose -f "${COMPOSE_FILE}" ps -q openclaw-gateway)"
if [ -z "${CONTAINER_ID}" ]; then
  echo "openclaw-gateway container is not running." >&2
  exit 1
fi

node - "${HOST_CREDENTIALS}" "${NORMALIZED_CREDENTIALS}" <<'NODE'
const fs = require("node:fs");

const [inputPath, outputPath] = process.argv.slice(2);
const raw = JSON.parse(fs.readFileSync(inputPath, "utf8"));

if (raw.installed || raw.web) {
  fs.writeFileSync(outputPath, JSON.stringify(raw, null, 2) + "\n");
  process.exit(0);
}

if (!raw.client_id || !raw.client_secret) {
  console.error("Unsupported credentials.json format.");
  process.exit(1);
}

const normalized = {
  installed: {
    client_id: raw.client_id,
    client_secret: raw.client_secret,
    auth_uri: "https://accounts.google.com/o/oauth2/auth",
    token_uri: "https://oauth2.googleapis.com/token",
    redirect_uris: [
      "http://localhost",
      "http://localhost:8080",
      "urn:ietf:wg:oauth:2.0:oob"
    ]
  }
};

fs.writeFileSync(outputPath, JSON.stringify(normalized, null, 2) + "\n");
NODE

echo "Copying Gmail OAuth client credentials into the container..."
docker cp "${NORMALIZED_CREDENTIALS}" "${CONTAINER_ID}:/home/node/.openclaw/gog-credentials.json"

docker compose -f "${COMPOSE_FILE}" exec -T --user root openclaw-gateway bash -lc '
  set -euo pipefail
  chown node:node /home/node/.openclaw/gog-credentials.json
  chmod 600 /home/node/.openclaw/gog-credentials.json
'

docker compose -f "${COMPOSE_FILE}" exec -T openclaw-gateway bash -lc '
  set -euo pipefail
  gog auth keyring file >/dev/null
  gog auth credentials set /home/node/.openclaw/gog-credentials.json >/dev/null
  rm -f /home/node/.openclaw/gog-credentials.json
'

HOST_IMPORT_DONE=0
if command -v gog >/dev/null 2>&1; then
  if gog auth tokens export "${ACCOUNT_EMAIL}" --out "${TOKEN_EXPORT}" --overwrite >/dev/null 2>&1; then
    echo "Importing existing host Gmail token into the container..."
    docker cp "${TOKEN_EXPORT}" "${CONTAINER_ID}:/home/node/.openclaw/gog-token-export.json"
    docker compose -f "${COMPOSE_FILE}" exec -T --user root openclaw-gateway bash -lc '
      set -euo pipefail
      chown node:node /home/node/.openclaw/gog-token-export.json
      chmod 600 /home/node/.openclaw/gog-token-export.json
    '
    docker compose -f "${COMPOSE_FILE}" exec -T openclaw-gateway bash -lc '
      set -euo pipefail
      gog auth tokens import /home/node/.openclaw/gog-token-export.json >/dev/null
      rm -f /home/node/.openclaw/gog-token-export.json
    '
    HOST_IMPORT_DONE=1
  fi
fi

if [ "${HOST_IMPORT_DONE}" -eq 0 ]; then
  cat <<EOF
No exportable host Gmail refresh token was found for ${ACCOUNT_EMAIL}.
Falling back to interactive Docker-side auth.

gog will print a Google auth URL in the container. Open it in your browser,
complete consent for ${ACCOUNT_EMAIL}, then paste the redirect URL back into
the terminal when prompted.
EOF
  docker compose -f "${COMPOSE_FILE}" exec openclaw-gateway bash -lc "set -euo pipefail; gog auth add '${ACCOUNT_EMAIL}' --manual --services gmail --force-consent"
fi

echo
echo "Verifying Docker-side Gmail auth:"
docker compose -f "${COMPOSE_FILE}" exec -T openclaw-gateway bash -lc "set -euo pipefail; gog auth list --plain"

echo
echo "Docker Gmail bootstrap complete for ${ACCOUNT_EMAIL}."
echo "Next test:"
echo "docker compose -f ${COMPOSE_FILE} exec openclaw-gateway openclaw agent --agent main --message 'Run pip-newsletter-digest now in test mode.'"
