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

jq -s '.[0] * .[1]' \
  config/openclaw.cloud.json5.example \
  <(printf '%s\n' "${SECRET_JSON}") \
  > "${RUNTIME_DIR}/openclaw.json"

chmod 644 "${RUNTIME_DIR}/openclaw.json"
