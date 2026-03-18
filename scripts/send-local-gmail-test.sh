#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

docker compose --env-file config/docker.build.env -f docker/compose.local.yml exec -T openclaw-gateway \
  bash -lc "printf 'Local Gmail send test\n' | gog gmail send --account pip@meador.me --to '${GMAIL_TEST_TO:-sean@meador.me}' --subject '${GMAIL_TEST_SUBJECT:-Pip Local Gmail send test}' --body-file=-"
