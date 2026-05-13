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
SECRET_FILE="$(mktemp "${RUNTIME_DIR}/openclaw-secret.XXXXXX.json")"
chmod 600 "${SECRET_FILE}"

cleanup() {
  rm -f "${SECRET_FILE}"
}

trap cleanup EXIT

ACCESS_TOKEN="$(
  curl -fsS \
    -H 'Metadata-Flavor: Google' \
    http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/token \
  | jq -r '.access_token'
)"

curl -fsS \
  -H "Authorization: Bearer ${ACCESS_TOKEN}" \
  "https://secretmanager.googleapis.com/v1/projects/${PROJECT_ID}/secrets/${SECRET_NAME}/versions/latest:access" \
| jq -r '.payload.data' \
| tr '_-' '/+' \
| base64 --decode > "${SECRET_FILE}"

cd "$(dirname "$0")/.."
node scripts/render-docker-build-env.mjs --output config/docker.build.env
node scripts/render-runtime-env.mjs \
  --secrets "${SECRET_FILE}" \
  --output "${RUNTIME_DIR}/runtime.env"
node scripts/render-gog-service-account-key.mjs \
  --secrets "${SECRET_FILE}" \
  --output "${RUNTIME_DIR}/gog-service-account.json"

cp config/exec-approvals.runtime.json "${RUNTIME_DIR}/exec-approvals.json"

node scripts/render-openclaw-config.mjs \
  --template config/openclaw.cloud.example.json5 \
  --output "${RUNTIME_DIR}/openclaw.json" \
  --secret-file "${SECRET_FILE}"

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

if [ -f "${RUNTIME_DIR}/exec-approvals.json" ]; then
  chmod 600 "${RUNTIME_DIR}/exec-approvals.json"
  chown 1000:1000 "${RUNTIME_DIR}/exec-approvals.json"
fi
