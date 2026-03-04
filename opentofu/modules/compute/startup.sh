#!/bin/bash
set -euo pipefail

OPENCLAW_USER="openclaw"
OPENCLAW_ROOT="/opt/openclaw"
OPENCLAW_APP_ROOT="${OPENCLAW_ROOT}/app"

if ! id "${OPENCLAW_USER}" >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash "${OPENCLAW_USER}"
fi

install -d -o root -g root -m 0755 "${OPENCLAW_ROOT}"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_APP_ROOT}"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/config"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/agents"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/scripts"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/logs"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/state"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/state/home"
# The rendered runtime config must be readable by the container user, while
# mutable runtime state stays restricted to the dedicated host user.
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0755 "${OPENCLAW_ROOT}/state/runtime"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/state/workspace"
install -d -o "${OPENCLAW_USER}" -g "${OPENCLAW_USER}" -m 0750 "${OPENCLAW_ROOT}/state/memory"

# Persisted OpenClaw runtime state may contain live provider auth and should
# remain accessible only to the dedicated runtime user.
chmod 0750 "${OPENCLAW_APP_ROOT}" "${OPENCLAW_ROOT}/state" "${OPENCLAW_ROOT}/state/home" "${OPENCLAW_ROOT}/state/workspace" "${OPENCLAW_ROOT}/state/memory"
chmod 0755 "${OPENCLAW_ROOT}/state/runtime"
