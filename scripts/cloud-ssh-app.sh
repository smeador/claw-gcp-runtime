#!/bin/bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 [--tty] COMMAND [ARGS...]" >&2
  exit 1
fi

TTY_FLAG=0
if [ "${1}" = "--tty" ]; then
  TTY_FLAG=1
  shift
fi

if [ -z "${VM_NAME:-}" ] || [ -z "${PROJECT_ID:-}" ] || [ -z "${ZONE:-}" ]; then
  echo "Missing required cloud settings. Set VM_NAME, PROJECT_ID, and ZONE." >&2
  exit 1
fi

REMOTE_APP_ROOT="${OPENCLAW_APP_ROOT:-/opt/openclaw/app}"

quote_args() {
  local quoted=()
  local arg
  for arg in "$@"; do
    quoted+=("$(printf "%q" "${arg}")")
  done
  printf "%s" "${quoted[*]}"
}

REMOTE_CMD="cd ${REMOTE_APP_ROOT@Q} && $(quote_args "$@")"

SSH_ARGS=(
  compute ssh "${VM_NAME}"
  --project "${PROJECT_ID}"
  --zone "${ZONE}"
  --tunnel-through-iap
)

if [ "${TTY_FLAG}" = "1" ]; then
  gcloud "${SSH_ARGS[@]}" -- -t "sudo bash -lc $(printf "%q" "${REMOTE_CMD}")"
else
  gcloud "${SSH_ARGS[@]}" --command "sudo bash -lc $(printf "%q" "${REMOTE_CMD}")"
fi
