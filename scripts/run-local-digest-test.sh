#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

export SKILL_TEST_MESSAGE="${SKILL_TEST_MESSAGE:-${DIGEST_MESSAGE:-Run pip-newsletter-digest now in test mode.}}"
if [ -n "${DIGEST_TEST_TIMEOUT_MS:-}" ] && [ -z "${SKILL_TEST_TIMEOUT_MS:-}" ]; then
  export SKILL_TEST_TIMEOUT_MS="${DIGEST_TEST_TIMEOUT_MS}"
fi

bash ./scripts/run-local-skill-test.sh pip-newsletter-digest
