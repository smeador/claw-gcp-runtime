#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../.."
node ./scripts/render-docker-build-env.mjs --output config/docker.build.env >/dev/null

QUIT_TAILSCALE_APP=1
if [ "${1:-}" = "--keep-tailscale-app" ]; then
  QUIT_TAILSCALE_APP=0
fi

echo "Stopping local Docker OpenClaw services..."
if command -v docker >/dev/null 2>&1; then
  docker compose --env-file config/docker.build.env -f docker/compose.local.yml down --remove-orphans >/dev/null 2>&1 || true
fi

echo "Stopping OpenClaw gateway service..."
if command -v openclaw >/dev/null 2>&1; then
  openclaw gateway stop >/dev/null 2>&1 || true
fi

echo "Killing remaining OpenClaw local processes..."
pkill -f "openclaw.*gateway" >/dev/null 2>&1 || true
pkill -f "openclaw webhooks gmail run" >/dev/null 2>&1 || true
pkill -f "openclaw.*cron" >/dev/null 2>&1 || true

echo "Bringing Tailscale down..."
if command -v tailscale >/dev/null 2>&1; then
  tailscale down >/dev/null 2>&1 || true
fi

if [ "${QUIT_TAILSCALE_APP}" -eq 1 ]; then
  echo "Quitting Tailscale app..."
  if command -v osascript >/dev/null 2>&1; then
    osascript -e 'quit app "Tailscale"' >/dev/null 2>&1 || true
  fi
fi

echo "Local security shutdown complete."
