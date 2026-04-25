#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import process from "node:process";

function run(command, args, label) {
  process.stdout.write(`\n== ${label}\n`);
  const result = spawnSync(command, args, {
    encoding: "utf8",
    env: process.env,
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

const npmCmd = "npm";
const npmRun = (...parts) => [npmCmd, ["run", "rt", "--", ...parts]];
const skipDeploy = process.env.RUNTIME_SMOKE_SKIP_DEPLOY === "1";

try {
  if (!skipDeploy) {
    const [deployCmd, deployArgs] = npmRun("local", "deploy");
    run(deployCmd, deployArgs, "local deploy");
  } else {
    process.stdout.write("\n== local deploy\nSkipping deploy because RUNTIME_SMOKE_SKIP_DEPLOY=1\n");
  }

  const [psCmd, psArgs] = npmRun("local", "ps");
  const psOutput = run(psCmd, psArgs, "local ps");
  assertIncludes(psOutput, "openclaw-gateway", "local ps");

  const [logsCmd, logsArgs] = npmRun("local", "logs");
  const logsOutput = run(logsCmd, logsArgs, "local logs");
  assertIncludes(logsOutput, "openclaw-gateway", "local logs");

  const [cronCmd, cronArgs] = npmRun("local", "cron", "list");
  run(cronCmd, cronArgs, "local cron list");

  process.stdout.write("\nLocal runtime smoke test passed.\n");
} catch (error) {
  process.stderr.write(`\nRuntime smoke test failed: ${error.message}\n`);
  process.exit(1);
}
