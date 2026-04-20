#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
COMPAT_SCRIPT="${REPO_ROOT}/compat/newsletter/scripts/email/finalize-newsletter-digest.sh"
DEFAULT_DIGEST_ROOT="$(cd "${REPO_ROOT}/.." && pwd)/agent-newsletter-digest"
DEFAULT_DIGEST_NODE_MODULES="${DEFAULT_DIGEST_ROOT}/node_modules"
EXPLICIT_DIGEST_ROOT="${AGENT_NEWSLETTER_DIGEST_ROOT:-${AGENT_EMAIL_DIGEST_ROOT:-}}"

if command -v agent-newsletter-digest-finalize >/dev/null 2>&1; then
  exec agent-newsletter-digest-finalize "$@"
fi

if command -v agent-email-digest-finalize >/dev/null 2>&1; then
  exec agent-email-digest-finalize "$@"
fi

if [ -n "${EXPLICIT_DIGEST_ROOT}" ] && [ -f "${EXPLICIT_DIGEST_ROOT}/scripts/email/finalize-newsletter-digest.sh" ]; then
  exec bash "${EXPLICIT_DIGEST_ROOT}/scripts/email/finalize-newsletter-digest.sh" "$@"
fi

if [ -f "${DEFAULT_DIGEST_ROOT}/scripts/email/finalize-newsletter-digest.sh" ] && [ -d "${DEFAULT_DIGEST_NODE_MODULES}" ]; then
  exec bash "${DEFAULT_DIGEST_ROOT}/scripts/email/finalize-newsletter-digest.sh" "$@"
fi

exec bash "${COMPAT_SCRIPT}" "$@"
