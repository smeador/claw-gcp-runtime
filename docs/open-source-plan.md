# Open Source Plan

## Decision

We are standardizing on a two-repo split:

1. this repo is the OpenClaw runtime / GCP infra / local-cloud operating model repo
2. [`agent-newsletter-digest`](/Users/sean/Repos/agent-newsletter-digest) is the newsletter workflow repo

This is a split between:

- a reusable runtime and composition host
- a reusable workflow implementation and adapter package

The live Pip workflow remains the proving ground, but it should no longer determine where ownership lives.

## Core boundary

The key rule is:

- runtime repo provisions generic capabilities
- integration repos consume those capabilities
- `workspace/` is the composed view, not the long-term home of workflow logic

That means:

- if logic is required for the newsletter system to run in any runtime, it belongs in `agent-newsletter-digest`
- if logic is required to run OpenClaw locally, in Docker, or on GCP, it belongs here
- if a file only exists to compose the current runtime with installed integrations, it may live in `workspace/`
- if a script only existed to bridge the old split, remove it

## Repo A: this repo

Recommended future identity:

- `openclaw-runtime-gcp`

Purpose:

- reproducible OpenClaw setup across native local, Docker local, and GCP cloud
- deterministic config rendering
- deterministic state layout
- deploy/rebuild/restart/test ergonomics
- integration staging and composed workspace assembly
- tunnel, logs, cron, and operator helpers

This repo should answer:

- how do I run OpenClaw locally and on GCP with the same operating model?
- how do I provision capabilities such as `gog`, auth, secrets, mounts, logs, and cron?
- how do I compose one or more workflow integrations into a reviewed runtime workspace?

### What stays here

- `docker/`
- `opentofu/`
- runtime-oriented `config/`
- version pinning and sync logic
- local/cloud lifecycle scripts
- generic runtime tests
- integration staging logic
- operator docs and specs

### Runtime-owned examples

- [docker/Dockerfile](/Users/sean/Repos/gcp-claw-lab/docker/Dockerfile)
- [docker/compose.local.yml](/Users/sean/Repos/gcp-claw-lab/docker/compose.local.yml)
- [docker/compose.cloud.yml](/Users/sean/Repos/gcp-claw-lab/docker/compose.cloud.yml)
- [scripts/runtime.mjs](/Users/sean/Repos/gcp-claw-lab/scripts/runtime.mjs)
- [scripts/stage-workspace-integrations.mjs](/Users/sean/Repos/gcp-claw-lab/scripts/stage-workspace-integrations.mjs)
- [scripts/install-staged-integrations.mjs](/Users/sean/Repos/gcp-claw-lab/scripts/install-staged-integrations.mjs)
- [scripts/run-local-skill-test.sh](/Users/sean/Repos/gcp-claw-lab/scripts/run-local-skill-test.sh)
- [scripts/run-cloud-skill-test.sh](/Users/sean/Repos/gcp-claw-lab/scripts/run-cloud-skill-test.sh)
- [scripts/runtime-lifecycle.sh](/Users/sean/Repos/gcp-claw-lab/scripts/runtime-lifecycle.sh)
- [scripts/sync-cloud-app.sh](/Users/sean/Repos/gcp-claw-lab/scripts/sync-cloud-app.sh)
- [scripts/tunnel-cloud-gateway.sh](/Users/sean/Repos/gcp-claw-lab/scripts/tunnel-cloud-gateway.sh)
- [scripts/show-local-agent-logs.sh](/Users/sean/Repos/gcp-claw-lab/scripts/show-local-agent-logs.sh)
- [scripts/show-cloud-agent-logs.sh](/Users/sean/Repos/gcp-claw-lab/scripts/show-cloud-agent-logs.sh)
- [workspace/integrations.json](/Users/sean/Repos/gcp-claw-lab/workspace/integrations.json)

### What should not stay here

- newsletter extraction logic
- deterministic digest rendering
- digest finalization/send logic
- newsletter-specific wrapper scripts
- compatibility copies of newsletter implementation

## Repo B: `agent-newsletter-digest`

Purpose:

- ingest newsletter/email sources
- extract cleaned artifacts
- synthesize digest content
- render deterministic email output
- send through pluggable transports
- expose OpenClaw adapter commands and skills

