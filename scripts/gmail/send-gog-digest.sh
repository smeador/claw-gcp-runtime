#!/bin/bash
set -euo pipefail

if [ $# -lt 6 ]; then
  echo "Usage: $0 ACCOUNT_EMAIL TO_EMAIL SUBJECT TEXT_FILE HTML_FILE DAY_DIR [FROM_EMAIL] [MESSAGE_IDS_JSON] [SOURCE_ARTIFACTS_JSON]" >&2
  exit 1
fi

ACCOUNT_EMAIL="$1"
TO_EMAIL="$2"
SUBJECT="$3"
TEXT_FILE="$4"
HTML_FILE="$5"
DAY_DIR="$6"
FROM_EMAIL="${7:-}"
MESSAGE_IDS_JSON="${8:-}"
SOURCE_ARTIFACTS_JSON="${9:-}"

if ! command -v gog >/dev/null 2>&1; then
  echo "gog CLI not found on PATH." >&2
  exit 1
fi

if [ ! -f "${TEXT_FILE}" ]; then
  echo "Text body file not found: ${TEXT_FILE}" >&2
  exit 1
fi

if [ ! -f "${HTML_FILE}" ]; then
  echo "HTML body file not found: ${HTML_FILE}" >&2
  exit 1
fi

mkdir -p "${DAY_DIR}"

LOCAL_DATE="$(TZ=America/Chicago date '+%Y-%m-%d')"
LOCAL_TIME="$(TZ=America/Chicago date '+%Y-%m-%dT%H-%M-%S')"
RUN_DIR="${DAY_DIR}/${LOCAL_TIME}"

if [ -e "${RUN_DIR}" ]; then
  suffix=2
  while [ -e "${RUN_DIR}-${suffix}" ]; do
    suffix=$((suffix + 1))
  done
  RUN_DIR="${RUN_DIR}-${suffix}"
fi

mkdir -p "${RUN_DIR}"

cp "${TEXT_FILE}" "${RUN_DIR}/email.txt"
cp "${HTML_FILE}" "${RUN_DIR}/email.html"

SUMMARY_FILE="${RUN_DIR}/summary.json"
RESULT_FILE="${RUN_DIR}/send-result.json"

if [ -n "${MESSAGE_IDS_JSON}" ] && [ ! -f "${MESSAGE_IDS_JSON}" ]; then
  echo "Message ids file not found: ${MESSAGE_IDS_JSON}" >&2
  exit 1
fi

if [ -n "${SOURCE_ARTIFACTS_JSON}" ] && [ ! -f "${SOURCE_ARTIFACTS_JSON}" ]; then
  echo "Source artifacts file not found: ${SOURCE_ARTIFACTS_JSON}" >&2
  exit 1
fi

MESSAGE_IDS_JSON_VALUE='[]'
SOURCE_ARTIFACTS_JSON_VALUE='[]'

if [ -n "${MESSAGE_IDS_JSON}" ]; then
  MESSAGE_IDS_JSON_VALUE="$(cat "${MESSAGE_IDS_JSON}")"
fi

if [ -n "${SOURCE_ARTIFACTS_JSON}" ]; then
  SOURCE_ARTIFACTS_JSON_VALUE="$(cat "${SOURCE_ARTIFACTS_JSON}")"
fi

cat > "${SUMMARY_FILE}" <<EOF
{
  "subject": $(jq -Rn --arg v "${SUBJECT}" '$v'),
  "recipient": $(jq -Rn --arg v "${TO_EMAIL}" '$v'),
  "sender": $(jq -Rn --arg v "${FROM_EMAIL:-${ACCOUNT_EMAIL}}" '$v'),
  "account": $(jq -Rn --arg v "${ACCOUNT_EMAIL}" '$v'),
  "localDate": $(jq -Rn --arg v "${LOCAL_DATE}" '$v'),
  "runTimestamp": $(jq -Rn --arg v "${LOCAL_TIME}" '$v'),
  "runDir": $(jq -Rn --arg v "${RUN_DIR}" '$v'),
  "selectedMessageIds": ${MESSAGE_IDS_JSON_VALUE},
  "sourceArtifactDirs": ${SOURCE_ARTIFACTS_JSON_VALUE}
}
EOF

BODY_HTML="$(cat "${RUN_DIR}/email.html")"

SEND_ARGS=(
  gmail send
  --account "${ACCOUNT_EMAIL}"
  --to "${TO_EMAIL}"
  --subject "${SUBJECT}"
  --body-file "${RUN_DIR}/email.txt"
  --body-html "${BODY_HTML}"
  --json
  --results-only
  --no-input
)

if [ -n "${FROM_EMAIL}" ]; then
  SEND_ARGS+=(--from "${FROM_EMAIL}")
fi

SEND_OUTPUT="$(gog "${SEND_ARGS[@]}")"
printf '%s\n' "${SEND_OUTPUT}" > "${RESULT_FILE}"

if ! printf '%s\n' "${SEND_OUTPUT}" | jq -e '(.message_id // .messageId) and (.message_id // .messageId) != ""' >/dev/null 2>&1; then
  echo "Digest send failed: gog output did not include message_id/messageId" >&2
  cat "${RESULT_FILE}" >&2
  exit 1
fi

jq -n \
  --arg run_dir "${RUN_DIR}" \
  --arg summary_file "${SUMMARY_FILE}" \
  --arg result_file "${RESULT_FILE}" \
  --slurpfile send "${RESULT_FILE}" \
  '{
    run_dir: $run_dir,
    summary_file: $summary_file,
    result_file: $result_file,
    send_result: $send[0]
  }'
