#!/bin/bash
set -euo pipefail

if [ $# -lt 3 ]; then
  echo "Usage: $0 ACCOUNT_EMAIL TO_EMAIL SUBJECT [BODY_FILE|-] [HTML_FILE]" >&2
  exit 1
fi

ACCOUNT_EMAIL="$1"
TO_EMAIL="$2"
SUBJECT="$3"
BODY_SOURCE="${4:--}"
HTML_SOURCE="${5:-}"

if ! command -v gog >/dev/null 2>&1; then
  echo "gog CLI not found on PATH." >&2
  exit 1
fi

if [ -n "${HTML_SOURCE}" ] && [ ! -f "${HTML_SOURCE}" ]; then
  echo "HTML body file not found: ${HTML_SOURCE}" >&2
  exit 1
fi

if [ -n "${HTML_SOURCE}" ]; then
  BODY_HTML="$(cat "${HTML_SOURCE}")"
fi

HTML_STATUS="no"
if [ -n "${HTML_SOURCE}" ]; then
  HTML_STATUS="yes"
fi

if [ "${BODY_SOURCE}" = "-" ]; then
  if [ -n "${HTML_SOURCE}" ]; then
    gog gmail send \
      --account "${ACCOUNT_EMAIL}" \
      --to "${TO_EMAIL}" \
      --subject "${SUBJECT}" \
      --body-file=- \
      --body-html "${BODY_HTML}"
  else
    gog gmail send \
      --account "${ACCOUNT_EMAIL}" \
      --to "${TO_EMAIL}" \
      --subject "${SUBJECT}" \
      --body-file=-
  fi
else
  if [ ! -f "${BODY_SOURCE}" ]; then
    echo "Body file not found: ${BODY_SOURCE}" >&2
    exit 1
  fi

  if [ -n "${HTML_SOURCE}" ]; then
    gog gmail send \
      --account "${ACCOUNT_EMAIL}" \
      --to "${TO_EMAIL}" \
      --subject "${SUBJECT}" \
      --body-file "${BODY_SOURCE}" \
      --body-html "${BODY_HTML}"
  else
    gog gmail send \
      --account "${ACCOUNT_EMAIL}" \
      --to "${TO_EMAIL}" \
      --subject "${SUBJECT}" \
      --body-file "${BODY_SOURCE}"
  fi
fi

echo "Email sent successfully"
echo "To: ${TO_EMAIL}"
echo "Subject: ${SUBJECT}"
echo "HTML: ${HTML_STATUS}"
