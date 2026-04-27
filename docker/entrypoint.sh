#!/bin/bash
set -euo pipefail

HOME_DIR="${HOME:-/home/node}"
STATE_DIR="${HOME_DIR}/.openclaw"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE:-/workspace}"
CONFIG_PATH="${STATE_DIR}/openclaw.json"
CONFIG_SEED="${OPENCLAW_CONFIG_SEED:-}"
CONFIG_SOURCE="${OPENCLAW_CONFIG_SOURCE:-}"
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

AGENT_AUTH_PATH="${STATE_DIR}/agents/main/agent/auth-profiles.json"
AGENT_MODELS_PATH="${STATE_DIR}/agents/main/agent/models.json"
CONFIG_PATH="${CONFIG_PATH}" AGENT_AUTH_PATH="${AGENT_AUTH_PATH}" AGENT_MODELS_PATH="${AGENT_MODELS_PATH}" node <<'EOF'
const fs = require("fs");
const path = require("path");

function defaultApiKeyEnvVar(provider) {
  if (provider === "openai") {
    return "OPENAI_API_KEY";
  }

  return `${String(provider || "provider").replace(/[^A-Za-z0-9]+/g, "_").toUpperCase()}_API_KEY`;
}

const configPath = process.env.CONFIG_PATH;
const authPath = process.env.AGENT_AUTH_PATH;
const modelsPath = process.env.AGENT_MODELS_PATH;

if (!configPath || !authPath || !fs.existsSync(configPath)) {
  process.exit(0);
}

let config;
try {
  config = JSON.parse(fs.readFileSync(configPath, "utf8"));
} catch {
  process.exit(0);
}

const declaredProfiles = config?.auth?.profiles ?? {};
const seededProfiles = {};

for (const [name, profile] of Object.entries(declaredProfiles)) {
  if (!profile || typeof profile !== "object") {
    continue;
  }
  if (profile.mode !== "api_key" || typeof profile.provider !== "string" || profile.provider.length === 0) {
    continue;
  }

  const envName = typeof profile.apiKeyEnvVar === "string" && profile.apiKeyEnvVar.length > 0
    ? profile.apiKeyEnvVar
    : defaultApiKeyEnvVar(profile.provider);
  const secret = process.env[envName];
  if (!secret) {
    continue;
  }

  seededProfiles[name] = {
    type: "api_key",
    provider: profile.provider,
    key: secret,
  };
}

if (Object.keys(seededProfiles).length === 0) {
  process.exit(0);
}

let authStore = {
  version: 1,
  profiles: {},
  lastGood: {},
  usageStats: {},
};

if (fs.existsSync(authPath)) {
  try {
    const parsed = JSON.parse(fs.readFileSync(authPath, "utf8"));
    if (parsed && typeof parsed === "object") {
      authStore = {
        version: parsed.version ?? 1,
        profiles: parsed.profiles && typeof parsed.profiles === "object" ? parsed.profiles : {},
        lastGood: parsed.lastGood && typeof parsed.lastGood === "object" ? parsed.lastGood : {},
        usageStats: parsed.usageStats && typeof parsed.usageStats === "object" ? parsed.usageStats : {},
      };
    }
  } catch {
    // Ignore malformed persisted auth store and rebuild a minimal one.
  }
}

for (const [name, seeded] of Object.entries(seededProfiles)) {
  authStore.profiles[name] = seeded;
  authStore.lastGood[seeded.provider] = name;
  if (!authStore.usageStats[name] || typeof authStore.usageStats[name] !== "object") {
    authStore.usageStats[name] = {errorCount: 0};
  } else if (typeof authStore.usageStats[name].errorCount !== "number") {
    authStore.usageStats[name].errorCount = 0;
  }
}

fs.mkdirSync(path.dirname(authPath), {recursive: true});
fs.writeFileSync(authPath, `${JSON.stringify(authStore, null, 2)}\n`, {mode: 0o600});

// Repair stale persisted OpenRouter catalog state from older local runs.
if (modelsPath && fs.existsSync(modelsPath)) {
  try {
    const modelsStore = JSON.parse(fs.readFileSync(modelsPath, "utf8"));
    if (
      modelsStore &&
      typeof modelsStore === "object" &&
      modelsStore.providers &&
      typeof modelsStore.providers === "object" &&
      modelsStore.providers.openrouter &&
      typeof modelsStore.providers.openrouter === "object" &&
      modelsStore.providers.openrouter.baseUrl === "https://openrouter.ai/v1"
    ) {
      modelsStore.providers.openrouter.baseUrl = "https://openrouter.ai/api/v1";
      fs.mkdirSync(path.dirname(modelsPath), {recursive: true});
      fs.writeFileSync(modelsPath, `${JSON.stringify(modelsStore, null, 2)}\n`);
    }
  } catch {
    // Leave malformed provider catalogs untouched; OpenClaw can regenerate them.
  }
}
EOF

if [ -n "${GOG_ACCOUNT}" ] && [ -n "${GOG_SERVICE_ACCOUNT_KEY_SOURCE}" ] && [ -f "${GOG_SERVICE_ACCOUNT_KEY_SOURCE}" ]; then
  mkdir -p "${HOME_DIR}/.config/gogcli"
  gog auth service-account set "${GOG_ACCOUNT}" --key "${GOG_SERVICE_ACCOUNT_KEY_SOURCE}" >/dev/null
fi

if [ "$#" -eq 0 ]; then
  set -- gateway --bind lan --port 18789
fi

exec openclaw "$@"
