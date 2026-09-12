import assert from "node:assert/strict";
import { mkdtempSync, mkdirSync, readFileSync, writeFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import test from "node:test";

const entrypoint = fileURLToPath(new URL("../../docker/entrypoint.sh", import.meta.url));

for (const sourceMode of ["SOURCE", "SEED"]) {
  for (const command of ["gateway", "doctor"]) {
    test(`${sourceMode}: ${command} preserves config without resurrecting legacy stores`, () => {
      const root = mkdtempSync(path.join(tmpdir(), "openclaw-entrypoint-"));
      try {
        const home = path.join(root, "home");
        const state = path.join(home, ".openclaw");
        const bin = path.join(root, "bin");
        mkdirSync(state, { recursive: true });
        mkdirSync(bin);
        const source = {
          agents: { defaults: { model: { primary: "openrouter/test" } } },
          auth: { profiles: { "openrouter:default": { provider: "openrouter", mode: "api_key" } } },
          gateway: { auth: { mode: "token", token: "fixture-token" } },
        };
        writeFileSync(path.join(state, "openclaw.json"), JSON.stringify({
          ...source,
          meta: { lastTouchedAt: "2026-06-06T00:00:00.000Z", lastTouchedVersion: "2026.6.6" },
          wizard: { lastRunVersion: "2026.6.6" },
        }));
        const sourcePath = path.join(root, "source.json");
        const approvalsPath = path.join(root, "approvals.json");
        writeFileSync(sourcePath, JSON.stringify(source));
        writeFileSync(approvalsPath, JSON.stringify({ version: 1, defaults: { security: "full", ask: "off" }, agents: {} }));
        const callsPath = path.join(root, "calls.jsonl");
        writeFileSync(path.join(bin, "openclaw"), `#!/usr/bin/env node
const fs = require("node:fs");
const args = process.argv.slice(2);
const input = args.includes("paste-api-key") ? fs.readFileSync(0, "utf8") : "";
fs.appendFileSync(process.env.TEST_CALLS, JSON.stringify({args, input}) + "\\n");
`, { mode: 0o755 });
        const result = spawnSync("bash", [entrypoint, command], {
          encoding: "utf8",
          env: {
            ...process.env,
            HOME: home,
            PATH: `${bin}:${process.env.PATH}`,
            OPENCLAW_WORKSPACE: path.join(root, "workspace"),
            OPENCLAW_CONFIG_SOURCE: "",
            OPENCLAW_CONFIG_SEED: "",
            [`OPENCLAW_CONFIG_${sourceMode}`]: sourcePath,
            OPENCLAW_EXEC_APPROVALS_SOURCE: approvalsPath,
            OPENROUTER_API_KEY: "fixture-api-key",
            GOG_ACCOUNT: "",
            TEST_CALLS: callsPath,
          },
        });
        assert.equal(result.status, 0, result.stderr);
        const config = JSON.parse(readFileSync(path.join(state, "openclaw.json")));
        assert.equal(config.meta.lastTouchedAt, undefined);
        assert.equal(config.meta.lastTouchedVersion, "2026.6.6");
        assert.deepEqual(config.wizard, { lastRunVersion: "2026.6.6" });
        assert.deepEqual(config.gateway.auth, source.gateway.auth);
        assert.equal(existsSync(path.join(state, "exec-approvals.json")), false);
        assert.equal(existsSync(path.join(state, "agents/main/agent/auth-profiles.json")), false);
        const calls = readFileSync(callsPath, "utf8").trim().split("\n").map(JSON.parse);
        if (command === "doctor") {
          assert.deepEqual(calls, [{ args: ["doctor"], input: "" }]);
        } else {
          assert.deepEqual(calls[0].args, ["approvals", "set", "--file", approvalsPath]);
          assert.deepEqual(calls[1].args, ["models", "auth", "paste-api-key", "--agent", "main", "--provider", "openrouter", "--profile-id", "openrouter:default"]);
          assert.equal(calls[1].input, "fixture-api-key\n");
          assert.deepEqual(calls[2].args, ["gateway"]);
          assert.equal(calls.length, 3);
          assert.equal(result.stdout.includes("fixture-api-key"), false);
          assert.equal(result.stderr.includes("fixture-api-key"), false);
        }
      } finally {
        rmSync(root, { recursive: true, force: true });
      }
    });
  }
}
