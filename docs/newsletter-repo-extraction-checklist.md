# Newsletter Repo Extraction Checklist

This checklist tracks the stricter split we agreed on:

- this repo stays runtime-first and integration-generic
- [`agent-newsletter-digest`](/Users/sean/Repos/agent-newsletter-digest) owns newsletter mechanics
- `workspace/` in this repo remains a composed surface, not an implementation home

## Guardrails

- keep the live Pip workflow working
- do not reintroduce newsletter implementation into runtime repo scripts
- keep `agent-runtime` generic
- let skills provide their own workflow-specific test entrypoints
- keep local Docker and cloud behavior aligned

## Phase 1: Lock the boundary

Goal:

- make the runtime/newsletter ownership line obvious in code and docs

Tasks:

- [x] update the runtime docs to describe this repo as the runtime and composition host
- [x] remove repo-root newsletter implementation and compatibility copies
- [x] stop treating `workspace/` as the long-term home of newsletter scripts
- [ ] review whether any remaining Pip-specific runtime commands should become more generic aliases

## Phase 2: Generic integration composition

Goal:

- let the runtime consume integrations without learning their workflow details

Tasks:

- [x] add a reviewed integration manifest:
  - [workspace/integrations.json](/Users/sean/Repos/gcp-claw-lab/workspace/integrations.json)
- [x] stage integrations into:
  - [`.runtime/integrations`](/Users/sean/Repos/gcp-claw-lab/.runtime/integrations)
- [x] expose composed skills under:
  - [workspace/skills](/Users/sean/Repos/gcp-claw-lab/workspace/skills)
- [x] install integration-provided CLI entrypoints into the runtime image
- [ ] validate the same model for native local later

## Phase 3: Generic skill testing

Goal:

- let the runtime test skills without embedding workflow logic

Tasks:

- [x] add:
  - `agent-runtime local test skill <skill>`
  - `agent-runtime cloud test skill <skill>`
- [x] make the newsletter skill package provide its own test entrypoint
- [ ] decide whether digest-specific runtime aliases should remain long-term or become compatibility-only
- [ ] document a reusable convention only if a second integration needs it

## Phase 4: Newsletter repo ownership

Goal:

- ensure `agent-newsletter-digest` is the only implementation home for newsletter mechanics

Tasks:

- [x] move extraction/render/send commands there
- [x] move OpenClaw skill assets there
- [x] move workflow-specific test logic there
- [ ] decide the long-term home of [workspace/skills/pip-gmail-gog/SKILL.md](/Users/sean/Repos/gcp-claw-lab/workspace/skills/pip-gmail-gog/SKILL.md)
- [ ] keep reducing runtime-doc assumptions about newsletter-specific commands

## Phase 5: Runtime hardening

Goal:

- make this repo strong as a standalone runtime project

Tasks:

- [x] add local runtime validation tiers:
  - `basic`
  - `core`
  - `integration`
- [ ] consider cloud-side `basic` and `core` validation later
- [ ] review command ergonomics and simplify where helpful
- [ ] keep the CLI/help/docs aligned with the staged integration model

## Phase 6: Newsletter repo hardening

Goal:

- make the newsletter repo independently reviewable and publishable later

Tasks:

- [ ] add sanitized fixtures
- [ ] add extraction regression tests
- [ ] add renderer snapshot tests
- [ ] add send-helper contract tests
- [ ] document provider and transport interfaces
- [ ] document cache versioning and invalidation

## Phase 7: Open-source readiness

Goal:

- make both repos safe and understandable for broader use

Tasks:

- [ ] security scrub for personal identifiers and private artifacts
- [ ] public-facing READMEs and contribution docs
- [ ] support boundary and compatibility notes
- [ ] optional version-pinning story later, after the local-sibling workflow stabilizes

## Rule of thumb

When deciding where something belongs, ask:

> Would another runtime still need this for the newsletter workflow to work?

- if yes, it belongs in `agent-newsletter-digest`
- if it is generic runtime capability or composition, it belongs here
- if it is only temporary migration glue, remove it
