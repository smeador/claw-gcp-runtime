#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import process from "node:process";

const VALID_MODES = new Set(["basic", "core", "integration"]);

function run(command, args, label, options = {}) {
  process.stdout.write(`\n== ${label}\n`);
  const result = spawnSync(command, args, {
    encoding: "utf8",
    env: process.env,
    ...options,
  });

  if (result.stdout) {
    process.stdout.write(result.stdout);
    if (!result.stdout.endsWith("\n")) {
      process.stdout.write("\n");
    }
  }

  if (result.stderr) {
    process.stderr.write(result.stderr);
    if (!result.stderr.endsWith("\n")) {
      process.stderr.write("\n");
    }
  }

  if (result.status !== 0) {
    throw new Error(`${label} failed with exit code ${result.status ?? "unknown"}`);
  }

  return result.stdout ?? "";
}

function assertIncludes(haystack, needle, label) {
  if (!haystack.includes(needle)) {
    throw new Error(`${label} did not include expected text: ${needle}`);
  }
}

function parseJson(text, label) {
  try {
    return JSON.parse(text);
  } catch (error) {
    throw new Error(`${label} did not return valid JSON: ${error.message}`);
  }
}

const npmRun = (...parts) => ["npm", ["run", "rt", "--", ...parts]];
const composeExec = (...parts) => [
  "docker",
  [
    "compose",
    "--env-file",
    "config/docker.build.env",
    "-f",
    "docker/compose.local.yml",
    "exec",
    "-T",
    "openclaw-gateway",
    ...parts,
  ],
];

function runBasic(skipDeploy) {
  if (!skipDeploy) {
    const [deployCmd, deployArgs] = npmRun("local", "deploy");
    run(deployCmd, deployArgs, "local deploy");
  } else {
    process.stdout.write("\n== local deploy\nSkipping deploy because a skip-deploy flag is set\n");
  }

  const [psCmd, psArgs] = npmRun("local", "ps");
  const psOutput = run(psCmd, psArgs, "local ps");
  assertIncludes(psOutput, "openclaw-gateway", "local ps");

  const [logsCmd, logsArgs] = npmRun("local", "logs");
  const logsOutput = run(logsCmd, logsArgs, "local logs");
  assertIncludes(logsOutput, "[gateway] ready", "local logs");

  const [cronListCmd, cronListArgs] = npmRun("local", "cron", "list");
  const cronListOutput = run(cronListCmd, cronListArgs, "local cron list");
  assertIncludes(cronListOutput, "ID", "local cron list");

  const [cronStatusCmd, cronStatusArgs] = composeExec("openclaw", "cron", "status", "--json");
  const cronStatusOutput = run(cronStatusCmd, cronStatusArgs, "local cron status");
  const cronStatus = parseJson(cronStatusOutput, "local cron status");
  if (!cronStatus.enabled) {
    throw new Error("local cron status reported disabled scheduler");
  }
}

function runCore() {
  const [healthCmd, healthArgs] = composeExec("openclaw", "health", "--json");
  const healthOutput = run(healthCmd, healthArgs, "local health");
  const health = parseJson(healthOutput, "local health");
  if (!health.ok) {
    throw new Error("local health reported ok=false");
  }
  if (health.defaultAgentId !== "main") {
    throw new Error(`local health reported unexpected default agent: ${health.defaultAgentId}`);
  }

  const [modelsCmd, modelsArgs] = composeExec("openclaw", "models", "status", "--plain");
  const modelsOutput = run(modelsCmd, modelsArgs, "local model status");
  assertIncludes(modelsOutput, "openrouter/", "local model status");

  const [pathsCmd, pathsArgs] = composeExec(
    "bash",
    "-lc",
    [
      "test -d /workspace && echo workspace-present",
      "test -w /workspace/memory && echo memory-writable",
      "test -w /workspace/.openclaw && echo workspace-openclaw-writable",
      "if test -w /workspace; then echo workspace-root-writable; else echo workspace-root-readonly; fi",
    ].join(" && "),
  );
  const pathOutput = run(pathsCmd, pathsArgs, "local workspace paths");
  assertIncludes(pathOutput, "workspace-present", "local workspace paths");
  assertIncludes(pathOutput, "memory-writable", "local workspace paths");
  assertIncludes(pathOutput, "workspace-openclaw-writable", "local workspace paths");
  assertIncludes(pathOutput, "workspace-root-readonly", "local workspace paths");

  const [binaryCmd, binaryArgs] = composeExec("bash", "-lc", "command -v openclaw && command -v gog");
  const binaryOutput = run(binaryCmd, binaryArgs, "local runtime binaries");
  assertIncludes(binaryOutput, "/usr/local/bin/openclaw", "local runtime binaries");
  assertIncludes(binaryOutput, "/usr/local/bin/gog", "local runtime binaries");
}

function runIntegration() {
  run(process.execPath, ["scripts/runtime.mjs", "help"], "runtime facade help");
  run("./scripts/email/extract-newsletter-from-gmail.mjs", ["--help"], "host extract shim help");
  run("./scripts/email/render-newsletter-digest.mjs", ["--help"], "host render shim help");

  const [wrapperExtractCmd, wrapperExtractArgs] = composeExec(
    "bash",
    "/workspace/scripts/extract-newsletter-from-gmail.sh",
    "--help",
  );
  run(wrapperExtractCmd, wrapperExtractArgs, "workspace extract wrapper help");

  const [wrapperRenderCmd, wrapperRenderArgs] = composeExec(
    "bash",
    "/workspace/scripts/render-newsletter-digest.sh",
    "--help",
  );
  run(wrapperRenderCmd, wrapperRenderArgs, "workspace render wrapper help");
}

const mode = process.argv[2] ?? "basic";
if (!VALID_MODES.has(mode)) {
  process.stderr.write(`Unknown local runtime test mode: ${mode}\n`);
  process.exit(1);
}

const skipDeploy =
  process.env.RUNTIME_TEST_SKIP_DEPLOY === "1" ||
  process.env.RUNTIME_SMOKE_SKIP_DEPLOY === "1";

try {
  runBasic(skipDeploy);

  if (mode === "core" || mode === "integration") {
    runCore();
  }

  if (mode === "integration") {
    runIntegration();
  }

  process.stdout.write(`\nLocal runtime ${mode} test passed.\n`);
} catch (error) {
  process.stderr.write(`\nLocal runtime ${mode} test failed: ${error.message}\n`);
  process.exit(1);
}
