#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function usage() {
  console.error("Usage:");
  console.error("  node scripts/render-runtime-env.mjs --secrets <path> --output <path>");
  console.error("  node scripts/render-runtime-env.mjs --json <json> --output <path>");
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

function resolveGogAccount(secrets) {
  if (typeof process.env.GOG_ACCOUNT === "string" && process.env.GOG_ACCOUNT.length > 0) {
    return process.env.GOG_ACCOUNT;
  }

  if (typeof secrets?.hooks?.gmail?.account === "string" && secrets.hooks.gmail.account.length > 0) {
    return secrets.hooks.gmail.account;
  }

  const accounts = secrets?.gog?.serviceAccounts;
  if (!accounts || typeof accounts !== "object") {
    return null;
  }

  const [firstAccount] = Object.keys(accounts);
  return firstAccount || null;
}

const args = parseArgs(process.argv.slice(2));
if (!args.output || ((args.secrets ? 1 : 0) + (args.json ? 1 : 0) !== 1)) {
  usage();
}

const secrets = args.secrets ? readJson(args.secrets) : JSON.parse(args.json);
const profiles = secrets?.auth?.profiles ?? {};
const lines = [];

const gogAccount = resolveGogAccount(secrets);
if (gogAccount) {
  lines.push(`GOG_ACCOUNT=${shellEscapeEnvValue(gogAccount)}`);
}

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
fs.writeFileSync(args.output, `${lines.join("\n")}${lines.length ? "\n" : ""}`, {mode: 0o600});
console.log(`Rendered runtime env to ${args.output}`);
