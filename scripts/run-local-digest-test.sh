#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

docker compose --env-file config/docker.build.env -f docker/compose.local.yml exec -T openclaw-gateway \
  openclaw agent --agent main --message "${DIGEST_MESSAGE:-/reset Use /workspace/skills/pip-newsletter-digest/SKILL.md directly and run pip-newsletter-digest now in test mode from scratch. Do not scan the workspace for other skills before starting.}"
