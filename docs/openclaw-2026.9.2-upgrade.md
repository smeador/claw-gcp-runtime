# OpenClaw 2026.9.2 upgrade

Validated on September 6, 2026. OpenClaw + GCP remains the chosen runtime architecture; newsletter logic stays in the separate deterministic workflow integration.

Follow-up: [September dependency maintenance](dependency-review-2026-09.md) resolves the Cloud Function advisories recorded below, and [cloud storage maintenance](cloud-docker-storage.md) fixes the accumulated Docker images. The original upgrade evidence below is retained as history.

## Versions and compatibility

OpenClaw is pinned to **2026.9.2** (previous Docker pin: 2026.6.6). Both Dockerfile defaults match `versions.json`. The native installation was also upgraded from 2026.3.24. Node **22.23.2** was used in all three environments; `.nvmrc` selects that version for native use.

The published Node requirement is `>=22.22.3 <23 || >=24.15.0 <25 || >=25.9.0`. Docker retains the Node 22 image family and pulls the base during deploy/rebuild. Native shells should run `nvm install && nvm use` in this repository before installing OpenClaw. A background gateway service must also reference the compatible Node binary; changing the interactive shell alone is insufficient.

Sources: [release notes](https://github.com/openclaw/openclaw/releases/tag/v2026.9.2), [published package](https://www.npmjs.com/package/openclaw/v/2026.9.2).

## Required runtime changes

The templates now use `tools.exec.mode: "full"` and `gateway.nodes.commands.deny`. They remove retired `commands.ownerDisplay`, `plugins.bundledDiscovery`, and `gateway.tailscale.resetOnExit` fields. Existing command restrictions and effective execution permissions are preserved. The entrypoint no longer copies the retired `meta.lastTouchedAt` field from persisted config.

This release migrates legacy auth, approval, workspace, and session state into SQLite. Writing the old `auth-profiles.json` or `exec-approvals.json` files after migration makes the runtime reject stale state. The entrypoint now imports approvals through `openclaw approvals set` and API keys through `openclaw models auth paste-api-key`. Secrets go through stdin, and auth command output is suppressed to avoid leaking credentials.

Deploy and rebuild now build the image, stop the gateway, run `doctor --fix --non-interactive --no-workspace-suggestions` in a one-off container with the same persistent mounts, then start the gateway and reconcile cron. `OPENCLAW_SERVICE_REPAIR_POLICY=external` leaves service ownership with Docker. During doctor, the entrypoint skips auth/approval initialization so migration can complete first. A migration failure stops deployment before the gateway starts; investigate the doctor output before retrying. Ordinary restart does not repeat the migration step.

The upstream runtime changes are mirrored into the private deployment repository. Provider/model choices and the deployment's newsletter schedule are preserved.

## Operator procedure

Before upgrading another installation, stop its gateway and securely back up the runtime state **and** all writable workspace state/memory mounts, plus its config and prior runtime revision. Backups contain credentials and must remain private. Docker's gateway must be stopped during migration; native service managers can otherwise restart the process behind doctor's maintenance lock.

For Docker, after backups and dependency rendering:

```bash
npm run deps:sync
./bin/claw-runtime local deploy
# With the deployment's GCP environment configured:
./bin/claw-runtime cloud deploy
```

For a native installation, use the compatible Node version, install the pinned OpenClaw with the existing package manager, stop the service, run `openclaw doctor --fix --non-interactive`, validate config, and reinstall/restart the gateway service under that Node binary. Inspect an old LaunchAgent/systemd definition if doctor cannot acquire maintenance ownership. Do not blindly replace a native personalized config with the generic template.

Rollback requires restoring the matching pre-upgrade state, workspace data, configuration, and runtime version together while the gateway is stopped. Merely downgrading the package against migrated SQLite state is not a tested rollback. Restore into an isolated location first when possible. Preserve the failed/migrated state for diagnosis.

## Verification results

| Check | Native local | Local Docker | GCP Docker |
| --- | --- | --- | --- |
| OpenClaw 2026.9.2 and Node 22.23.2 | Pass | Pass | Pass |
| Config validation and gateway health | Pass | Pass | Pass |
| Real bounded inference | Pass | Pass | Pass |
| Agent executing a deterministic `printf` tool call | Pass | Pass | Pass |
| Newsletter selection adapter: gateway transport | Pass | Pass | Pass |
| Newsletter selection adapter: local transport | Pass | Pass | Pass |
| Gmail read smoke check | Not run | Pass | Pass |
| Restart followed by health check | Pass | Pass | Deployment startup passed |
| Writable state with read-only workspace root | Not applicable | Pass | Pass |

The adapter smoke check used one synthetic eligible newsletter and asserted the exact selected message ID and two successful model-call audit records. This exercises the existing adapter contract without sending email. It does not establish full digest formatting or email delivery correctness.

Additional checks passed:

- Full local runtime integration suite, including image build/deploy, cron, models, binaries, permissions, integration staging and command smoke checks.
- Four entrypoint regression tests (config source/seed, gateway/doctor). All four fail against the old entrypoint and pass against the new entrypoint.
- Native service repair and final restart; repeated local Docker restart preserves SQLite state without recreating legacy stores.
- Newsletter repository: all 47 tests and syntax checks.
- All three config templates, both Compose configurations, shell syntax, OpenTofu validation with an isolated backend-free initialization, and `git diff --check`.

The existing cloud newsletter cron was found enabled despite older workspace notes saying it was suspended. Its existing schedule was retained. This release also exposes built-in heartbeat, memory dreaming, and skill-review declarations in cron output; these are distinct from the newsletter job. No test emails were sent.

## Audit and remaining limits

The native global installation initially retained vulnerable transitive packages from its existing pnpm lock. Refreshing the OpenClaw dependency tree within declared ranges produced a final pnpm audit with **zero advisories across 393 dependencies**. The exercised native paths passed afterward. Optional native package build scripts were not broadly enabled; optional features outside the checks above remain untested.

The Docker npm global installation has no lockfile, so `npm audit` cannot produce a complete audit there. Fresh image package inspection confirmed updated versions of the relevant protobufjs, hono, @hono/node-server, fast-uri, and brace-expansion packages; this is not a clean full-image audit claim.

The unchanged cost-control Cloud Function lockfile has **8 advisories**: high in `fast-uri` and `brace-expansion`; moderate in `protobufjs`, `qs`, and the `@google-cloud/functions-framework -> cloudevents -> uuid` chain; low in `body-parser`. Fixable transitive updates are deferred to a separate Cloud Function maintenance change. npm's proposed fix for the framework chain downgrades functions-framework to 2.0.0 and was not applied. Neither the Cloud Function nor gog was upgraded in this OpenClaw change.

Rollback restoration was not exercised. Successful health/cron status does not prove a complete scheduled digest; verify the next real run's artifacts separately.
