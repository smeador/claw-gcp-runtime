#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f config/docker.local.env ]; then
  mkdir -p config
  PASSWORD="$(python3 - <<'PY'
import secrets
import string

alphabet = string.ascii_letters + string.digits
print(''.join(secrets.choice(alphabet) for _ in range(32)))
PY
)"
  cat > config/docker.local.env <<EOF
GOG_ACCOUNT=pip@meador.me
GOG_KEYRING_BACKEND=file
GOG_KEYRING_PASSWORD=${PASSWORD}
EOF
  chmod 600 config/docker.local.env
fi

bash ./scripts/render-openclaw-local.sh
docker compose -f docker/compose.local.yml build openclaw-gateway openclaw-cli

# Match upstream docker-setup.sh behavior: eagerly seed OpenClaw state paths
# and fix ownership before onboarding or starting the gateway.
docker compose -f docker/compose.local.yml run --rm --no-deps --user root --entrypoint bash openclaw-gateway -lc '
  set -euo pipefail
  mkdir -p \
    /home/node/.openclaw/identity \
    /home/node/.openclaw/agents/main/agent \
    /home/node/.openclaw/agents/main/sessions \
    /workspace/.openclaw \
    /workspace/.tmp \
    /workspace/memory
  chown -R node:node /home/node/.openclaw /workspace/.openclaw /workspace/.tmp /workspace/memory
'
