# Open Source Plan

## Decision

We are standardizing on a two-repo split:

1. this repo becomes the OpenClaw runtime / GCP infra / local-cloud operating model repo
2. a new repo will contain the newsletter and digest system

This is intentionally not a split between "infra" and "app" in the abstract. It is a split between:

- a reusable OpenClaw runtime/distribution layer
- a reusable email-to-digest workflow layer

The live Pip workflow remains the proving ground, but the code should evolve toward these public surfaces.

Important transition note:

- keep the live Pip workflow working during the split
- do not let Pip-specific personality or framing become part of the long-term public identity of the runtime repo
- over time, Pip should become an example implementation or compatibility layer rather than the conceptual center of the runtime repo

## Repo shape

### Repo A: current repo

Recommended future identity:

- `openclaw-runtime-gcp`

Purpose:

- reproducible OpenClaw setup across native local, Docker local, and GCP cloud
- deterministic config rendering
- deterministic state layout
- deploy/rebuild/restart/test ergonomics
- tunnel, logs, cron, and operational helpers

This repo should answer:

- how do I run OpenClaw locally and on GCP with the same operational model?
- how do I manage state, secrets, Docker, cron jobs, and cloud rollouts safely?

### Repo B: new repo

Recommended future identity:

- `agent-email-digest`

Purpose:

- ingest newsletter/email sources
- extract cleaned artifacts
- select issues
- synthesize digest content
- render deterministic email output
- send through pluggable transports

This repo should answer:

- how do I turn emails into a structured digest workflow that can plug into different agent frameworks?

## Core principle

The public design principle should stay the same:

- code owns deterministic mechanics
- agent instructions own judgment

That means:

- retrieval and extraction should be code-owned
- schemas should be explicit and versioned
- rendering and send should be code-owned
- prompts/skills should focus on selection, synthesis, and adaptation

## What stays in this repo

This repo should keep everything that is primarily about running OpenClaw as an environment.

### Runtime and infra

- `docker/`
- `opentofu/`
- runtime-oriented `config/`
- version pinning and sync logic
- cloud host bootstrap and deploy scripts
- local Docker lifecycle scripts
- tunnel, log, cron, and state inspection helpers

### Recommended examples of code that stay here

- `docker/Dockerfile`
- `docker/compose.local.yml`
- `docker/compose.cloud.yml`
- `docker/entrypoint.sh`
- `scripts/run-cloud.sh`
- `scripts/rebuild-cloud.sh`
- `scripts/restart-cloud.sh`
- `scripts/run-local.sh`
- `scripts/rebuild-local-docker.sh`
- `scripts/prepare-local-docker.sh`
- `scripts/tunnel-cloud-gateway.sh`
- `scripts/show-local-agent-logs.sh`
- `scripts/show-cloud-agent-logs.sh`
- `scripts/render-openclaw-config.mjs`
- `scripts/push-cloud-runtime-secret.sh`
- `scripts/prune-unused-docker-images.sh`
- `config/openclaw.*`
- `config/secrets.*.example`
- `config/docker.*`
- `versions.json`

### Docs that stay here

- runtime docs
- local/cloud operational docs
- infra architecture docs
- deployment notes
- state layout docs
- compatibility matrix docs

Examples:

- `README.md`
- `docs/spec.md`
- `docs/backlog.md`
- `docs/openclaw-agent-guide.md`

## What moves to the new newsletter repo

The new repo should own the digest workflow itself.

### Deterministic workflow code

- email extraction logic
- digest finalization logic
- deterministic renderer
- digest send helper
- schema definitions
- fixture tests

### OpenClaw adapter layer

- OpenClaw-facing skills for the digest workflow
- OpenClaw-specific wrappers that call the core library

### Recommended examples of code that move

- `scripts/email/`
- `scripts/gmail/send-gog-digest.sh`
- `workspace/scripts/extract-newsletter-from-gmail.sh`
- `workspace/scripts/render-newsletter-digest.sh`
- `workspace/scripts/finalize-newsletter-digest.sh`
- `workspace/scripts/send-gog-digest.sh`
- `workspace/skills/pip-newsletter-digest/`
- `workspace/skills/pip-newsletter-digest-format/`
- `workspace/skills/pip-gmail-send/`
- likely most of `workspace/skills/pip-gmail-gog/` after it is generalized

