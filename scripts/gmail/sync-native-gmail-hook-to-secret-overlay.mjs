#!/usr/bin/env node

import fs from "node:fs";
import os from "node:os";
import path from "node:path";

function usage() {
  console.error("Usage: node scripts/gmail/sync-native-gmail-hook-to-secret-overlay.mjs <target-json>");
  process.exit(1);
}

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, "utf8"));
}

if (process.argv.length !== 3) {
  usage();
}

const targetPath = path.resolve(process.argv[2]);
const nativePath = path.join(os.homedir(), ".openclaw", "openclaw.json");

if (!fs.existsSync(nativePath)) {
  console.error(`Native OpenClaw config not found: ${nativePath}`);
  process.exit(1);
}

if (!fs.existsSync(targetPath)) {
  console.error(`Target secret overlay not found: ${targetPath}`);
  process.exit(1);
}

const nativeConfig = readJson(nativePath);
if (!nativeConfig.hooks || !nativeConfig.hooks.gmail) {
  console.error("Native OpenClaw config does not contain hooks.gmail.");
  process.exit(1);
}

const targetConfig = readJson(targetPath);
targetConfig.hooks = targetConfig.hooks || {};
targetConfig.hooks.enabled = nativeConfig.hooks.enabled ?? targetConfig.hooks.enabled;
targetConfig.hooks.path = nativeConfig.hooks.path ?? targetConfig.hooks.path;
targetConfig.hooks.token = nativeConfig.hooks.token ?? targetConfig.hooks.token;
targetConfig.hooks.presets = nativeConfig.hooks.presets ?? targetConfig.hooks.presets;
targetConfig.hooks.gmail = nativeConfig.hooks.gmail;

fs.writeFileSync(targetPath, `${JSON.stringify(targetConfig, null, 2)}\n`, {mode: 0o600});
console.log(`Synced hooks.gmail from ${nativePath} into ${targetPath}`);
