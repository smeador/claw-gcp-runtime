#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 ENV" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "${SCRIPT_DIR}/gateway-command.sh" "$1" \
  bash -lc 'gog gmail search "newer_than:1d" --account "${GOG_ACCOUNT:?missing GOG_ACCOUNT}" --plain'
