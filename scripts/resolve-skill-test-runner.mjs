#!/usr/bin/env node

import { existsSync, readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import process from "node:process";

const REPO_ROOT = resolve(dirname(new URL(import.meta.url).pathname), "..");
const STATE_FILE = resolve(REPO_ROOT, ".runtime/integrations-state.json");

function usage(message = "") {
  if (message) {
    console.error(message);
    console.error("");
  }
  console.error("Usage: node scripts/resolve-skill-test-runner.mjs SKILL_NAME");
  process.exit(1);
}

function readJson(filePath) {
  return JSON.parse(readFileSync(filePath, "utf8"));
}

const skillName = process.argv[2];
if (!skillName) {
  usage();
}

if (!existsSync(STATE_FILE)) {
  usage(`Integration state file not found: ${STATE_FILE}`);
}

const state = readJson(STATE_FILE);
const integrations = Array.isArray(state.integrations) ? state.integrations : [];
const matches = integrations.filter(
  (integration) =>
    Array.isArray(integration.skills) &&
    integration.skills.includes(skillName) &&
    integration.adapter &&
    typeof integration.adapter.skillTestRunner === "string" &&
    integration.adapter.skillTestRunner.length > 0,
);

if (matches.length === 0) {
  usage(`No staged integration test runner found for skill: ${skillName}`);
}

if (matches.length > 1) {
  usage(`Multiple staged integrations claim skill test ownership for: ${skillName}`);
}

const match = matches[0];
const runnerPath = `${match.stagedRoot}/${match.adapter.skillTestRunner}`;
process.stdout.write(`${runnerPath}\n`);
