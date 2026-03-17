#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../..");
const versions = JSON.parse(fs.readFileSync(path.join(repoRoot, "versions.json"), "utf8"));
const packagePath = path.join(repoRoot, "opentofu/modules/cost_controls/function_source/package.json");
const pkg = JSON.parse(fs.readFileSync(packagePath, "utf8"));

pkg.engines = {
  ...(pkg.engines || {}),
  node: versions.cloudFunction.node
};
pkg.dependencies = {
  ...versions.cloudFunction.dependencies
};

fs.writeFileSync(packagePath, `${JSON.stringify(pkg, null, 2)}\n`);
console.log(`Synced Cloud Function package manifest from ${path.join(repoRoot, "versions.json")}`);
