#!/usr/bin/env node

import { readFileSync } from "node:fs";
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

function readJsonFile(filePath, label) {
  try {
    return JSON.parse(readFileSync(filePath, "utf8"));
  } catch (error) {
    throw new Error(`${label} did not return valid JSON: ${error.message}`);
  }
}

const runtimeCli = (...parts) => [process.execPath, ["scripts/runtime/cli.mjs", ...parts]];
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
    const [deployCmd, deployArgs] = runtimeCli("local", "deploy");
    run(deployCmd, deployArgs, "local deploy");
  } else {
    process.stdout.write("\n== local deploy\nSkipping deploy because a skip-deploy flag is set\n");
  }

  const [psCmd, psArgs] = runtimeCli("local", "ps");
  const psOutput = run(psCmd, psArgs, "local ps");
  assertIncludes(psOutput, "openclaw-gateway", "local ps");

  const [logsCmd, logsArgs] = runtimeCli("local", "logs");
  const logsOutput = run(logsCmd, logsArgs, "local logs");
  assertIncludes(logsOutput, "[gateway] ready", "local logs");

  const [cronListCmd, cronListArgs] = runtimeCli("local", "cron", "list");
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
  run(process.execPath, ["scripts/runtime/cli.mjs", "help"], "runtime facade help");
  run(process.execPath, ["scripts/stage-workspace-integrations.mjs"], "stage workspace integrations");

  const state = readJsonFile("./.runtime/integrations-state.json", "integration state");
  const integrations = Array.isArray(state.integrations) ? state.integrations : [];
  if (integrations.length === 0) {
    throw new Error("integration state did not include any staged integrations");
  }

  for (const integration of integrations) {
    const stagedRoot = integration.stagedRoot;
    const firstSkill = integration.skills?.[0];
    if (!stagedRoot || !firstSkill) {
      throw new Error(`integration ${integration.name ?? "unknown"} did not declare a staged root and skills`);
    }
    const testSkill = integration.adapter?.testSkill || firstSkill;

    const [stagedPackageCmd, stagedPackageArgs] = [
      "bash",
      [
        "-lc",
        [
          `test -f ./${stagedRoot}/integration.json`,
          `test -f ./${stagedRoot}/package.json`,
          `test -f ./${stagedRoot}/${integration.adapter.skillsRoot}/${firstSkill}/SKILL.md`,
          ...(integration.workspaceFiles ?? []).map((entry) => `test -e ./workspace/${entry.target}`),
          "echo staged-integration-present",
        ].join(" && "),
      ],
    ];
    const stagedPackageOutput = run(
      stagedPackageCmd,
      stagedPackageArgs,
      `staged integration package (${integration.name})`,
    );
    assertIncludes(
      stagedPackageOutput,
      "staged-integration-present",
      `staged integration package (${integration.name})`,
    );

    for (const smokeTest of integration.smokeTests ?? []) {
      const [command, ...args] = smokeTest.command;
      run(
        ...composeExec(command, ...args),
        `integration smoke test (${integration.name}: ${smokeTest.name})`,
      );
    }

    const runnerPath = integration.adapter?.skillTestRunner;
    if (!runnerPath) {
      throw new Error(`integration ${integration.name} did not declare a skill test runner`);
    }

    const [skillTestEntryCmd, skillTestEntryArgs] = composeExec(
      "bash",
      "-lc",
      `test -x /opt/claw-runtime/integrations/${stagedRoot.replace(/^\.runtime\/integrations\//, "")}/${runnerPath} && echo skill-test-present`,
    );
    const skillTestEntryOutput = run(
      skillTestEntryCmd,
      skillTestEntryArgs,
      `skill test entrypoint (${integration.name})`,
    );
    assertIncludes(
      skillTestEntryOutput,
      "skill-test-present",
      `skill test entrypoint (${integration.name})`,
    );
  }
}

const mode = process.argv[2] ?? "basic";
if (!VALID_MODES.has(mode)) {
  process.stderr.write(`Unknown local runtime test mode: ${mode}\n`);
  process.exit(1);
}

const skipDeploy = process.env.RUNTIME_TEST_SKIP_DEPLOY === "1";

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
