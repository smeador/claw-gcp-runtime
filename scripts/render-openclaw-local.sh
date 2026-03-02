#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p config/rendered

node scripts/render-openclaw-config.mjs \
  --template config/openclaw.container.json5.example \
  --output config/rendered/openclaw.json \
  --local-secrets config/secrets.local.json
