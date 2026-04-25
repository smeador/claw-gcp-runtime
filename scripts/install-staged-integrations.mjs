#!/usr/bin/env node

import { chmodSync, existsSync, mkdirSync, readFileSync, readdirSync, symlinkSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { execFileSync } from "node:child_process";
import process from "node:process";

function usage(message = "") {
  if (message) {
    console.error(message);
    console.error("");
  }
  console.error("Usage: node scripts/install-staged-integrations.mjs INTEGRATIONS_DIR BIN_DIR");
  process.exit(1);
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8"));
}

function installPackage(packageRoot) {
  const packageLock = resolve(packageRoot, "package-lock.json");
  const npmArgs = existsSync(packageLock)
    ? ["ci", "--omit=dev", "--ignore-scripts"]
    : ["install", "--omit=dev", "--ignore-scripts"];
  execFileSync("npm", npmArgs, { cwd: packageRoot, stdio: "inherit" });
}

function installBins(packageRoot, binDir) {
  const pkg = readJson(resolve(packageRoot, "package.json"));
  const bin = pkg.bin ?? {};
  const entries =
    typeof bin === "string"
      ? [[pkg.name, bin]]
      : Object.entries(bin);

  for (const [binName, relativePath] of entries) {
    const absolutePath = resolve(packageRoot, relativePath);
    chmodSync(absolutePath, 0o755);
    const linkPath = resolve(binDir, binName);
    try {
      symlinkSync(absolutePath, linkPath);
    } catch (error) {
      if (error.code === "EEXIST") {
        continue;
      }
      throw error;
    }
  }
}

const integrationsDir = process.argv[2];
const binDir = process.argv[3];

if (!integrationsDir || !binDir) {
  usage();
}

const resolvedIntegrationsDir = resolve(integrationsDir);
const resolvedBinDir = resolve(binDir);

if (!existsSync(resolvedIntegrationsDir)) {
  process.exit(0);
}

mkdirSync(resolvedBinDir, { recursive: true });

for (const entry of readdirSync(resolvedIntegrationsDir, { withFileTypes: true })) {
  if (!entry.isDirectory()) {
    continue;
  }

  const packageRoot = join(resolvedIntegrationsDir, entry.name);
  const packageJson = resolve(packageRoot, "package.json");
  if (!existsSync(packageJson)) {
    continue;
  }

  installPackage(packageRoot);
  installBins(packageRoot, resolvedBinDir);
}
