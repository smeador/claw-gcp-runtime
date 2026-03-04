#!/bin/bash
set -euo pipefail

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  echo "Usage: $0 SECRET_NAME PROJECT_ID [JSON_FILE]" >&2
  exit 1
fi

SECRET_NAME="$1"
PROJECT_ID="$2"
JSON_FILE="${3:-config/secrets.cloud.json}"

if [ ! -f "${JSON_FILE}" ]; then
  echo "Secret payload file not found: ${JSON_FILE}" >&2
  exit 1
fi

gcloud secrets versions add "${SECRET_NAME}" \
  --project "${PROJECT_ID}" \
  --data-file "${JSON_FILE}"
