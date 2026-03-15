#!/bin/bash
set -euo pipefail

if ! command -v openclaw >/dev/null 2>&1; then
  echo "openclaw CLI not found on PATH." >&2
  exit 1
fi

echo "Running OpenClaw Gmail webhook watcher..."
echo "Use this only in manual-watcher mode."
echo "If gateway-managed watcher is enabled, do not run this in parallel."

openclaw webhooks gmail run
