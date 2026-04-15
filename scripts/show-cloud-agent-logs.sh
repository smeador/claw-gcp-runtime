#!/bin/bash
set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo "Usage: $0 VM_NAME PROJECT_ID ZONE" >&2
  exit 1
fi

VM_NAME="$1"
PROJECT_ID="$2"
ZONE="$3"
TAIL_LINES="${TAIL_LINES:-120}"
AGENT_NAME="${AGENT_NAME:-main}"
SHOW_RUNTIME_LOG="${SHOW_RUNTIME_LOG:-0}"

format_arg() {
  printf "%q" "$1"
}

container_script='set -euo pipefail
SESSION_DIR="/home/node/.openclaw/agents/${AGENT_NAME}/sessions"
LATEST_SESSION="$(find "${SESSION_DIR}" -maxdepth 1 -type f -name "*.jsonl" ! -name "sessions.json" -print | xargs ls -1t 2>/dev/null | head -n 1 || true)"
LATEST_RUNTIME="$(find /tmp/openclaw-1000 -maxdepth 1 -type f -name "openclaw-*.log" -print | xargs ls -1t 2>/dev/null | head -n 1 || true)"
if [ -n "${LATEST_SESSION}" ]; then
  printf "Latest session activity: %s\n" "${LATEST_SESSION}"
  node /workspace/scripts/format-agent-session.mjs "${LATEST_SESSION}"
else
  printf "No session transcript found for agent %s.\n" "${AGENT_NAME}"
fi
if [ "${SHOW_RUNTIME_LOG}" = "1" ]; then
  printf "\n"
  if [ -n "${LATEST_RUNTIME}" ]; then
    printf "Latest runtime log: %s\n" "${LATEST_RUNTIME}"
    tail -n "${TAIL_LINES}" "${LATEST_RUNTIME}"
  else
    printf "No OpenClaw runtime log found under /tmp/openclaw-1000.\n"
  fi
fi'

remote_cmd="cd /opt/openclaw/app && docker-compose --env-file config/docker.build.env -f docker/compose.cloud.yml exec -T \
  -e TAIL_LINES=$(format_arg "${TAIL_LINES}") \
  -e AGENT_NAME=$(format_arg "${AGENT_NAME}") \
  -e SHOW_RUNTIME_LOG=$(format_arg "${SHOW_RUNTIME_LOG}") \
  openclaw-gateway bash -lc $(format_arg "${container_script}")"

gcloud compute ssh "${VM_NAME}" \
  --project="${PROJECT_ID}" \
  --zone="${ZONE}" \
  --tunnel-through-iap \
  --command "sudo bash -lc $(format_arg "${remote_cmd}")"
