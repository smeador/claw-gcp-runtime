#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function usage() {
  console.error("Usage:");
  console.error("  node scripts/render-openclaw-config.mjs --template <path> --output <path> --local-secrets <path>");
  console.error("  node scripts/render-openclaw-config.mjs --template <path> --output <path> --gcp-secret-json <json>");
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

function mergeDeep(base, overlay) {
  if (overlay === undefined) {
    return base;
  }
  if (base === null || overlay === null || Array.isArray(base) || Array.isArray(overlay) || typeof base !== "object" || typeof overlay !== "object") {
    return overlay;
  }

  const merged = {...base};
  for (const [key, value] of Object.entries(overlay)) {
    merged[key] = key in merged ? mergeDeep(merged[key], value) : value;
  }
  return merged;
}

function ensureDir(filePath) {
  fs.mkdirSync(path.dirname(filePath), {recursive: true});
}

const args = parseArgs(process.argv.slice(2));
const templatePath = args.template;
const outputPath = args.output;
const localSecretsPath = args["local-secrets"];
const gcpSecretJson = args["gcp-secret-json"];

if (!templatePath || !outputPath) {
  usage();
}

if ((localSecretsPath ? 1 : 0) + (gcpSecretJson ? 1 : 0) !== 1) {
  usage();
}

const template = readJson(templatePath);
let secretOverlay;

if (localSecretsPath) {
  secretOverlay = readJson(localSecretsPath);
} else {
  secretOverlay = JSON.parse(gcpSecretJson);
}

const rendered = mergeDeep(template, secretOverlay);
ensureDir(outputPath);
fs.writeFileSync(outputPath, `${JSON.stringify(rendered, null, 2)}\n`, {mode: 0o600});
console.log(`Rendered OpenClaw config to ${outputPath}`);
