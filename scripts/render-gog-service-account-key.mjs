#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

function usage() {
  console.error("Usage: node scripts/render-gog-service-account-key.mjs --secrets <path> [--account <email>] --output <path>");
  console.error("   or: node scripts/render-gog-service-account-key.mjs --json <json> [--account <email>] --output <path>");
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

function firstServiceAccount(secrets) {
  const accounts = secrets?.gog?.serviceAccounts;
  if (!accounts || typeof accounts !== "object") {
    return null;
  }

  const [account] = Object.keys(accounts);
  return account || null;
}

function resolveGogAccount(secrets) {
  if (typeof process.env.GOG_ACCOUNT === "string" && process.env.GOG_ACCOUNT.length > 0) {
    return process.env.GOG_ACCOUNT;
  }

  if (typeof secrets?.gog?.account === "string" && secrets.gog.account.length > 0) {
    return secrets.gog.account;
  }

  if (typeof secrets?.hooks?.gmail?.account === "string" && secrets.hooks.gmail.account.length > 0) {
    return secrets.hooks.gmail.account;
  }

  return firstServiceAccount(secrets);
}

const args = parseArgs(process.argv.slice(2));
if (!args.output || ((args.secrets ? 1 : 0) + (args.json ? 1 : 0) !== 1)) {
  usage();
}

const secrets = args.secrets
  ? JSON.parse(fs.readFileSync(args.secrets, "utf8"))
  : JSON.parse(args.json);
const account = args.account || resolveGogAccount(secrets);
const key = account ? secrets?.gog?.serviceAccounts?.[account] : null;

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
console.log(`Rendered Gmail service-account key for ${account} to ${args.output}`);
