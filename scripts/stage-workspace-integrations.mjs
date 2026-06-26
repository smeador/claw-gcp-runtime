#!/usr/bin/env node

import { cpSync, existsSync, mkdirSync, readFileSync, readdirSync, rmSync, writeFileSync } from "node:fs";
import { dirname, relative, resolve } from "node:path";
import process from "node:process";

const REPO_ROOT = resolve(dirname(new URL(import.meta.url).pathname), "..");
const MANIFEST_PATH = resolve(REPO_ROOT, "workspace/integrations.json");
const STAGED_ROOT = resolve(REPO_ROOT, ".runtime/integrations");
const STATE_FILE = resolve(REPO_ROOT, ".runtime/integrations-state.json");
const WORKSPACE_ROOT = resolve(REPO_ROOT, "workspace");
const WORKSPACE_SKILLS_ROOT = resolve(REPO_ROOT, "workspace/skills");
const LEGACY_WORKSPACE_INTEGRATIONS_PATH = resolve(REPO_ROOT, "workspace/integrations");
function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8"));
}

function mergeDeep(base, overlay) {
  if (overlay === undefined) {
    return base;
  }
  if (base === null || overlay === null || Array.isArray(base) || Array.isArray(overlay) || typeof base !== "object" || typeof overlay !== "object") {
    return overlay;
  }

  const merged = { ...base };
  for (const [key, value] of Object.entries(overlay)) {
    merged[key] = key in merged ? mergeDeep(merged[key], value) : value;
  }
  return merged;
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

function readStateFile() {
  if (!existsSync(STATE_FILE)) {
    return null;
  }
  return readJson(STATE_FILE);
}

function cleanGeneratedSkillsRoot() {
  ensureDirExists(WORKSPACE_SKILLS_ROOT);
  for (const entry of readdirSync(WORKSPACE_SKILLS_ROOT, { withFileTypes: true })) {
    if (entry.name === ".gitkeep") {
      continue;
    }
    removeIfExists(resolve(WORKSPACE_SKILLS_ROOT, entry.name));
  }
}

function resolveWorkspaceTarget(target) {
  const resolved = resolve(WORKSPACE_ROOT, target);
  const relativeTarget = relative(WORKSPACE_ROOT, resolved);
  if (relativeTarget === "" || relativeTarget.startsWith("..")) {
    throw new Error(`Workspace target must stay within workspace/: ${target}`);
  }
  return resolved;
}

function cleanPreviouslyStagedWorkspaceFiles(previousState) {
  const integrations = Array.isArray(previousState?.integrations) ? previousState.integrations : [];
  for (const integration of integrations) {
    for (const entry of integration.workspaceFiles ?? []) {
      if (!entry || typeof entry.target !== "string" || entry.target.length === 0) {
        continue;
      }
      removeIfExists(resolveWorkspaceTarget(entry.target));
    }
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
      if (base === ".git" || base === "node_modules" || base === ".DS_Store" || base.startsWith("._")) {
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
    filter: (source) => {
      const base = source.split("/").pop() ?? "";
      if (base === ".DS_Store" || base.startsWith("._")) {
        return false;
      }
      return true;
    },
  });
}

function maybeApplyWorkspaceOverride(targetPath) {
  if (!targetPath.endsWith(".json")) {
    return;
  }

  const overridePath = targetPath.replace(/\.json$/, ".override.json");
  if (!existsSync(overridePath)) {
    return;
  }

  const base = readJson(targetPath);
  const overlay = readJson(overridePath);
  const merged = mergeDeep(base, overlay);
  writeFileSync(targetPath, `${JSON.stringify(merged, null, 2)}\n`);
}

function loadIntegrationManifest(sourceRoot, integrationName) {
  const manifestPath = resolve(sourceRoot, "integration.json");
  if (!existsSync(manifestPath)) {
    throw new Error(`Integration ${integrationName} is missing integration.json.`);
  }

  const manifest = readJson(manifestPath);
  if (!manifest || typeof manifest !== "object") {
    throw new Error(`Integration ${integrationName} has an invalid integration.json.`);
  }

  const adapter = manifest.adapter;
  if (!adapter || typeof adapter !== "object" || adapter.type !== "openclaw") {
    throw new Error(`Integration ${integrationName} must declare an OpenClaw adapter.`);
  }

  if (typeof adapter.skillsRoot !== "string" || adapter.skillsRoot.length === 0) {
    throw new Error(`Integration ${integrationName} is missing adapter.skillsRoot.`);
  }

  if ("testSkill" in adapter && (typeof adapter.testSkill !== "string" || adapter.testSkill.length === 0)) {
    throw new Error(`Integration ${integrationName} adapter.testSkill must be a non-empty string when provided.`);
  }

  if ("smokeTests" in manifest) {
    if (!Array.isArray(manifest.smokeTests)) {
      throw new Error(`Integration ${integrationName} smokeTests must be an array when provided.`);
    }

    for (const [index, smokeTest] of manifest.smokeTests.entries()) {
      if (!smokeTest || typeof smokeTest !== "object") {
        throw new Error(`Integration ${integrationName} smokeTests[${index}] must be an object.`);
      }
      if (typeof smokeTest.name !== "string" || smokeTest.name.length === 0) {
        throw new Error(`Integration ${integrationName} smokeTests[${index}] is missing a name.`);
      }
      if (!Array.isArray(smokeTest.command) || smokeTest.command.length === 0) {
        throw new Error(`Integration ${integrationName} smokeTests[${index}] must declare a non-empty command array.`);
      }
      for (const part of smokeTest.command) {
        if (typeof part !== "string" || part.length === 0) {
          throw new Error(`Integration ${integrationName} smokeTests[${index}] command entries must be non-empty strings.`);
        }
      }
    }
  }

  if ("workspaceFiles" in manifest) {
    if (!Array.isArray(manifest.workspaceFiles)) {
      throw new Error(`Integration ${integrationName} workspaceFiles must be an array when provided.`);
    }

    for (const [index, workspaceFile] of manifest.workspaceFiles.entries()) {
      if (!workspaceFile || typeof workspaceFile !== "object") {
        throw new Error(`Integration ${integrationName} workspaceFiles[${index}] must be an object.`);
      }
      if (typeof workspaceFile.source !== "string" || workspaceFile.source.length === 0) {
        throw new Error(`Integration ${integrationName} workspaceFiles[${index}] is missing a source.`);
      }
      if (typeof workspaceFile.target !== "string" || workspaceFile.target.length === 0) {
        throw new Error(`Integration ${integrationName} workspaceFiles[${index}] is missing a target.`);
      }
      resolveWorkspaceTarget(workspaceFile.target);
    }
  }

  return manifest;
}

function discoverSkillDirs(sourceRoot, integrationName, manifest) {
  const skillsRoot = resolve(sourceRoot, manifest.adapter.skillsRoot);
  if (!existsSync(skillsRoot)) {
    throw new Error(`Integration ${integrationName} skills root not found: ${skillsRoot}`);
  }

  return readdirSync(skillsRoot, { withFileTypes: true })
    .filter((entry) => entry.isDirectory())
    .map((entry) => entry.name)
    .sort();
}

function stageWorkspaceFiles(sourceRoot, integrationName, manifest) {
  const stagedFiles = [];
  for (const workspaceFile of manifest.workspaceFiles ?? []) {
    const sourcePath = resolve(sourceRoot, workspaceFile.source);
    if (!existsSync(sourcePath)) {
      throw new Error(`Integration ${integrationName} workspace file source not found: ${sourcePath}`);
    }
    const targetPath = resolveWorkspaceTarget(workspaceFile.target);
    copyWorkspaceTree(sourcePath, targetPath);
    maybeApplyWorkspaceOverride(targetPath);
    stagedFiles.push({
      source: workspaceFile.source,
      target: workspaceFile.target,
    });
  }
  return stagedFiles;
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

  removeIfExists(STAGED_ROOT);
  mkdirSync(STAGED_ROOT, { recursive: true });
  mkdirSync(WORKSPACE_SKILLS_ROOT, { recursive: true });
  removeIfExists(LEGACY_WORKSPACE_INTEGRATIONS_PATH);
  cleanPreviouslyStagedWorkspaceFiles(readStateFile());
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

    const integrationManifest = loadIntegrationManifest(sourceRoot, integration.name);
    const destRoot = resolve(STAGED_ROOT, integration.name);
    copyIntegration(sourceRoot, destRoot);

    const skillDirs = discoverSkillDirs(sourceRoot, integration.name, integrationManifest);
    const stagedSkillsRoot = resolve(destRoot, integrationManifest.adapter.skillsRoot);

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

    const stagedWorkspaceFiles = stageWorkspaceFiles(sourceRoot, integration.name, integrationManifest);

    staged.push({
      name: integration.name,
      sourceRoot: relative(REPO_ROOT, sourceRoot),
      stagedRoot: relative(REPO_ROOT, destRoot),
      adapter: {
        type: integrationManifest.adapter.type,
        skillsRoot: integrationManifest.adapter.skillsRoot,
        skillTestRunner: integrationManifest.adapter.skillTestRunner ?? "",
        testSkill: integrationManifest.adapter.testSkill ?? "",
      },
      smokeTests: integrationManifest.smokeTests ?? [],
      workspaceFiles: stagedWorkspaceFiles,
      skills: skillDirs,
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
