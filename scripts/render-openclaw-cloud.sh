#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 SECRET_NAME" >&2
  exit 1
fi

SECRET_NAME="$1"
DEPLOY_ROOT="${OPENCLAW_DEPLOY_ROOT:-/opt/openclaw}"
RUNTIME_DIR="${DEPLOY_ROOT}/state/runtime"
PROJECT_ID="${GOOGLE_CLOUD_PROJECT:-$(curl -fsS -H 'Metadata-Flavor: Google' http://metadata.google.internal/computeMetadata/v1/project/project-id)}"

mkdir -p "${RUNTIME_DIR}"

ACCESS_TOKEN="$(
  curl -fsS \
    -H 'Metadata-Flavor: Google' \
    http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token \
  | jq -r '.access_token'
)"

SECRET_JSON="$(
  curl -fsS \
    -H "Authorization: Bearer ${ACCESS_TOKEN}" \
    "https://secretmanager.googleapis.com/v1/projects/${PROJECT_ID}/secrets/${SECRET_NAME}/versions/latest:access" \
  | jq -r '.payload.data' \
  | tr '_-' '/+' \
  | base64 --decode
)"

cd "$(dirname "$0")/.."
node scripts/render-docker-build-env.mjs --output config/docker.build.env
node scripts/render-runtime-env.mjs \
  --json "${SECRET_JSON}" \
  --output "${RUNTIME_DIR}/runtime.env"
node scripts/render-gog-service-account-key.mjs \
  --json "${SECRET_JSON}" \
  --account "automation@example.com" \
  --output "${RUNTIME_DIR}/gog-service-account.json"

node scripts/render-openclaw-config.mjs \
  --template config/openclaw.cloud.json5.example \
  --output "${RUNTIME_DIR}/openclaw.json" \
  --gcp-secret-json "${SECRET_JSON}"

chmod 600 "${RUNTIME_DIR}/openclaw.json"
chown 1000:1000 "${RUNTIME_DIR}/openclaw.json"

if [ -f "${RUNTIME_DIR}/runtime.env" ]; then
  chmod 600 "${RUNTIME_DIR}/runtime.env"
  chown 1000:1000 "${RUNTIME_DIR}/runtime.env"
fi

if [ -f "${RUNTIME_DIR}/gog-service-account.json" ]; then
  chmod 600 "${RUNTIME_DIR}/gog-service-account.json"
  chown 1000:1000 "${RUNTIME_DIR}/gog-service-account.json"
fi
