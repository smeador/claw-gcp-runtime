# September 2026 dependency review

This maintenance branch is stacked on the OpenClaw 2026.9.2 upgrade. Cloud Docker storage was fixed and verified first; see [the storage report](cloud-docker-storage.md).

## Changes

| Dependency | Previous | Updated |
| --- | --- | --- |
| gog in Docker | v0.27.0 | v0.39.1 |
| Native Homebrew gog | 0.12.0 | 0.39.1 |
| Go Docker builder family | 1.26-bookworm | 1.27-bookworm (resolved Go 1.27.1) |
| `@google-cloud/compute` | 6.13.0 | 7.2.0 |
| `@google-cloud/functions-framework` | 5.0.2 | 5.0.5 |
| OpenTofu Google provider | 6.50.0 | 8.1.0 |
| OpenTofu Archive provider | 2.7.1 | 2.8.0 |

OpenClaw stays at 2026.9.2. Native/container Node stays at 22.23.2 and the Cloud Function remains on managed Node.js 22. Node 22 satisfies the upgraded Compute SDK and CloudEvents requirements; moving to a different Node major is unnecessary for these updates. Host Docker/Compose and other host utilities remain managed by the Debian package repositories; this is not an OS distribution migration. Newsletter implementation dependencies remain owned by its separate repository.

The Dockerfile and version checker now use `github.com/openclaw/gogcli`, the module path introduced in gog 0.35. The old `github.com/steipete/gogcli` install path is incompatible with the newer module declaration. Go 1.27 aligns with the upstream preferred toolchain. Docker fallback arguments remain aligned with `versions.json`.

Compute SDK 7 raises its minimum Node version to 22. The installed SDK's `InstancesClient` API was checked with mocked budget decisions and a real read-only VM lookup. No test stopped a VM.

## Audit

The Cloud Function lockfile now audits with **zero advisories across 196 production packages**, down from eight advisories (including two high severity). The root runtime manifest also audits clean.

Functions Framework 5.0.5 still depends on CloudEvents 10, whose `uuid ^8.3.2` dependency has an advisory. The narrow `cloudevents -> uuid: 11.1.1` override uses a patched release with CommonJS exports. Inspection showed CloudEvents uses `uuid.v4()`; generated IDs and both HTTP event bindings passed compatibility tests. Remove this override when CloudEvents adopts a patched compatible uuid version itself. Do not use npm's proposed functions-framework downgrade to 2.0.0 as the audit fix.

These are npm dependency audits, not a comprehensive OS/container vulnerability scan. The Docker build pulls the current configured base images.

## Cloud Function packaging and deployment

The archive now excludes local `node_modules`, so installing dependencies for tests does not accidentally ship a local dependency tree. An isolated Archive-provider check verified the ZIP contains exactly `index.js`, `package.json`, and `package-lock.json`.

The function's storage source now includes the uploaded object's `generation`. Without this reference, overwriting the same named ZIP can leave the function resource unchanged, even when its lockfile changed. The generation reference makes future source changes trigger a function update.

During this maintenance run, a baseline infrastructure plan already proposed replacing the VM and network before provider upgrades. Google 8.1 and Archive 2.8 produced the same resource action/replacement set. The relevant v7/v8 migration guidance was reviewed and configuration validation passed. No broad infrastructure apply was performed.

The deployed Cloud Function was updated directly from the three reviewed source files using `gcloud functions deploy`, avoiding unrelated infrastructure changes. Its new revision became ACTIVE. Before/after comparison confirmed that the event trigger, service account, environment, memory, timeout, ingress, concurrency, and instance limits were preserved. The full OpenTofu plan must still be reviewed and its pre-existing replacement drift reconciled before any general apply. A future managed apply must review the source object/generation alongside the existing drift.

## Validation

- Storage regression suite: eight passing cases; seven fail against the prior lifecycle. Two successive cloud deployments remained at 25% disk use after cleanup.
- Full local Docker integration suite rebuilt the upgraded image and passed. The final suite asserts the installed gog version matches the pin.
- Native, local Docker, and cloud Docker: gog 0.39.1; Gmail read checks passed.
- Native, local Docker, and cloud Docker: real Gmail JSON search/get output passed through the existing deterministic newsletter extractor with nonempty extracted content.
- Cloud gateway health passed with no degraded event loop; the newsletter cron remained unchanged.
- Cloud disk after the new gog/Go build: 35% used, about 19 GB free, with the old runtime image retained under `claw-runtime-openclaw:cloud-rollback`.
- Seven Cloud Function tests passed, including installed SDK method compatibility, budget/no-op decisions, UUID generation, and real Functions Framework HTTP handling of structured and binary Pub/Sub events. Run with `npm --prefix opentofu/modules/cost_controls/function_source ci --omit=dev --ignore-scripts`, then `npm run test:function`.
- Real upgraded Compute SDK `get` returned the running VM's status; the destructive `stop` path was mocked in tests.
- All 47 newsletter tests and its syntax checks passed. No test emails were sent; full email delivery was not exercised.
- Latest-version check, config/Compose validation, shell syntax, OpenTofu validation, archive contents, and diff whitespace checks passed.

## Sources

- [gog release history](https://github.com/openclaw/gogcli/blob/v0.39.1/CHANGELOG.md) and [toolchain declaration](https://github.com/openclaw/gogcli/blob/v0.39.1/go.mod)
- [Go releases](https://go.dev/dl/)
- [Compute SDK changelog](https://github.com/googleapis/google-cloud-node/blob/main/packages/google-cloud-compute/CHANGELOG.md)
- [Functions Framework 5.0.5](https://github.com/GoogleCloudPlatform/functions-framework-nodejs/releases/tag/v5.0.5)
- [Google provider v7 migration](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/version_7_upgrade) and [v8 migration](https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/version_8_upgrade)
- [uuid advisory](https://github.com/advisories/GHSA-w5hq-g745-h8pq)
