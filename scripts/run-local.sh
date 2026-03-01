#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
docker compose -f docker/compose.local.yml up -d openclaw-gateway
