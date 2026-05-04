#!/bin/bash
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 ENV" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

bash "${SCRIPT_DIR}/gateway-command.sh" "$1" \
  env \
  TEST_TO="${GMAIL_TEST_TO:-recipient@example.com}" \
  TEST_SUBJECT="${GMAIL_TEST_SUBJECT:-Runtime Gmail send test}" \
  bash -lc 'printf "Runtime Gmail send test\n" | gog gmail send --account "${GOG_ACCOUNT:?missing GOG_ACCOUNT}" --to "$TEST_TO" --subject "$TEST_SUBJECT" --body-file=-'
