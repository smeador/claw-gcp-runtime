#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import os from "node:os";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const templatePath = path.join(repoRoot, "config", "openclaw.local.example.json5");
const livePath = path.join(os.homedir(), ".openclaw", "openclaw.json");

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

function projectConfig(config) {
  return {
    agents: {
      defaults: {
        model: config?.agents?.defaults?.model ?? {},
        workspace: config?.agents?.defaults?.workspace ?? null,
        compaction: config?.agents?.defaults?.compaction ?? {},
        maxConcurrent: config?.agents?.defaults?.maxConcurrent ?? null,
        subagents: config?.agents?.defaults?.subagents ?? {},
      },
    },
    messages: config?.messages ?? {},
    commands: config?.commands ?? {},
    session: config?.session ?? {},
    hooks: {
      internal: config?.hooks?.internal ?? {},
    },
    gateway: {
      mode: config?.gateway?.mode ?? null,
      port: config?.gateway?.port ?? null,
      bind: config?.gateway?.bind ?? null,
      tailscale: config?.gateway?.tailscale ?? {},
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
  console.log("Local OpenClaw config matches the repo template for managed fields.");
  process.exit(0);
}

console.log("Local OpenClaw config differs from the repo template for managed fields.");
console.log("");
console.log("Template:");
console.log(JSON.stringify(template, null, 2));
console.log("");
console.log("Live:");
console.log(JSON.stringify(live, null, 2));
process.exit(2);
