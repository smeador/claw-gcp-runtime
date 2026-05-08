#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import process from "node:process";

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

function cloudRemote(args, { tty = false } = {}) {
  return bashScript("./scripts/cloud/ssh-app.sh", tty ? ["--tty", ...args] : args);
}

function runtimeScript(envName, scriptPath, args = [], { tty = false } = {}) {
  if (envName === "local") {
    return bashScript(scriptPath, ["local", ...args]);
  }

  return cloudRemote(
    [
      "env",
      "OPENCLAW_APP_ROOT=/opt/openclaw/app",
      "OPENCLAW_DEPLOY_ROOT=/opt/openclaw",
      "bash",
      scriptPath,
      "cloud",
      ...args,
    ],
    { tty },
  );
}

function localCompose(args) {
  return bashLogin(
    `docker compose --env-file config/docker.build.env -f docker/compose.local.yml ${args.join(" ")}`,
  );
}

const COMMANDS = {
  help: {
    local: () => nodeScript("scripts/runtime/help-local.mjs"),
    cloud: () => nodeScript("scripts/runtime/help-cloud.mjs"),
  },
  prepare: {
    local: () => bashScript("./scripts/runtime/lifecycle.sh", ["local", "prepare"]),
  },
  deploy: {
    local: () => bashScript("./scripts/runtime/lifecycle.sh", ["local", "deploy"]),
    cloud: () =>
      bashScript("./scripts/cloud/runtime-action.sh", [
        "deploy",
        envOrFail("VM_NAME"),
        envOrFail("PROJECT_ID"),
        envOrFail("ZONE"),
        envOrFail("OPENCLAW_SECRET_NAME"),
      ]),
  },
  restart: {
    local: () => bashScript("./scripts/runtime/lifecycle.sh", ["local", "restart"]),
    cloud: () =>
      bashScript("./scripts/cloud/runtime-action.sh", [
        "restart",
        envOrFail("VM_NAME"),
        envOrFail("PROJECT_ID"),
        envOrFail("ZONE"),
        envOrFail("OPENCLAW_SECRET_NAME"),
      ]),
  },
  rebuild: {
    local: () => bashScript("./scripts/runtime/lifecycle.sh", ["local", "rebuild"]),
    cloud: () =>
      bashScript("./scripts/cloud/runtime-action.sh", [
        "rebuild",
        envOrFail("VM_NAME"),
        envOrFail("PROJECT_ID"),
        envOrFail("ZONE"),
        envOrFail("OPENCLAW_SECRET_NAME"),
      ]),
  },
  prune: {
    local: () => bashScript("./scripts/maintenance/prune-unused-docker-images.sh"),
    cloud: () => cloudRemote(["bash", "./scripts/maintenance/prune-unused-docker-images.sh"]),
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
    local: () => runtimeScript("local", "./scripts/runtime/agent-logs.sh"),
    cloud: () => runtimeScript("cloud", "./scripts/runtime/agent-logs.sh"),
  },
  "logs-download": {
    cloud: () => bashScript("./scripts/cloud/download-session-logs.sh"),
  },
  shell: {
    local: () => runtimeScript("local", "./scripts/runtime/shell-gateway.sh", [], { tty: true }),
    cloud: () => runtimeScript("cloud", "./scripts/runtime/shell-gateway.sh", [], { tty: true }),
  },
  tunnel: {
    cloud: () => bashScript("./scripts/cloud/tunnel-gateway.sh", [envOrFail("VM_NAME"), envOrFail("PROJECT_ID"), envOrFail("ZONE")]),
  },
  sync: {
    cloud: () => bashScript("./scripts/cloud/sync-app.sh", [envOrFail("VM_NAME"), envOrFail("PROJECT_ID"), envOrFail("ZONE")]),
  },
  "push-secret": {
    cloud: () => bashScript("./scripts/cloud/push-runtime-secret.sh", [envOrFail("OPENCLAW_SECRET_NAME"), envOrFail("PROJECT_ID"), process.env.CLOUD_SECRET_FILE || "config/secrets.cloud.json"]),
  },
};

const NESTED_COMMANDS = {
  cron: {
    apply: {
      local: () => bashScript("./scripts/runtime/cron.sh", ["local", "apply", process.env.LOCAL_CRON_FILE || "workspace/config/cron.local.json"]),
      cloud: () => runtimeScript("cloud", "./scripts/runtime/cron.sh", ["apply", process.env.CLOUD_CRON_FILE || "workspace/config/cron.cloud.json"]),
    },
    list: {
      local: () => bashScript("./scripts/runtime/cron.sh", ["local", "list"]),
      cloud: () => runtimeScript("cloud", "./scripts/runtime/cron.sh", ["list"]),
    },
    "run-digest": {
      local: () => bashScript("./scripts/runtime/cron.sh", ["local", "run", "newsletter-digest-morning"]),
      cloud: () => runtimeScript("cloud", "./scripts/runtime/cron.sh", ["run", "newsletter-digest-morning"]),
    },
  },
  test: {
    basic: {
      local: () => nodeScript("scripts/runtime/test-local.mjs", ["basic"]),
    },
    core: {
      local: () => nodeScript("scripts/runtime/test-local.mjs", ["core"]),
    },
    integration: {
      local: () => nodeScript("scripts/runtime/test-local.mjs", ["integration"]),
    },
    "gmail-read": {
      local: () => bashScript("./scripts/runtime/test-gmail-read.sh", ["local"]),
      cloud: () => runtimeScript("cloud", "./scripts/runtime/test-gmail-read.sh"),
    },
    "gmail-send": {
      local: () => bashScript("./scripts/runtime/test-gmail-send.sh", ["local"]),
      cloud: () => runtimeScript("cloud", "./scripts/runtime/test-gmail-send.sh"),
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
  prune
  ps
  logs
  logs-download
  agent-logs
  shell

Local-only commands:
  prepare

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
  agent-runtime local prune
  agent-runtime cloud prune
  agent-runtime local test skill newsletter-digest
  agent-runtime cloud test skill newsletter-digest
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
    const script = envName === "local" ? "./scripts/runtime/test-skill-local.sh" : "./scripts/runtime/test-skill-cloud.sh";
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
