#!/bin/bash
set -euo pipefail

OPENCLAW_USER="openclaw"
OPENCLAW_ROOT="/opt/openclaw"

if ! id "${OPENCLAW_USER}" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${OPENCLAW_USER}"
fi

install -d -o root -g root -m 0755 "${OPENCLAW_ROOT}"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/config"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/agents"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/scripts"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/logs"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/state"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/state/home"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/state/workspace"
