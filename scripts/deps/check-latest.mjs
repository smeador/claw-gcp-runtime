#!/usr/bin/env node

import {resolveLatestVersions} from "./lib/versions-latest.mjs";

function printEntry(label, entry) {
  const changedLabel = entry.changed ? "update available" : "current";
  console.log(`- ${label}: ${entry.current} -> ${entry.latest} (${changedLabel}, ${entry.source})`);
  if (entry.note) {
    console.log(`  note: ${entry.note}`);
  }
}

const resolved = await resolveLatestVersions();

console.log("Latest version check");
console.log("");

console.log("Docker");
printEntry("goImage", resolved.docker.goImage);
printEntry("nodeImage", resolved.docker.nodeImage);
console.log("");

console.log("Runtime");
printEntry("openclawVersion", resolved.runtime.openclawVersion);
printEntry("gogVersion", resolved.runtime.gogVersion);
console.log("");

console.log("Cloud Function");
printEntry("node", resolved.cloudFunction.node);
for (const [packageName, entry] of Object.entries(resolved.cloudFunction.dependencies)) {
  printEntry(`dependency ${packageName}`, entry);
}