### Data model and fixtures that move

- sanitized newsletter fixtures
- regression tests for extraction/render/send
- digest schema docs
- adapter docs

## What should not stay app-specific in this repo

This repo should stop being the long-term home for:

- Pip-specific digest orchestration
- digest-specific renderer/theme choices
- newsletter-specific extraction heuristics
- email send semantics specific to the digest product

Those belong in the newsletter repo, even if this repo continues to consume them.

## Shape of the new newsletter repo

The new repo can still be a monorepo internally. That is probably the cleanest way to expose both reusable code and framework adapters without fragmenting too early.

Recommended structure:

```text
agent-email-digest/
  packages/
    core/
    provider-gmail/
    transport-gmail-gog/
    renderer-email/
    adapter-openclaw/
  skills/
    openclaw/
  fixtures/
  examples/
    pip-digest/
  docs/
```

### `packages/core`

Owns:

- source artifact contract
- digest JSON contract
- shared validation
- common interfaces

### `packages/provider-gmail`

Owns:

- Gmail search/fetch integration
- extraction helpers
- normalized output artifacts

### `packages/transport-gmail-gog`

Owns:

- Gmail delivery through `gog`
- `send-result.json` contract

### `packages/renderer-email`

Owns:

- deterministic `digest.json -> email.html + email.txt`
- themes/templates
- validation/sanitization

### `packages/adapter-openclaw`

Owns:

- OpenClaw wrapper scripts
- OpenClaw skill text
- OpenClaw-specific contracts and install story

## Stable contract surface

Before physically splitting files, treat these as the public contract that the new repo will own.

### Source artifacts

- `metadata.json`
- `links.json`
- `clean.md`
- `extracted.json`

### Digest artifacts

- `digest.json`
- `email.html`
- `email.txt`
- `summary.json`
- `send-result.json`

### Contract rules

- `digest.json` is the source of truth for final content
- rendering is deterministic from `digest.json`
- send helpers archive machine-readable results
- caches are versioned

## How this repo should consume the newsletter repo later

Long term, this repo should not vendor the newsletter workflow manually.

Preferred order of maturity:

1. split code into the new repo while this repo still references it via local checkout or subtree during development
2. make the newsletter repo publishable as one or more npm packages plus OpenClaw skill assets
3. have this repo consume a released version of the newsletter repo

Practical near-term options:

- git subtree while interfaces are still unstable
- local path dependency during development
- released npm packages once interfaces settle

Recommendation:

- use a local path / manual sync phase first
- do not optimize for package publishing until the contracts are stable

## Migration plan

### Phase 1: boundary cleanup inside this repo

Goal:

- make the split obvious before actually extracting files

Tasks:

- separate runtime docs from digest docs more clearly
- reduce cross-coupling between runtime scripts and digest scripts
- keep moving digest orchestration into code-owned runner/finalizer layers
- keep local/cloud behavior aligned

### Phase 2: freeze contracts

Goal:

- define what the newsletter repo will export

Tasks:

- document source artifact schema
- document digest JSON schema
- document renderer inputs/outputs
- document send helper inputs/outputs
- version cache format and schema format

### Phase 3: extract deterministic newsletter code

Goal:

- move workflow code before prompts

Tasks:

- move `scripts/email/*`
- move digest send helper
- move renderer
- move fixture tests and sanitized data

### Phase 4: extract OpenClaw adapter

Goal:

- move framework-specific wrapper layer

Tasks:

- move digest skills
- move wrapper scripts under `workspace/scripts`
- generalize names away from Pip where appropriate

### Phase 5: make this repo a consumer

Goal:

- this repo becomes an integrator of the newsletter repo, not its long-term home

Tasks:

- update local/cloud images to consume released newsletter artifacts
- keep an example Pip implementation here only if it helps demonstrate integration

## File-by-file first-pass move map

This is the first-pass extraction map, not the final package boundary.

### Move to newsletter repo

