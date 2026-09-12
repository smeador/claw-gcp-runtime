#!/bin/bash
set -euo pipefail

HOME_DIR="${HOME:-/home/node}"
STATE_DIR="${HOME_DIR}/.openclaw"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE:-/workspace}"
CONFIG_PATH="${STATE_DIR}/openclaw.json"
CONFIG_SEED="${OPENCLAW_CONFIG_SEED:-}"
CONFIG_SOURCE="${OPENCLAW_CONFIG_SOURCE:-}"
EXEC_APPROVALS_SOURCE="${OPENCLAW_EXEC_APPROVALS_SOURCE:-}"
GOG_ACCOUNT="${GOG_ACCOUNT:-}"
GOG_SERVICE_ACCOUNT_KEY_SOURCE="${GOG_SERVICE_ACCOUNT_KEY_SOURCE:-}"

mkdir -p "${STATE_DIR}" "${WORKSPACE_DIR}" "${WORKSPACE_DIR}/.openclaw" "${WORKSPACE_DIR}/.openclaw/state"

if [ -n "${CONFIG_SOURCE}" ] && [ -f "${CONFIG_SOURCE}" ]; then
  if [ -f "${CONFIG_PATH}" ]; then
    tmp="$(mktemp)"
    jq -s '
      . as [$existing, $source]
      | $source
      | if ($existing.wizard | type) == "object" then .wizard = $existing.wizard else . end
      | if ($existing.meta | type) == "object" then .meta = ($existing.meta | del(.lastTouchedAt)) else . end
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
      | .meta = (($existing.meta // .meta) | if type == "object" then del(.lastTouchedAt) else . end)
      | .gateway = (($template.gateway // {}) + {auth: (($existing.gateway // {}).auth // (($template.gateway // {}).auth // {}))})
    ' "${CONFIG_PATH}" "${CONFIG_SEED}" > "${tmp}"
    mv "${tmp}" "${CONFIG_PATH}"
  else
    cp "${CONFIG_SEED}" "${CONFIG_PATH}"
  fi
fi

# Doctor owns legacy JSON-to-SQLite migration while the gateway is stopped.
# Never recreate retired auth-profiles.json or exec-approvals.json files.
if [ "${1:-}" != "doctor" ]; then
  if [ -n "${EXEC_APPROVALS_SOURCE}" ] && [ -f "${EXEC_APPROVALS_SOURCE}" ]; then
    openclaw approvals set --file "${EXEC_APPROVALS_SOURCE}" >/dev/null
  fi

  CONFIG_PATH="${CONFIG_PATH}" node <<'EOF'
const fs = require("node:fs");
const { spawnSync } = require("node:child_process");
const configPath = process.env.CONFIG_PATH;
if (!configPath || !fs.existsSync(configPath)) process.exit(0);
const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
for (const [name, profile] of Object.entries(config?.auth?.profiles ?? {})) {
  if (profile?.mode !== "api_key" || typeof profile.provider !== "string") continue;
  const envName = profile.apiKeyEnvVar || profile.provider.replace(/[^A-Za-z0-9]+/g, "_").toUpperCase() + "_API_KEY";
  const secret = process.env[envName];
  if (!secret) continue;
  const result = spawnSync("openclaw", ["models", "auth", "paste-api-key", "--agent", "main", "--provider", profile.provider, "--profile-id", name], {
    input: secret + "\n",
    encoding: "utf8",
    stdio: ["pipe", "pipe", "pipe"],
  });
  if (result.error || result.status !== 0) {
    // Auth command output may contain sensitive context; do not echo it.
    console.error("Failed to seed runtime auth profile " + name + "; run openclaw doctor --fix with the gateway stopped.");
    process.exit(1);
  }
}
EOF
fi

if [ -n "${GOG_ACCOUNT}" ] && [ -n "${GOG_SERVICE_ACCOUNT_KEY_SOURCE}" ] && [ -f "${GOG_SERVICE_ACCOUNT_KEY_SOURCE}" ]; then
  mkdir -p "${HOME_DIR}/.config/gogcli"
  gog auth service-account set "${GOG_ACCOUNT}" --key "${GOG_SERVICE_ACCOUNT_KEY_SOURCE}" >/dev/null
fi

if [ "$#" -eq 0 ]; then
  set -- gateway --bind lan --port 18789
fi

exec openclaw "$@"
