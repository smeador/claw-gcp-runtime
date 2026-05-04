#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../..");
const templatePath = path.join(repoRoot, "config", "openclaw.local.example.json5");
const livePath = path.join(os.homedir(), ".openclaw", "openclaw.json");

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function normalizeWorkspacePath(value) {
  return typeof value === "string" && value.length > 0 ? "<workspace>" : null;
}

function normalizeInternalHooks(value) {
  const hooks = value && typeof value === "object" ? value : {};
  const entries = hooks.entries && typeof hooks.entries === "object" ? hooks.entries : {};
  const normalizedEntries = {};

  for (const [name, entry] of Object.entries(entries)) {
    if (!entry || typeof entry !== "object") {
      continue;
    }
    if (entry.enabled === false) {
      continue;
    }
    normalizedEntries[name] = entry;
  }

  return {
    enabled: hooks.enabled ?? null,
    entries: normalizedEntries,
  };
}

function projectConfig(config) {
  return {
    agents: {
      defaults: {
        model: config?.agents?.defaults?.model ?? {},
        workspace: normalizeWorkspacePath(config?.agents?.defaults?.workspace),
        compaction: config?.agents?.defaults?.compaction ?? {},
        maxConcurrent: config?.agents?.defaults?.maxConcurrent ?? null,
        subagents: config?.agents?.defaults?.subagents ?? {},
      },
    },
    messages: config?.messages ?? {},
    commands: config?.commands ?? {},
    session: config?.session ?? {},
    hooks: {
      internal: normalizeInternalHooks(config?.hooks?.internal),
    },
    gateway: {
      mode: config?.gateway?.mode ?? null,
      port: config?.gateway?.port ?? null,
      bind: config?.gateway?.bind ?? null,
      nodes: config?.gateway?.nodes ?? {},
    },
  };
}

function stableStringify(value) {
  if (Array.isArray(value)) {
    return `[${value.map(stableStringify).join(",")}]`;
  }
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map(key => `${JSON.stringify(key)}:${stableStringify(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

if (!fs.existsSync(livePath)) {
  console.error(`Live config not found: ${livePath}`);
  process.exit(1);
}

const template = projectConfig(readJson(templatePath));
const live = projectConfig(readJson(livePath));

const templateStr = stableStringify(template);
const liveStr = stableStringify(live);

if (templateStr === liveStr) {
  console.log("Native-local OpenClaw config matches the repo template for managed fields.");
  process.exit(0);
}

console.log("Native-local OpenClaw config differs from the repo template for managed fields.");
console.log("");
console.log("This is a manual native-local drift check. It is not used by Docker-local or cloud.");
console.log("");
console.log("Template:");
console.log(JSON.stringify(template, null, 2));
console.log("");
console.log("Live:");
console.log(JSON.stringify(live, null, 2));
process.exit(2);
