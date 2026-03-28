#!/usr/bin/env node

import {
  applyResolvedVersions,
  loadVersions,
  resolveLatestVersions,
  saveVersions,
  summarizeChanges
} from "./lib/versions-latest.mjs";

const versions = loadVersions();
const resolved = await resolveLatestVersions();
const changes = summarizeChanges(resolved);

if (changes.length === 0) {
  console.log("versions.json is already current for auto-managed entries.");
  console.log("Skipped manual pins: docker.goImage, docker.nodeImage, cloudFunction.node");
  process.exit(0);
}

const next = applyResolvedVersions(versions, resolved);
saveVersions(next);

console.log("Updated versions.json:");
for (const change of changes) {
  console.log(`- ${change}`);
}
console.log("");
console.log("Skipped manual pins: docker.goImage, docker.nodeImage, cloudFunction.node");
