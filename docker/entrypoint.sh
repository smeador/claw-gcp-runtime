#!/bin/bash
set -euo pipefail

HOME_DIR="${HOME:-/home/node}"
STATE_DIR="${HOME_DIR}/.openclaw"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE:-/workspace}"
CONFIG_PATH="${STATE_DIR}/openclaw.json"
CONFIG_SEED="${OPENCLAW_CONFIG_SEED:-}"
CONFIG_SOURCE="${OPENCLAW_CONFIG_SOURCE:-}"

mkdir -p "${STATE_DIR}" "${WORKSPACE_DIR}/.openclaw"

if [ "$(id -u)" -eq 0 ]; then
  chown -R node:node "${STATE_DIR}" "${WORKSPACE_DIR}/.openclaw"
fi

if [ -n "${CONFIG_SOURCE}" ] && [ -f "${CONFIG_SOURCE}" ]; then
  if [ -f "${CONFIG_PATH}" ]; then
    tmp="$(mktemp)"
    jq -s '
      . as [$existing, $source]
      | $source
      | if ($existing.wizard | type) == "object" then .wizard = $existing.wizard else . end
      | if ($existing.meta | type) == "object" then .meta = $existing.meta else . end
    ' "${CONFIG_PATH}" "${CONFIG_SOURCE}" > "${tmp}"
    mv "${tmp}" "${CONFIG_PATH}"
  else
    cp "${CONFIG_SOURCE}" "${CONFIG_PATH}"
  fi
elif [ -n "${CONFIG_SEED}" ] && [ -f "${CONFIG_SEED}" ]; then
  if [ -f "${CONFIG_PATH}" ]; then
    tmp="$(mktemp)"
    jq -s '
      . as [$existing, $template]
      | $template
      | .auth = ($existing.auth // .auth)
      | .wizard = ($existing.wizard // .wizard)
      | .meta = ($existing.meta // .meta)
      | .gateway = (($template.gateway // {}) + {auth: (($existing.gateway // {}).auth // (($template.gateway // {}).auth // {}))})
    ' "${CONFIG_PATH}" "${CONFIG_SEED}" > "${tmp}"
    mv "${tmp}" "${CONFIG_PATH}"
  else
    cp "${CONFIG_SEED}" "${CONFIG_PATH}"
  fi
fi

if [ "$#" -eq 0 ]; then
  set -- gateway --bind lan --port 18789
fi

if [ "$(id -u)" -eq 0 ]; then
  chown -R node:node "${STATE_DIR}" "${WORKSPACE_DIR}/.openclaw"
  exec setpriv --reuid "$(id -u node)" --regid "$(id -g node)" --init-groups openclaw "$@"
fi

exec openclaw "$@"
