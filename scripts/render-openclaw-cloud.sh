#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 SECRET_NAME" >&2
  exit 1
fi

SECRET_NAME="$1"
DEPLOY_ROOT="${OPENCLAW_DEPLOY_ROOT:-/opt/openclaw}"
RUNTIME_DIR="${DEPLOY_ROOT}/state/runtime"

mkdir -p "${RUNTIME_DIR}"

SECRET_JSON="$(gcloud secrets versions access latest --secret "${SECRET_NAME}")"

cd "$(dirname "$0")/.."
node scripts/render-openclaw-config.mjs \
  --template config/openclaw.cloud.json5.example \
  --output "${RUNTIME_DIR}/openclaw.json" \
  --gcp-secret-json "${SECRET_JSON}"
