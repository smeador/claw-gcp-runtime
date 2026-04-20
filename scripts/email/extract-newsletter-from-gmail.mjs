#!/usr/bin/env node

import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import process from "node:process";

const HERE = dirname(fileURLToPath(import.meta.url));
const REPO_ROOT = resolve(HERE, "../..");
const COMPAT_SCRIPT = resolve(REPO_ROOT, "compat/newsletter/scripts/email/extract-newsletter-from-gmail.mjs");
const DEFAULT_DIGEST_ROOT = resolve(REPO_ROOT, "..", "agent-newsletter-digest");

function run(command, args) {
  try {
    execFileSync(command, args, { stdio: "inherit" });
    process.exit(0);
  } catch (error) {
    if (typeof error?.status === "number") {
      process.exit(error.status);
    }
    throw error;
  }
}

const args = process.argv.slice(2);

const explicitDigestRoot = process.env.AGENT_NEWSLETTER_DIGEST_ROOT || process.env.AGENT_EMAIL_DIGEST_ROOT || "";

if (explicitDigestRoot) {
  const envScript = resolve(explicitDigestRoot, "scripts/email/extract-newsletter-from-gmail.mjs");
  if (existsSync(envScript)) {
    run(process.execPath, [envScript, ...args]);
  }
}

const siblingScript = resolve(DEFAULT_DIGEST_ROOT, "scripts/email/extract-newsletter-from-gmail.mjs");
const siblingNodeModules = resolve(DEFAULT_DIGEST_ROOT, "node_modules");
if (existsSync(siblingScript) && existsSync(siblingNodeModules)) {
  run(process.execPath, [siblingScript, ...args]);
}

run(process.execPath, [COMPAT_SCRIPT, ...args]);
