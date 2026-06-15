---
name: dependency-update
description: |
  Update and safety-review dependencies in this repo. Use when asked to bump,
  refresh, audit, or review dependency updates for the GCP OpenClaw runtime repo,
  including OpenClaw, gog, Docker image pins, and the Cloud Function package.
---

# Dependency Update

Use this skill for coding-agent work in this repository. This is not an
OpenClaw runtime skill and must not be placed under `workspace/skills`.

## Scope

This repo owns runtime and integration packaging. Newsletter workflow logic lives
in the sibling `newsletter-digest` repo, so update it only when the user asks for
that repo too.

Primary dependency surfaces:

- `versions.json`: central pins for Docker image families, OpenClaw, gog, and Cloud Function dependencies.
- `docker/Dockerfile`: fallback ARG defaults for direct Docker builds.
- `config/docker.build.env`: generated, ignored output from `npm run deps:sync`.
- `opentofu/modules/cost_controls/function_source/package.json`: Cloud Function manifest.
- `opentofu/modules/cost_controls/function_source/package-lock.json`: Cloud Function lockfile.

## Workflow

1. Start with repo state.

   ```bash
   git status --short --branch
   npm run deps:show
   npm run deps:check
   ```

2. Bump auto-managed dependency pins.

   ```bash
   npm run deps:bump
   npm run deps:sync
   npm run deps:lock:function
   ```

3. Review the diff before fixing anything else.

   ```bash
   git diff -- versions.json docker/Dockerfile opentofu/modules/cost_controls/function_source/package.json opentofu/modules/cost_controls/function_source/package-lock.json
   ```

   If `versions.json` changes OpenClaw or gog, keep `docker/Dockerfile` fallback ARGs aligned with the new pins. Compose usually passes generated build args, but direct Docker builds should not silently install old runtime versions.

4. Run audit checks.

   ```bash
   npm audit --omit=dev --json
   npm audit --omit=dev --json --prefix opentofu/modules/cost_controls/function_source
   ```

   If the Cloud Function lockfile has fixable transitive vulnerabilities, prefer:

   ```bash
   npm audit fix --omit=dev
   ```

   Run it from `opentofu/modules/cost_controls/function_source`.

   Do not run `npm audit fix --force` unless the user explicitly accepts the breaking-change risk. npm may suggest downgrading `@google-cloud/functions-framework`; treat that as a finding to report, not an automatic fix.

5. Check compatibility metadata for runtime tool bumps.

   ```bash
   npm view openclaw@NEW_VERSION name version license engines bin dependencies optionalDependencies peerDependencies dist.integrity repository --json
   npm view openclaw@OLD_VERSION name version license engines bin dependencies optionalDependencies peerDependencies dist.integrity repository --json
   npm view @google-cloud/functions-framework@VERSION dependencies engines --json
   npm view cloudevents versions dependencies --json
   ```

   If OpenClaw raises its Node engine floor, make sure runtime builds pull the current `node:22-bookworm-slim` base instead of relying on stale cached layers. The lifecycle build paths should use `--pull`.

6. Validate locally.

   ```bash
   node --check opentofu/modules/cost_controls/function_source/index.js
   bash -n scripts/runtime/lifecycle.sh
   tofu validate
   docker compose --env-file config/docker.build.env -f docker/compose.local.yml config
   OPENCLAW_DEPLOY_ROOT=/private/tmp/openclaw-compose docker compose --env-file config/docker.build.env -f docker/compose.cloud.yml config
   git diff --check
   ```

   For cloud compose validation, create an empty throwaway env first if needed:

   ```bash
   mkdir -p /private/tmp/openclaw-compose/state/runtime
   touch /private/tmp/openclaw-compose/state/runtime/runtime.env
   ```

7. Run the full local integration suite before calling the dependency update safe.

   ```bash
   node scripts/runtime/cli.mjs local test integration
   ```

   If Docker Buildx or Docker state is blocked by sandboxing, rerun with the required approval. The suite should rebuild the image, deploy the local gateway, check cron, health, model status, workspace permissions, runtime binaries, staged integrations, and integration smoke tests.

## Safety Review Notes

- Keep generated ignored files out of commits unless the user explicitly asks.
- `config/docker.build.env` and local rendered secrets/config are generated local state.
- It is acceptable for a local run to create ignored `node_modules/` directories.
- Report residual vulnerabilities with package chain, severity, and why they were not fixed.
- Prefer latest direct dependencies, but do not accept audit fixes that downgrade major runtime packages without explicit user approval.
- For gog jumps, treat CLI compatibility as higher risk than a normal patch bump because Gmail commands are operationally important.

## Expected Closeout

Summarize:

- changed pins and files
- audit result, including any residual findings
- validation commands run
- full integration suite result
- any remaining manual risk, especially runtime tool or CLI behavior changes
