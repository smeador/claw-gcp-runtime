#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p config/rendered

node scripts/render-openclaw-config.mjs \
  --template config/openclaw.container.json5.example \
  --output config/rendered/openclaw.json \
  --local-secrets config/secrets.local.json

if [ -f "${HOME}/.openclaw/openclaw.json" ]; then
  node - "${HOME}/.openclaw/openclaw.json" "config/rendered/openclaw.json" <<'NODE'
const fs = require("node:fs");

const [nativePath, renderedPath] = process.argv.slice(2);
const nativeConfig = JSON.parse(fs.readFileSync(nativePath, "utf8"));
const renderedConfig = JSON.parse(fs.readFileSync(renderedPath, "utf8"));

if (nativeConfig.hooks && nativeConfig.hooks.gmail) {
  renderedConfig.hooks = renderedConfig.hooks || {};
  renderedConfig.hooks.enabled = nativeConfig.hooks.enabled ?? renderedConfig.hooks.enabled;
  renderedConfig.hooks.path = nativeConfig.hooks.path ?? renderedConfig.hooks.path;
  renderedConfig.hooks.token = nativeConfig.hooks.token ?? renderedConfig.hooks.token;
  renderedConfig.hooks.presets = nativeConfig.hooks.presets ?? renderedConfig.hooks.presets;
  renderedConfig.hooks.gmail = nativeConfig.hooks.gmail;
}

fs.writeFileSync(renderedPath, `${JSON.stringify(renderedConfig, null, 2)}\n`, {mode: 0o600});
NODE
fi
