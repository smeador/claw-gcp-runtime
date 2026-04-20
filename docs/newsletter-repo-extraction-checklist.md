# Newsletter Repo Extraction Checklist

This checklist turns the high-level split plan into an execution sequence.

Working assumptions:

- this repo remains the OpenClaw runtime / GCP / local-cloud infra repo
- a new repo will hold the newsletter extraction, digest, rendering, and send system
- the live Pip workflow must keep working during the transition
- deterministic code moves before skill text and prompt layers

## Guardrails

- do not break the live Pip digest flow while extracting code
- prefer temporary compatibility shims over big-bang cutovers
- keep `gog` as a runtime-provided capability from this repo
- keep OpenClaw-specific logic at the adapter boundary, not in the newsletter core
- keep local Docker and cloud behavior aligned as changes land

## Phase 1: Freeze boundaries in this repo

Goal:

- make the runtime-vs-newsletter boundary explicit before moving code

Tasks:

- [ ] keep [docs/open-source-plan.md](/Users/sean/Repos/gcp-claw-lab/docs/open-source-plan.md) as the source of truth for repo ownership boundaries
- [ ] keep runtime-specific docs in this repo and avoid adding new digest-product docs here unless they are integration-specific
- [ ] identify any remaining newsletter-specific logic that still lives in runtime scripts and note it for cleanup
- [ ] confirm which `workspace/skills/*` are newsletter-specific versus runtime/workspace policy

## Phase 2: Freeze public contracts

Goal:

- define what the new repo will export before moving files

Tasks:

- [ ] write a source-artifact contract doc for:
  - `metadata.json`
  - `links.json`
  - `clean.md`
  - `extracted.json`
- [ ] write a digest contract doc for:
  - `digest.json`
- [ ] write a render/send contract doc for:
  - `email.html`
  - `email.txt`
  - `summary.json`
  - `send-result.json`
- [ ] document extractor cache versioning and invalidation rules
- [ ] document the expected provider/transport interfaces at a high level

## Phase 3: Prepare the new repo skeleton

Goal:

- create the target structure before copying logic over

Tasks:

- [ ] create the new repo with a package-oriented layout
- [ ] scaffold:
  - `packages/core`
  - `packages/provider-gmail`
  - `packages/renderer-email`
  - `packages/transport-gmail-gog`
  - `packages/adapter-openclaw`
- [ ] add a minimal README explaining the layer split
- [ ] add placeholders for fixtures and regression tests
- [ ] add an `examples/pip-digest` directory for the current live workflow shape

## Phase 4: Move deterministic newsletter code first

Goal:

- extract code-owned mechanics before prompts/skills

Primary candidates to move first:

- [ ] [scripts/email/extract-newsletter-from-gmail.mjs](/Users/sean/Repos/gcp-claw-lab/scripts/email/extract-newsletter-from-gmail.mjs)
- [ ] [scripts/email/render-newsletter-digest.mjs](/Users/sean/Repos/gcp-claw-lab/scripts/email/render-newsletter-digest.mjs)
- [ ] [scripts/email/finalize-newsletter-digest.sh](/Users/sean/Repos/gcp-claw-lab/scripts/email/finalize-newsletter-digest.sh)
- [ ] [scripts/gmail/send-gog-digest.sh](/Users/sean/Repos/gcp-claw-lab/scripts/gmail/send-gog-digest.sh)

Tasks:

- [ ] move the files into the new repo without changing behavior yet
- [ ] keep compatibility wrappers here temporarily if this repo still imports the old paths
- [ ] port existing validation and sanitization behavior unchanged first
- [ ] move related tests or add first-pass snapshot/regression coverage immediately after each move

## Phase 5: Move OpenClaw wrappers and adapter code

Goal:

- move the framework-specific integration layer after the deterministic core is stable

Primary candidates:

- [ ] [workspace/scripts/extract-newsletter-from-gmail.sh](/Users/sean/Repos/gcp-claw-lab/workspace/scripts/extract-newsletter-from-gmail.sh)
- [ ] [workspace/scripts/render-newsletter-digest.sh](/Users/sean/Repos/gcp-claw-lab/workspace/scripts/render-newsletter-digest.sh)
- [ ] [workspace/scripts/finalize-newsletter-digest.sh](/Users/sean/Repos/gcp-claw-lab/workspace/scripts/finalize-newsletter-digest.sh)
- [ ] [workspace/scripts/send-gog-digest.sh](/Users/sean/Repos/gcp-claw-lab/workspace/scripts/send-gog-digest.sh)
- [ ] [workspace/skills/pip-newsletter-digest/SKILL.md](/Users/sean/Repos/gcp-claw-lab/workspace/skills/pip-newsletter-digest/SKILL.md)
- [ ] [workspace/skills/pip-newsletter-digest-format/SKILL.md](/Users/sean/Repos/gcp-claw-lab/workspace/skills/pip-newsletter-digest-format/SKILL.md)
- [ ] [workspace/skills/pip-gmail-send/SKILL.md](/Users/sean/Repos/gcp-claw-lab/workspace/skills/pip-gmail-send/SKILL.md)

Tasks:

- [ ] move the wrappers into the OpenClaw adapter package in the new repo
- [ ] decide whether [workspace/skills/pip-gmail-gog/SKILL.md](/Users/sean/Repos/gcp-claw-lab/workspace/skills/pip-gmail-gog/SKILL.md) belongs in the newsletter repo or stays as a more generic runtime skill
- [ ] keep temporary wrapper stubs in this repo if needed so the existing workspace still functions during migration

## Phase 6: Add sanitized fixtures and tests

Goal:

- make the new repo safe and regression-friendly before wider publishing

Tasks:

- [ ] create sanitized fixtures for:
  - NYT-style HTML newsletters
  - Daily Upside weekday issues
  - Daily Upside Sunday long-form issues
  - AI News / Substack issues
  - generic Substack items
- [ ] add renderer snapshot tests
- [ ] add send-helper contract tests
- [ ] add extraction regression tests for known bad cases:
  - redirect links
  - newsletter chrome
  - malformed HTML
  - empty sections

## Phase 7: Make this repo consume the new repo

Goal:

- turn this repo into an integrator rather than the long-term home of newsletter code

Tasks:

- [ ] choose an intermediate integration mode:
  - local path dependency
  - subtree
  - manual vendoring during the transition
- [ ] update Docker/local/cloud build flows here to consume the extracted newsletter code from the new repo
- [ ] verify cloud deploy, local Docker deploy, and native local workflow behavior after integration
- [ ] remove temporary compatibility wrappers once the new repo is the clear source of truth

## Phase 8: Generalize after the split

Goal:

- improve reuse only after the code is in the right home

Tasks:

- [ ] generalize Pip-specific naming where it materially improves reuse
- [ ] keep a `pip` example as a compatibility/example layer rather than the core identity
- [ ] remove Pip-specific runtime framing from this repo over time
- [ ] generalize source definitions, theming, and transport interfaces in the newsletter repo

## Pip-specific transition note

For now:

- keep the Pip workflow working as-is
- keep Pip-specific skills and naming if they are still the compatibility surface

Later:

- this runtime repo should not stay Pip-branded in its long-term open-source identity
- Pip should become an example implementation or compatibility layer, not the conceptual center of the runtime repo

## Dependency split

### This repo owns runtime capabilities

- OpenClaw installation and version pinning
- `gog` installation and provisioning
- Docker/cloud/native environment behavior
- secret rendering
- auth wiring

### Newsletter repo owns workflow usage

- digest extraction/render/send code
- `gog`-based transport adapter usage
- OpenClaw adapter usage

Rule of thumb:

- runtime repo provisions capabilities
- newsletter repo consumes them through adapters

## First concrete extraction milestone

The first meaningful milestone should be:

- the new repo contains the deterministic extraction/render/send code
- this repo still runs the Pip workflow through compatibility wrappers
- no live behavior changes are introduced yet beyond path/package ownership

That is the safest place to validate the split before pushing into naming/generalization work.