- `scripts/email/extract-newsletter-from-gmail.mjs`
- `scripts/email/render-newsletter-digest.mjs`
- `scripts/email/finalize-newsletter-digest.sh`
- `scripts/gmail/send-gog-digest.sh`
- `workspace/scripts/extract-newsletter-from-gmail.sh`
- `workspace/scripts/render-newsletter-digest.sh`
- `workspace/scripts/finalize-newsletter-digest.sh`
- `workspace/scripts/send-gog-digest.sh`
- `workspace/skills/pip-newsletter-digest/SKILL.md`
- `workspace/skills/pip-newsletter-digest-format/SKILL.md`
- `workspace/skills/pip-gmail-send/SKILL.md`

### Keep in runtime repo

- `docker/*`
- `config/openclaw.*`
- `config/secrets.*.example`
- `scripts/run-cloud.sh`
- `scripts/rebuild-cloud.sh`
- `scripts/restart-cloud.sh`
- `scripts/run-local.sh`
- `scripts/rebuild-local-docker.sh`
- `scripts/prepare-local-docker.sh`
- `scripts/deploy-cloud.sh`
- `scripts/install-cloud-host.sh`
- `scripts/tunnel-cloud-gateway.sh`
- `scripts/show-local-agent-logs.sh`
- `scripts/show-cloud-agent-logs.sh`
- `scripts/render-openclaw-config.mjs`
- `scripts/push-cloud-runtime-secret.sh`
- `scripts/apply-cloud-cron.sh`
- `scripts/apply-local-cron.sh`
- `scripts/print-local-docker-access.sh`
- `opentofu/**`

### Needs review before deciding

- `workspace/skills/pip-gmail-gog/SKILL.md`
  - if it stays digest-specific, move it
  - if it becomes a generic Gmail/OpenClaw operations skill, keep it here or extract to a more generic adapter package
- `workspace/skills/allowed-web-research/`
  - likely runtime/workspace policy, so probably stays

## Security and privacy review

Before any public extraction, scrub more than just secrets.

### Remove or sanitize

- personal email addresses
- project IDs
- VM names
- hostnames
- local absolute paths
- screenshots from real inboxes
- session transcripts with private content
- real newsletter artifacts under `workspace/memory`
- secret names that are too specific to the private deployment

### Replace with

- synthetic fixtures
- neutral example users
- generic project naming
- documented env var shapes

## Generalization targets for the newsletter repo

The new repo should not stay forever tied to Pip.

High-value generalizations:

- configurable source definitions
- configurable section order
- configurable rendering theme
- transport abstraction beyond `gog`
- optional non-OpenClaw execution path

What should remain opinionated:

- artifact-backed workflow
- deterministic renderer
- schema-first handoffs
- explicit cache invalidation/versioning

## Ergonomics targets for the runtime repo

This repo should evolve into a good operator experience for OpenClaw on GCP and local Docker.

High-value improvements:

- clearer command naming
- lighter config-only rollout path
- stronger smoke checks after deploy
- native-local parity checks
- better compatibility docs between runtime and app packages
- less quoting-heavy cloud command execution

## Dependency strategy

### Runtime repo

Should own:

- OpenClaw version pin
- `gog` installation and provisioning
- Docker base image pins
- cloud host package policy
- infra module versions

### Newsletter repo

Should own:

- extraction/render/send package versions
- schema versions
- fixture and regression coverage
- adapter logic that knows how to use runtime-provided capabilities such as `gog`, without provisioning those capabilities itself

### Compatibility story

Eventually publish a simple matrix:

- runtime repo version X supports newsletter repo version Y

Without that, upgrades will become guesswork.

## Recommended immediate next steps

1. create a concrete extraction checklist from the move map above
2. prepare the new newsletter repo skeleton and package layout
3. move deterministic newsletter code first
4. leave this repo as the runtime proving ground until the new repo contracts settle

## Short version

The split is:

- this repo = OpenClaw runtime + GCP/local infra + config + operational tooling
- new repo = newsletter ingestion/extraction/digest/render/send system

That is the cleanest way to:

- open-source useful parts sooner
- keep security review manageable
- improve ergonomics independently on each side
- evolve the newsletter system toward broader reuse without entangling it with the GCP/OpenClaw runtime story
