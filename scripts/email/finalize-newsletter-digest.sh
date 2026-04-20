#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPAT_SCRIPT="${REPO_ROOT}/compat/newsletter/scripts/email/finalize-newsletter-digest.sh"
DEFAULT_DIGEST_ROOT="$(cd "${REPO_ROOT}/.." && pwd)/agent-email-digest"
DEFAULT_DIGEST_NODE_MODULES="${DEFAULT_DIGEST_ROOT}/node_modules"

if command -v agent-email-digest-finalize >/dev/null 2>&1; then
  exec agent-email-digest-finalize "$@"
fi

if [ -n "${AGENT_EMAIL_DIGEST_ROOT:-}" ] && [ -f "${AGENT_EMAIL_DIGEST_ROOT}/scripts/email/finalize-newsletter-digest.sh" ]; then
  exec bash "${AGENT_EMAIL_DIGEST_ROOT}/scripts/email/finalize-newsletter-digest.sh" "$@"
fi

if [ -f "${DEFAULT_DIGEST_ROOT}/scripts/email/finalize-newsletter-digest.sh" ] && [ -d "${DEFAULT_DIGEST_NODE_MODULES}" ]; then
  exec bash "${DEFAULT_DIGEST_ROOT}/scripts/email/finalize-newsletter-digest.sh" "$@"
fi

exec bash "${COMPAT_SCRIPT}" "$@"
