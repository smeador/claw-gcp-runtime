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
  'gog gmail search "newer_than:1d" --account "${GOG_ACCOUNT:?missing GOG_ACCOUNT}" --plain'
