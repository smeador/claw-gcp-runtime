#!/bin/bash
set -euo pipefail

if [ $# -lt 3 ] || [ $# -gt 4 ]; then
  echo "Usage: $0 VM_NAME PROJECT_ID ZONE [PROVIDER]" >&2
  exit 1
fi

VM_NAME="$1"
PROJECT_ID="$2"
ZONE="$3"
PROVIDER="${4:-openai}"
REMOTE_APP_ROOT="${OPENCLAW_APP_ROOT:-/opt/openclaw/app}"

cat <<EOF
Cloud model auth is now secret-driven.

Set the API key in config/secrets.cloud.json under:
  auth.profiles.<profile>.apiKey

Then push the updated secret payload and redeploy:
  bash ./scripts/push-cloud-runtime-secret.sh SECRET_NAME PROJECT_ID [config/secrets.cloud.json]
  bash ./scripts/deploy-cloud.sh ${VM_NAME} ${PROJECT_ID} ${ZONE} SECRET_NAME

This keeps cloud provider auth in rendered runtime env instead of interactive
runtime state bootstrap.
EOF

if [ "${PROVIDER}" = "openrouter" ]; then
  echo
  echo "For provider '${PROVIDER}', the rendered runtime env will use OPENROUTER_API_KEY."
elif [ "${PROVIDER}" != "openai" ]; then
  echo
  echo "Note: provider '${PROVIDER}' may need a provider-specific env var shape."
fi
