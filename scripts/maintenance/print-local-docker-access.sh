#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/../.."
node ./scripts/render-docker-build-env.mjs --output config/docker.build.env >/dev/null

url="http://127.0.0.1:18790/overview"
token=""

if docker compose --env-file config/docker.build.env -f docker/compose.local.yml ps --status running openclaw-gateway >/dev/null 2>&1; then
  token="$(docker compose --env-file config/docker.build.env -f docker/compose.local.yml exec -T openclaw-gateway bash -lc 'jq -r ".gateway.auth.token // empty" /home/node/.openclaw/openclaw.json' 2>/dev/null || true)"
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
  bash ./scripts/runtime/shell-gateway.sh local

Then run these commands inside the container:
- Inspect Docker-local provider env wiring:
  env | rg 'OPENAI_API_KEY|GOG_ACCOUNT'

Steady-state operations:
- Rotate the Docker-local gateway token:
  1. Edit config/secrets.local.json
  2. claw-runtime local restart
- Add or update reviewed skills:
  edit the source integration repo declared in workspace/integrations.json and then rerun:
  claw-runtime local restart
- Add or update reviewed hooks:
  edit config/openclaw.container.example.json5 or the relevant repo-managed workspace files, then rerun:
  claw-runtime local restart
EOF