This repo should answer:

- how do I turn newsletters into structured digest artifacts?
- how do I package that workflow for OpenClaw or another runtime?

### What belongs there

- extraction/render/send scripts
- schema and contract ownership
- skill text and workflow-specific commands
- skill-owned test entrypoints
- fixtures and regression tests

## Execution model

### Runtime view

The runtime should stay generic.

`agent-runtime` should know about:

- environments such as `local` and `cloud`
- generic operations such as `deploy`, `restart`, `logs`, `cron`, and runtime test tiers
- generic skill dispatch such as:
  - `agent-runtime local test skill pip-newsletter-digest`

It should not know what a newsletter digest is beyond treating it as a skill name.

### Integration view

The integration package should provide:

- installable commands on `PATH`
- skill directories under its own `workspace/skills`
- any `TEST.sh` entrypoint needed for generic runtime testing

### Workspace view

The reviewed workspace should contain:

- runtime policy
- runtime-owned scratch and memory paths
- copied skill assets staged from declared integrations
- minimal context-specific glue only

It should not become a second implementation home for newsletter mechanics.

## Integration mechanism

The current preferred development model is:

- sibling local checkout for the integration repo
- latest local code during active development
- runtime repo stages integrations from [workspace/integrations.json](/Users/sean/Repos/gcp-claw-lab/workspace/integrations.json)
- staged integrations are copied under [`.runtime/integrations`](/Users/sean/Repos/gcp-claw-lab/.runtime/integrations)
- the composed workspace exposes those skills under [workspace/skills](/Users/sean/Repos/gcp-claw-lab/workspace/skills)

This keeps development fast without forcing release pinning yet.

Longer term, optional pinning can be added after the boundaries settle.

## Stable contract surface

Concrete contract docs in this repo currently live at:

- [docs/contracts/source-artifact-contract.md](/Users/sean/Repos/gcp-claw-lab/docs/contracts/source-artifact-contract.md)
- [docs/contracts/digest-json-contract.md](/Users/sean/Repos/gcp-claw-lab/docs/contracts/digest-json-contract.md)
- [docs/contracts/render-send-contract.md](/Users/sean/Repos/gcp-claw-lab/docs/contracts/render-send-contract.md)
- [docs/contracts/openclaw-runtime-expectations.md](/Users/sean/Repos/gcp-claw-lab/docs/contracts/openclaw-runtime-expectations.md)

The newsletter repo should eventually become the source of truth for the workflow-specific contracts, while this repo keeps the runtime-expectations side.

## Migration phases

### Phase 1: runtime clarity

Goal:

- make this repo clearly runtime-first and integration-generic

Tasks:

- document the stricter boundary
- remove repo-root newsletter implementation and compatibility copies
- stage integrations generically
- keep `agent-runtime` generic

### Phase 2: integration ownership

Goal:

- make the newsletter repo clearly own all newsletter mechanics

Tasks:

- keep moving workflow logic into `agent-newsletter-digest`
- keep skill-owned commands and `TEST.sh` there
- avoid reintroducing workflow scripts into `workspace/`

### Phase 3: testing and hardening

Goal:

- make both repos independently reviewable and safe to publish later

Tasks:

- add fixtures and regression tests in `agent-newsletter-digest`
- expand runtime validation here
- document native-local integration later

### Phase 4: open-source readiness

Goal:

- make both repos safe and understandable for others

Tasks:

- security scrub
- public README and contribution docs
- support boundary and compatibility docs
- eventual version pinning story if and when it becomes useful

## Dependency split

### Runtime repo owns capability provisioning

- OpenClaw installation and versioning
- `gog` installation and availability
- auth provisioning
- Docker/cloud/native behavior
- config and secret rendering

### Integration repo owns capability usage

- calling `gog`
- digest-specific extraction/render/send flow
- skill commands and test entrypoints

Rule of thumb:

- runtime provisions
- integration consumes

## Transitional note on Pip

Pip can remain the current example workflow and compatibility surface for now.

Long term:

- Pip should not define the public identity of the runtime repo
- Pip should become an example integration rather than the conceptual center of the project
