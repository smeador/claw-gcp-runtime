#!/bin/bash
set -euo pipefail

if command -v agent-lab-finalize-newsletter-digest >/dev/null 2>&1; then
  exec agent-lab-finalize-newsletter-digest "$@"
fi

WORKSPACE_DIR="$(cd "$(dirname "$0")/.." && pwd)"
REPO_ROOT="$(cd "${WORKSPACE_DIR}/.." && pwd)"

if [ -f "/opt/agent-lab/scripts/email/finalize-newsletter-digest.sh" ]; then
  exec bash /opt/agent-lab/scripts/email/finalize-newsletter-digest.sh "$@"
fi

if [ -f "${REPO_ROOT}/scripts/email/finalize-newsletter-digest.sh" ]; then
  exec bash "${REPO_ROOT}/scripts/email/finalize-newsletter-digest.sh" "$@"
fi

echo "finalize-newsletter-digest.sh not found in installed helper or repo checkout" >&2
exit 1
