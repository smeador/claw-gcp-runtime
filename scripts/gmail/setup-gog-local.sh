#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ] || [ $# -gt 2 ]; then
  echo "Usage: $0 EMAIL_ADDRESS [GCP_PROJECT_ID]" >&2
  exit 1
fi

EMAIL_ADDRESS="$1"
PROJECT_ID="${2:-}"

if ! command -v openclaw >/dev/null 2>&1; then
  echo "openclaw CLI not found on PATH." >&2
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud CLI not found on PATH." >&2
  exit 1
fi

if [ -n "${PROJECT_ID}" ]; then
  gcloud config set project "${PROJECT_ID}" >/dev/null
fi

echo "Starting OpenClaw Gmail webhook setup for ${EMAIL_ADDRESS}..."
echo "Follow the interactive prompts to complete gog/Gmail PubSub onboarding."

openclaw webhooks gmail setup --account "${EMAIL_ADDRESS}"

echo
echo "Setup complete. Verify with:"
echo "  openclaw config get hooks.gmail"
echo "Then start/restart your local gateway."
