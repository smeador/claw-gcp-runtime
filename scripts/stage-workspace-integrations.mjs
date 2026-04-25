#!/usr/bin/env node

import { cpSync, existsSync, mkdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import process from "node:process";

const REPO_ROOT = resolve(dirname(new URL(import.meta.url).pathname), "..");
const MANIFEST_PATH = resolve(REPO_ROOT, "workspace/integrations.json");
const STAGED_ROOT = resolve(REPO_ROOT, ".runtime/integrations");
const STATE_FILE = resolve(REPO_ROOT, ".runtime/integrations-state.json");
const WORKSPACE_SKILLS_ROOT = resolve(REPO_ROOT, "workspace/skills");
const LEGACY_WORKSPACE_INTEGRATIONS_PATH = resolve(REPO_ROOT, "workspace/integrations");
function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8"));
}

function usage(message = "") {
  if (message) {
    console.error(message);
    console.error("");
  }
  console.error("Usage: node scripts/stage-workspace-integrations.mjs");
  process.exit(1);
}

function removeIfExists(targetPath) {
  try {
    rmSync(targetPath, { recursive: true, force: true });
  } catch (error) {
    if (error && typeof error === "object" && "code" in error && error.code === "ENOENT") {
      return;
    }
    throw error;
  }
}

function ensureDirExists(targetPath) {
  if (!existsSync(targetPath)) {
    mkdirSync(targetPath, { recursive: true });
  }
}

function cleanGeneratedSkillsRoot() {
  ensureDirExists(WORKSPACE_SKILLS_ROOT);
  for (const entry of ["pip-gmail-send", "pip-newsletter-digest", "pip-newsletter-digest-format"]) {
    removeIfExists(resolve(WORKSPACE_SKILLS_ROOT, entry));
  }
}

function resolveIntegrationRoot(integration) {
  const envRoot = integration.rootEnv ? process.env[integration.rootEnv] : "";
  const rootValue = envRoot || integration.root;
  if (!rootValue) {
    throw new Error(`Integration ${integration.name} is missing both root and rootEnv.`);
  }
  return resolve(REPO_ROOT, rootValue);
}

function copyIntegration(sourceRoot, destRoot) {
  removeIfExists(destRoot);
  mkdirSync(dirname(destRoot), { recursive: true });
  cpSync(sourceRoot, destRoot, {
    recursive: true,
    preserveTimestamps: true,
    filter: (source) => {
      const base = source.split("/").pop() ?? "";
      if (base === ".git" || base === "node_modules" || base === ".DS_Store") {
        return false;
      }
      return true;
    },
  });
}

function copyWorkspaceTree(sourcePath, destPath) {
  removeIfExists(destPath);
  mkdirSync(dirname(destPath), { recursive: true });
  cpSync(sourcePath, destPath, {
    recursive: true,
    preserveTimestamps: true,
  });
}

function main() {
  if (!existsSync(MANIFEST_PATH)) {
    usage(`Integration manifest not found: ${MANIFEST_PATH}`);
  }

  const manifest = readJson(MANIFEST_PATH);
  const integrations = Array.isArray(manifest.integrations) ? manifest.integrations : [];
  if (integrations.length === 0) {
    removeIfExists(STAGED_ROOT);
    removeIfExists(STATE_FILE);
    return;
  }

  mkdirSync(STAGED_ROOT, { recursive: true });
  mkdirSync(WORKSPACE_SKILLS_ROOT, { recursive: true });
  removeIfExists(LEGACY_WORKSPACE_INTEGRATIONS_PATH);
  cleanGeneratedSkillsRoot();

  const staged = [];

  for (const integration of integrations) {
    if (!integration || typeof integration !== "object" || !integration.name) {
      throw new Error("Each integration entry must have a name.");
    }

    const sourceRoot = resolveIntegrationRoot(integration);
    if (!existsSync(sourceRoot)) {
      throw new Error(`Integration root not found for ${integration.name}: ${sourceRoot}`);
    }

    const destRoot = resolve(STAGED_ROOT, integration.name);
    copyIntegration(sourceRoot, destRoot);

    const skillDirs = Array.isArray(integration.skillDirs) ? integration.skillDirs : [];
    const stagedSkillsRoot = resolve(destRoot, "workspace/skills");

    for (const skillName of skillDirs) {
      const stagedSkillDir = resolve(stagedSkillsRoot, skillName);
      if (!existsSync(stagedSkillDir)) {
        throw new Error(`Skill ${skillName} not found in staged integration ${integration.name}.`);
      }
      const skillLink = resolve(WORKSPACE_SKILLS_ROOT, skillName);
      if (existsSync(skillLink)) {
        removeIfExists(skillLink);
      }
      copyWorkspaceTree(stagedSkillDir, skillLink);
    }

    staged.push({
      name: integration.name,
      sourceRoot,
      destRoot,
      skillDirs,
    });
  }

  writeFileSync(STATE_FILE, `${JSON.stringify({ integrations: staged }, null, 2)}\n`);
}

try {
  main();
} catch (error) {
  console.error(`Failed to stage workspace integrations: ${error.message}`);
  process.exit(1);
}
