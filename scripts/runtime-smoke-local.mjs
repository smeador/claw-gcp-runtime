#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import process from "node:process";

const result = spawnSync(process.execPath, ["scripts/runtime-test-local.mjs", "basic"], {
  stdio: "inherit",
  env: process.env,
});

process.exit(result.status ?? 1);
