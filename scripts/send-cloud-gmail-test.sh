#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

bash ./scripts/cloud-ssh-app.sh \
  docker-compose \
  --env-file config/docker.build.env \
  -f docker/compose.cloud.yml \
  exec \
  -T \
  openclaw-gateway \
  bash \
  -lc \
  "printf 'Cloud Gmail send test\n' | gog gmail send --account automation@example.com --to '${GMAIL_TEST_TO:-user@example.com}' --subject '${GMAIL_TEST_SUBJECT:-Pip Cloud Gmail send test}' --body-file=-"
