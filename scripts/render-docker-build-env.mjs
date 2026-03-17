#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const args = process.argv.slice(2);
const outputFlagIndex = args.indexOf("--output");
if (outputFlagIndex === -1 || !args[outputFlagIndex + 1]) {
  console.error("Usage: node scripts/render-docker-build-env.mjs --output <path>");
  process.exit(1);
}

const outputPath = path.resolve(args[outputFlagIndex + 1]);
const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "..");
const versions = JSON.parse(fs.readFileSync(path.join(repoRoot, "versions.json"), "utf8"));

const lines = [
  `GO_IMAGE=${versions.docker.goImage}`,
  `NODE_IMAGE=${versions.docker.nodeImage}`,
  `GOG_VERSION=${versions.runtime.gogVersion}`,
  `OPENCLAW_NPM_DIST_TAG=${versions.runtime.openclawVersion}`
];

fs.mkdirSync(path.dirname(outputPath), {recursive: true});
fs.writeFileSync(outputPath, `${lines.join("\n")}\n`, {mode: 0o600});
console.log(`Rendered Docker build env to ${outputPath}`);
