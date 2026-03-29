#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

docker compose --env-file config/docker.build.env -f docker/compose.local.yml exec -T openclaw-gateway \
  openclaw agent --agent main --message "${DIGEST_MESSAGE:-Re-read the pip-newsletter-digest skill from disk, then run pip-newsletter-digest now in test mode from scratch.}"
