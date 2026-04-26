#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import process from "node:process";

const cwd = process.cwd();

function envOrFail(name) {
  const value = process.env[name];
  if (!value) {
    console.error(`Missing required environment variable: ${name}`);
    process.exit(1);
  }
  return value;
}

function bashScript(scriptPath, args = [], extraEnv = {}) {
  return {
    command: "bash",
    args: [scriptPath, ...args],
    env: { ...process.env, ...extraEnv },
  };
}

function nodeScript(scriptPath, args = []) {
  return {
    command: process.execPath,
    args: [scriptPath, ...args],
    env: process.env,
  };
}

function bashLogin(command, extraEnv = {}) {
  return {
    command: "bash",
    args: ["-lc", command],
    env: { ...process.env, ...extraEnv },
  };
}

function localCompose(args) {
  return bashLogin(
    `docker compose --env-file config/docker.build.env -f docker/compose.local.yml ${args.join(" ")}`,
  );
}

function cloudRemote(args, { tty = false } = {}) {
  return bashScript("./scripts/cloud-ssh-app.sh", tty ? ["--tty", ...args] : args);
}

function cloudDeployArgs() {
  return [
    envOrFail("VM_NAME"),
    envOrFail("PROJECT_ID"),
    envOrFail("ZONE"),
    envOrFail("OPENCLAW_SECRET_NAME"),
  ];
}

function cloudBaseReady() {
  envOrFail("VM_NAME");
  envOrFail("PROJECT_ID");
  envOrFail("ZONE");
}

const COMMANDS = {
  help: {
    local: () => nodeScript("scripts/local-help.mjs"),
    cloud: () => nodeScript("scripts/cloud-help.mjs"),
  },
  prepare: {
    local: () => bashScript("./scripts/runtime-lifecycle.sh", ["local", "prepare"]),
  },
  deploy: {
    local: () => bashScript("./scripts/runtime-lifecycle.sh", ["local", "deploy"]),
    cloud: () => bashScript("./scripts/deploy-cloud.sh", cloudDeployArgs()),
  },
  restart: {
    local: () => bashScript("./scripts/runtime-lifecycle.sh", ["local", "restart"]),
    cloud: () =>
      cloudRemote([
        "env",
        "OPENCLAW_APP_ROOT=/opt/openclaw/app",
        "OPENCLAW_DEPLOY_ROOT=/opt/openclaw",
        "bash",
        "./scripts/runtime-lifecycle.sh",
        "cloud",
        "restart",
        envOrFail("OPENCLAW_SECRET_NAME"),
      ]),
  },
  rebuild: {
    local: () => bashScript("./scripts/runtime-lifecycle.sh", ["local", "rebuild"]),
    cloud: () => {
      cloudBaseReady();
      envOrFail("OPENCLAW_SECRET_NAME");
      return bashLogin(
        `bash ./scripts/sync-cloud-app.sh ${JSON.stringify(process.env.VM_NAME)} ${JSON.stringify(process.env.PROJECT_ID)} ${JSON.stringify(process.env.ZONE)} && bash ./scripts/cloud-ssh-app.sh env OPENCLAW_APP_ROOT=/opt/openclaw/app OPENCLAW_DEPLOY_ROOT=/opt/openclaw bash ./scripts/runtime-lifecycle.sh cloud rebuild ${JSON.stringify(process.env.OPENCLAW_SECRET_NAME)}`,
      );
    },
  },
  ps: {
    local: () => localCompose(["ps"]),
    cloud: () => cloudRemote(["docker-compose", "--env-file", "config/docker.build.env", "-f", "docker/compose.cloud.yml", "ps"]),
  },
  logs: {
    local: () => localCompose(["logs", `--tail=${process.env.TAIL_LINES || 200}`, "openclaw-gateway"]),
    cloud: () =>
      cloudRemote([
        "docker-compose",
        "--env-file",
        "config/docker.build.env",
        "-f",
        "docker/compose.cloud.yml",
        "logs",
        `--tail=${process.env.TAIL_LINES || 200}`,
        "openclaw-gateway",
      ]),
  },
  "agent-logs": {
    local: () => bashScript("./scripts/show-local-agent-logs.sh"),
    cloud: () => bashScript("./scripts/show-cloud-agent-logs.sh", [envOrFail("VM_NAME"), envOrFail("PROJECT_ID"), envOrFail("ZONE")]),
  },
  "logs-download": {
    cloud: () => bashScript("./scripts/download-cloud-session-logs.sh"),
  },
  shell: {
    local: () => bashScript("./scripts/shell-local-gateway.sh"),
    cloud: () => bashScript("./scripts/shell-cloud-gateway.sh", [envOrFail("VM_NAME"), envOrFail("PROJECT_ID"), envOrFail("ZONE")]),
  },
  tunnel: {
    cloud: () => bashScript("./scripts/tunnel-cloud-gateway.sh", [envOrFail("VM_NAME"), envOrFail("PROJECT_ID"), envOrFail("ZONE")]),
  },
  sync: {
    cloud: () => bashScript("./scripts/sync-cloud-app.sh", [envOrFail("VM_NAME"), envOrFail("PROJECT_ID"), envOrFail("ZONE")]),
  },
  "push-secret": {
    cloud: () => bashScript("./scripts/push-cloud-runtime-secret.sh", [envOrFail("OPENCLAW_SECRET_NAME"), envOrFail("PROJECT_ID"), process.env.CLOUD_SECRET_FILE || "config/secrets.cloud.json"]),
  },
};

