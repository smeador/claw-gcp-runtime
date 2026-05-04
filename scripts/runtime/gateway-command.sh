#!/bin/bash
set -euo pipefail

if [ $# -lt 2 ]; then
  echo "Usage: $0 ENV [--tty] COMMAND [ARGS...]" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "${SCRIPT_DIR}/../lib/runtime-common.sh"

ENV_NAME="$1"
shift

TTY=0
if [ "${1:-}" = "--tty" ]; then
  TTY=1
  shift
fi

runtime_init_env "${ENV_NAME}"

if [ "${TTY}" = "1" ]; then
  runtime_compose_cmd -f "${RUNTIME_COMPOSE_FILE}" exec openclaw-gateway "$@"
else
  runtime_compose_cmd -f "${RUNTIME_COMPOSE_FILE}" exec -T openclaw-gateway "$@"
fi
