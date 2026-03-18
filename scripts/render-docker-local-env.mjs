#!/usr/bin/env node

import {spawnSync} from "node:child_process";
import path from "node:path";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const scriptPath = path.join(repoRoot, "scripts", "render-runtime-env.mjs");
const result = spawnSync(process.execPath, [scriptPath, ...process.argv.slice(2)], {stdio: "inherit"});

if (result.error) {
  throw result.error;
}

process.exit(result.status ?? 1);