const NESTED_COMMANDS = {
  cron: {
    apply: {
      local: () => bashScript("./scripts/runtime-cron.sh", ["local", "apply", process.env.LOCAL_CRON_FILE || "workspace/config/cron.local.json"], { OPENCLAW_APP_ROOT: cwd }),
      cloud: () =>
        cloudRemote([
          "env",
          "OPENCLAW_APP_ROOT=/opt/openclaw/app",
          "bash",
          "./scripts/runtime-cron.sh",
          "cloud",
          "apply",
          process.env.CLOUD_CRON_FILE || "workspace/config/cron.cloud.json",
        ]),
    },
    list: {
      local: () => bashScript("./scripts/runtime-cron.sh", ["local", "list"], { OPENCLAW_APP_ROOT: cwd }),
      cloud: () =>
        cloudRemote([
          "env",
          "OPENCLAW_APP_ROOT=/opt/openclaw/app",
          "bash",
          "./scripts/runtime-cron.sh",
          "cloud",
          "list",
        ]),
    },
    "run-digest": {
      local: () => bashScript("./scripts/runtime-cron.sh", ["local", "run", "pip-newsletter-digest-morning"], { OPENCLAW_APP_ROOT: cwd }),
      cloud: () =>
        cloudRemote([
          "env",
          "OPENCLAW_APP_ROOT=/opt/openclaw/app",
          "bash",
          "./scripts/runtime-cron.sh",
          "cloud",
          "run",
          "pip-newsletter-digest-morning",
        ]),
    },
  },
  test: {
    basic: {
      local: () => nodeScript("scripts/runtime-test-local.mjs", ["basic"]),
    },
    core: {
      local: () => nodeScript("scripts/runtime-test-local.mjs", ["core"]),
    },
    integration: {
      local: () => nodeScript("scripts/runtime-test-local.mjs", ["integration"]),
    },
    "gmail-read": {
      local: () => bashScript("./scripts/read-local-gmail-test.sh"),
      cloud: () => bashScript("./scripts/read-cloud-gmail-test.sh"),
    },
    "gmail-send": {
      local: () => bashScript("./scripts/send-local-gmail-test.sh"),
      cloud: () => bashScript("./scripts/send-cloud-gmail-test.sh"),
    },
    digest: {
      local: () => bashScript("./scripts/run-local-digest-test.sh"),
    },
  },
};

function printHelp() {
  console.log(`Usage:
  agent-runtime ENV COMMAND
  agent-runtime ENV GROUP COMMAND

Environments:
  local
  cloud

Common commands:
  help
  deploy
  restart
  rebuild
  ps
  logs
  logs-download
  agent-logs
  shell

Local-only commands:
  prepare
  test digest

Cloud-only commands:
  sync
  tunnel
  push-secret

Grouped commands:
  test basic
  test core
  test integration
  test skill SKILL_NAME
  cron apply
  cron list
  cron run-digest
  test gmail-read
  test gmail-send

Examples:
  agent-runtime local deploy
  agent-runtime cloud deploy
  agent-runtime local cron list
  agent-runtime local test basic
  agent-runtime local test core
  agent-runtime local test integration
  agent-runtime local test skill pip-newsletter-digest
  agent-runtime cloud test skill pip-newsletter-digest
`);
}

function resolveSpec(envName, parts) {
  if (parts.length === 1) {
    const entry = COMMANDS[parts[0]];
    return entry?.[envName]?.() ?? null;
  }

  if (parts.length === 2) {
    const group = NESTED_COMMANDS[parts[0]];
    return group?.[parts[1]]?.[envName]?.() ?? null;
  }

  return null;
}

function runDirect(envName, parts) {
  if (parts.length === 3 && parts[0] === "test" && parts[1] === "skill") {
    const skillName = parts[2];
    const script = envName === "local" ? "./scripts/run-local-skill-test.sh" : "./scripts/run-cloud-skill-test.sh";
    const result = spawnSync("bash", [script, skillName], {
      stdio: "inherit",
      env: process.env,
      shell: false,
    });
    if (typeof result.status === "number") {
      process.exit(result.status);
    }
    process.exit(1);
  }
}

const argv = process.argv.slice(2);

if (argv.length === 0 || argv[0] === "-h" || argv[0] === "--help" || argv[0] === "help") {
  printHelp();
  process.exit(0);
}

const [envName, ...commandParts] = argv;

if (!["local", "cloud"].includes(envName)) {
  console.error(`Unknown environment: ${envName}`);
  printHelp();
  process.exit(1);
}

if (commandParts.length === 0) {
  printHelp();
  process.exit(1);
}

runDirect(envName, commandParts);

const spec = resolveSpec(envName, commandParts);

if (!spec) {
  console.error(`Unknown command for ${envName}: ${commandParts.join(" ")}`);
  printHelp();
  process.exit(1);
}

const result = spawnSync(spec.command, spec.args, {
  stdio: "inherit",
  env: spec.env ?? process.env,
  shell: false,
});

if (typeof result.status === "number") {
  process.exit(result.status);
}

process.exit(1);
