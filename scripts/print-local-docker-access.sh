#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

url="http://127.0.0.1:18790/overview"
token=""

if docker compose -f docker/compose.local.yml ps --status running openclaw-gateway >/dev/null 2>&1; then
  token="$(docker compose -f docker/compose.local.yml exec -T openclaw-gateway bash -lc 'jq -r ".gateway.auth.token // empty" /home/node/.openclaw/openclaw.json' 2>/dev/null || true)"
fi

if [ -z "${token}" ] && [ -f config/rendered/openclaw.json ]; then
  token="$(jq -r '.gateway.auth.token // empty' config/rendered/openclaw.json 2>/dev/null || true)"
fi

cat <<EOF
Docker-local OpenClaw access
URL: ${url}

Gateway token:
${token:-<not found>}

Notes:
- Native local OpenClaw remains on http://127.0.0.1:18789
- Docker-local OpenClaw uses http://127.0.0.1:18790
- Approve device pairing against Docker-local runtime state, not host-native OpenClaw

Device pairing commands:
- List pending/paired devices:
  docker compose -f docker/compose.local.yml run --rm openclaw-cli devices list
- Approve a pending device:
  docker compose -f docker/compose.local.yml run --rm openclaw-cli devices approve

Auth/config commands:
- Targeted auth or provider setup refresh:
  docker compose -f docker/compose.local.yml run --rm openclaw-cli configure
- Fresh container onboarding:
  bash ./scripts/onboard-local-container.sh
EOF
