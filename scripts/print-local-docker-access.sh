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

Shell into the Docker-local gateway container:
  bash ./scripts/shell-local-gateway.sh

Then run these commands inside the container:
- Telegram pairing:
  openclaw pairing list telegram
  openclaw pairing approve telegram <CODE>
- Update provider auth with an interactive login flow:
  openclaw models auth login --provider openai
- Update provider auth with an API key:
  openclaw models auth paste-token --provider openai

Steady-state operations:
- Rotate the Docker-local gateway token:
  1. Edit config/secrets.local.json
  2. bash ./scripts/prepare-local-docker.sh
  3. docker compose -f docker/compose.local.yml up -d --force-recreate openclaw-gateway
- Add or update reviewed skills:
  edit workspace/skills/ and then rerun:
  bash ./scripts/prepare-local-docker.sh
  docker compose -f docker/compose.local.yml up -d --force-recreate openclaw-gateway
- Add or update reviewed hooks:
  edit config/openclaw.container.json5.example or the relevant repo-managed workspace files, then rerun:
  bash ./scripts/prepare-local-docker.sh
  docker compose -f docker/compose.local.yml up -d --force-recreate openclaw-gateway
EOF
