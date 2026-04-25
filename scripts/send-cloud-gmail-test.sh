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
  env \
  TEST_TO="${GMAIL_TEST_TO:-recipient@example.com}" \
  TEST_SUBJECT="${GMAIL_TEST_SUBJECT:-Runtime cloud Gmail send test}" \
  bash \
  -lc \
  'printf "Cloud Gmail send test\n" | gog gmail send --account "${GOG_ACCOUNT:?missing GOG_ACCOUNT}" --to "$TEST_TO" --subject "$TEST_SUBJECT" --body-file=-'
