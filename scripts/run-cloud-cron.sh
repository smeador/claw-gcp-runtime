#!/bin/bash
set -euo pipefail

JOB_NAME="${1:-pip-newsletter-digest-morning}"

compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    docker compose --env-file config/docker.build.env "$@"
  else
    docker-compose --env-file config/docker.build.env "$@"
  fi
}

APP_ROOT="${OPENCLAW_APP_ROOT:-/opt/openclaw/app}"
cd "${APP_ROOT}"

job_id="$(
  compose_cmd -f docker/compose.cloud.yml exec -T openclaw-gateway \
    openclaw cron list --all --json \
    | jq -r --arg name "${JOB_NAME}" '.jobs[] | select(.name == $name) | .id' \
    | head -n 1
)"

if [ -z "${job_id}" ]; then
  echo "Cloud cron job not found: ${JOB_NAME}" >&2
  exit 1
fi

compose_cmd -f docker/compose.cloud.yml exec -T openclaw-gateway \
  openclaw cron run "${job_id}"
