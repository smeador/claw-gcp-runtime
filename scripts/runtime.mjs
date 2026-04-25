#!/usr/bin/env node

import { spawnSync } from "node:child_process";
import process from "node:process";

const COMMANDS = {
  help: {
    local: "local:help",
    cloud: "cloud:help",
  },
  prepare: {
    local: "local:prepare",
  },
  deploy: {
    local: "local:deploy",
    cloud: "cloud:deploy",
  },
  restart: {
    local: "local:restart",
    cloud: "cloud:restart",
  },
  rebuild: {
    local: "local:rebuild",
    cloud: "cloud:rebuild",
  },
  ps: {
    local: "local:ps",
    cloud: "cloud:ps",
  },
  logs: {
    local: "local:logs",
    cloud: "cloud:logs",
  },
  "agent-logs": {
    local: "local:agent:logs",
    cloud: "cloud:agent:logs",
  },
  shell: {
    local: "local:shell",
    cloud: "cloud:shell",
  },
  tunnel: {
    cloud: "cloud:tunnel",
  },
  sync: {
    cloud: "cloud:sync",
  },
  "push-secret": {
    cloud: "cloud:push-secret",
  },
};

const NESTED_COMMANDS = {
  cron: {
    apply: {
      local: "local:cron:apply",
      cloud: "cloud:cron:apply",
    },
    list: {
      local: "local:cron:list",
      cloud: "cloud:cron:list",
    },
    "run-digest": {
      local: "local:cron:run:digest",
      cloud: "cloud:cron:run:digest",
    },
  },
  test: {
    basic: {
      local: "runtime:test:local:basic",
    },
    core: {
      local: "runtime:test:local:core",
    },
    integration: {
      local: "runtime:test:local:integration",
    },
    "gmail-read": {
      local: "local:test:gmail:read",
      cloud: "cloud:test:gmail:read",
    },
    "gmail-send": {
      local: "local:test:gmail:send",
      cloud: "cloud:test:gmail:send",
    },
    digest: {
      local: "local:test:digest",
      cloud: "cloud:test:digest",
    },
  },
};

function printHelp() {
  console.log(`Usage:
  agent-runtime ENV COMMAND
  agent-runtime ENV GROUP COMMAND
  ./bin/agent-runtime ENV COMMAND
  ./bin/agent-runtime ENV GROUP COMMAND
  npm run rt -- ENV COMMAND
  npm run rt -- ENV GROUP COMMAND

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
  cron apply
  cron list
  cron run-digest
  test gmail-read
  test gmail-send
  test digest

Examples:
  agent-runtime local deploy
  agent-runtime cloud deploy
  agent-runtime local cron list
  agent-runtime local test basic
  agent-runtime local test core
  agent-runtime local test integration
  agent-runtime cloud test digest
  ./bin/agent-runtime local deploy
  ./bin/agent-runtime cloud deploy
  ./bin/agent-runtime local cron list
  ./bin/agent-runtime local test basic
  ./bin/agent-runtime local test core
  ./bin/agent-runtime local test integration
  ./bin/agent-runtime cloud test digest
  npm run rt -- local deploy
  npm run rt -- cloud deploy
  npm run rt -- local cron list
  npm run rt -- cloud test digest
`);
}

function resolveScript(envName, parts) {
  if (parts.length === 1) {
    const entry = COMMANDS[parts[0]];
    return entry?.[envName] ?? "";
  }

  if (parts.length === 2) {
    const group = NESTED_COMMANDS[parts[0]];
    return group?.[parts[1]]?.[envName] ?? "";
  }

  return "";
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

const scriptName = resolveScript(envName, commandParts);

if (!scriptName) {
  console.error(`Unknown command for ${envName}: ${commandParts.join(" ")}`);
  printHelp();
  process.exit(1);
}

const result = spawnSync("npm", ["run", scriptName], {
  stdio: "inherit",
  env: process.env,
  shell: false,
});

if (typeof result.status === "number") {
  process.exit(result.status);
}

process.exit(1);
