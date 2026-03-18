#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function usage() {
  console.error("Usage: node scripts/render-gog-service-account-key.mjs --secrets <path> --account <email> --output <path>");
  console.error("   or: node scripts/render-gog-service-account-key.mjs --json <json> --account <email> --output <path>");
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

function ensureDir(filePath) {
  fs.mkdirSync(path.dirname(filePath), {recursive: true});
}

const args = parseArgs(process.argv.slice(2));
if (!args.account || !args.output || ((args.secrets ? 1 : 0) + (args.json ? 1 : 0) !== 1)) {
  usage();
}

const secrets = args.secrets
  ? JSON.parse(fs.readFileSync(args.secrets, "utf8"))
  : JSON.parse(args.json);
const key = secrets?.gog?.serviceAccounts?.[args.account];

if (!key) {
  try {
    fs.unlinkSync(args.output);
    console.log(`Removed Gmail service-account key at ${args.output}`);
  } catch (error) {
    if (error.code !== "ENOENT") {
      throw error;
    }
  }
  process.exit(0);
}

ensureDir(args.output);
fs.writeFileSync(args.output, `${JSON.stringify(key, null, 2)}\n`, {mode: 0o600});
console.log(`Rendered Gmail service-account key to ${args.output}`);
