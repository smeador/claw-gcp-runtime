#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function usage() {
  console.error("Usage: node scripts/render-docker-local-env.mjs --secrets <path> --output <path>");
  process.exit(1);
}

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    const key = argv[i];
    if (!key.startsWith("--")) {
      usage();
    }
    const value = argv[i + 1];
    if (value === undefined || value.startsWith("--")) {
      usage();
    }
    args[key.slice(2)] = value;
    i += 1;
  }
  return args;
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function ensureDir(filePath) {
  fs.mkdirSync(path.dirname(filePath), {recursive: true});
}

function shellEscapeEnvValue(value) {
  return String(value).replace(/\\/g, "\\\\").replace(/\n/g, "\\n");
}

function defaultApiKeyEnvVar(provider) {
  if (provider === "openai") {
    return "OPENAI_API_KEY";
  }

  return `${String(provider || "provider").replace(/[^A-Za-z0-9]+/g, "_").toUpperCase()}_API_KEY`;
}

const args = parseArgs(process.argv.slice(2));
if (!args.secrets || !args.output) {
  usage();
}

const secrets = readJson(args.secrets);
const profiles = secrets?.auth?.profiles ?? {};
const lines = [
  "GOG_ACCOUNT=pip@meador.me"
];

for (const profile of Object.values(profiles)) {
  if (!profile || typeof profile !== "object") {
    continue;
  }
  if (profile.mode !== "api_key" || typeof profile.apiKey !== "string" || profile.apiKey.length === 0) {
    continue;
  }

  const envName = typeof profile.apiKeyEnvVar === "string" && profile.apiKeyEnvVar.length > 0
    ? profile.apiKeyEnvVar
    : defaultApiKeyEnvVar(profile.provider);
  lines.push(`${envName}=${shellEscapeEnvValue(profile.apiKey)}`);
}

ensureDir(args.output);
fs.writeFileSync(args.output, `${lines.join("\n")}\n`, {mode: 0o600});
console.log(`Rendered Docker local env to ${args.output}`);
