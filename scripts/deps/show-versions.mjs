#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import {execFileSync} from "node:child_process";

const repoRoot = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../..");
const versions = JSON.parse(fs.readFileSync(path.join(repoRoot, "versions.json"), "utf8"));

function readCommand(command, args) {
  try {
    return execFileSync(command, args, {cwd: repoRoot, encoding: "utf8"}).trim();
  } catch {
    return "<not installed>";
  }
}

console.log("Pinned repo versions");
console.log(`- OpenClaw: ${versions.runtime.openclawVersion}`);
console.log(`- Gog: ${versions.runtime.gogVersion}`);
console.log(`- Docker Go image: ${versions.docker.goImage}`);
console.log(`- Docker Node image: ${versions.docker.nodeImage}`);
console.log(`- Cloud Function Node: ${versions.cloudFunction.node}`);
for (const [name, version] of Object.entries(versions.cloudFunction.dependencies)) {
  console.log(`- Cloud Function dep ${name}: ${version}`);
}

console.log("");
console.log("Detected local tools");
console.log(`- openclaw: ${readCommand("openclaw", ["--version"])}`);
console.log(`- gog: ${readCommand("gog", ["version"])}`);
console.log(`- docker: ${readCommand("docker", ["--version"])}`);
console.log(`- node: ${readCommand("node", ["--version"])}`);
console.log(`- npm: ${readCommand("npm", ["--version"])}`);
console.log(`- rg: ${readCommand("rg", ["--version"]).split("\n")[0]}`);
