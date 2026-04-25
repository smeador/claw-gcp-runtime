# Integration Interface Draft

This document defines the lightweight composition boundary between:

- the runtime repo
- an integration repo such as `agent-newsletter-digest`

The goal is to keep the interface small, explicit, and easy to evolve without pulling
workflow logic back into the runtime repo.

## Goals

- keep the runtime repo generic
- keep the integration repo runtime-agnostic except for its adapter layer
- let local sibling checkouts work with minimal ceremony
- support OpenClaw skill composition without inventing a heavy plugin framework
- keep testing generic on the runtime side and workflow-specific on the integration side

## Non-goals

- package publishing or registry distribution right now
- formal version pinning right now
- a large plugin SDK
- forcing everything into package-workspace abstractions before the boundaries settle

## Boundary

### Runtime owns

- OpenClaw install and lifecycle
- Docker/native/cloud orchestration
- `gog` install and capability provisioning
- auth/bootstrap/secrets rendering
- integration discovery and staging
- reviewed workspace assembly
- generic runtime test tiers
- generic skill-test dispatch

### Integration owns

- newsletter extraction
- digest shaping
- deterministic rendering
- send/finalize flow
- workflow-specific OpenClaw skills
- workflow-specific skill tests
- workflow-specific fixtures and regression tests

### Workspace owns

- the composed reviewed skill surface
- minimal context-specific glue only

It should not become a second implementation home for workflow mechanics.

## Interface options

### Option A: direct sibling conventions

Runtime knows:

- sibling repo path
- specific skill directory names
- specific bin names

Pros:

- smallest immediate change
- easy during active development

Cons:

- runtime knows too much about integration internals
- harder to support multiple integrations cleanly
- brittle as repo structure evolves

### Option B: manifest-based integration

Runtime knows:

- integration root
- one small manifest schema

Pros:

- still lightweight
- explicit ownership
- easy to add another integration later
- runtime stays generic

Cons:

- requires a little manifest plumbing

### Option C: published package exports

Runtime installs a package and consumes declared exports.

Pros:

- clean long-term distribution
- reproducible release model

Cons:

- more process and packaging overhead than we need right now

## Recommendation

Use **Option B: manifest-based integration**.

This keeps the runtime generic without adding much machinery.

## Proposed runtime-side config

The runtime repo keeps a small composition file, for example:

```json
{
  "integrations": [
    {
      "name": "agent-newsletter-digest",
      "root": "../agent-newsletter-digest",
      "rootEnv": "AGENT_NEWSLETTER_DIGEST_ROOT"
    }
  ]
}
```

The runtime should not also need to know:

- specific skill names
- specific bin names
- workflow semantics

Those come from the integration manifest instead.

## Proposed integration manifest

Each integration repo exposes one root manifest, for example:

```json
{
  "name": "agent-newsletter-digest",
  "adapter": {
    "type": "openclaw",
    "skillsRoot": "adapter/openclaw/skills",
    "skillTestRunner": "adapter/openclaw/run-skill-test.sh",
    "testSkill": "pip-newsletter-digest"
  },
  "smokeTests": [
    {
      "name": "extract-help",
      "command": ["agent-newsletter-digest-extract", "--help"]
    },
    {
      "name": "render-help",
      "command": ["agent-newsletter-digest-render", "--help"]
    }
  ]
}
```

This manifest should answer only:

- where are the skills?
- how does the runtime run a generic skill test?
- which skill should the runtime use for adapter smoke validation?
- which lightweight smoke commands can the runtime execute generically?

It should not encode runtime deployment details.

## Recommended `agent-newsletter-digest` layout

The current repo still has placeholder `packages/*` directories and real code under
top-level `scripts/`. For the next hardening pass, prefer a simpler shape:

```text
agent-newsletter-digest/
  README.md
  integration.json
  docs/
  adapter/
    openclaw/
      run-skill-test.sh
      skills/
        pip-newsletter-digest/
        pip-newsletter-digest-format/
        pip-gmail-send/
  lib/
    extract/
    render/
    send/
  bin/
    extract
    render
    finalize
    send
  examples/
    pip-digest/
  tests/
    fixtures/
    regression/
```

### Why this shape

- `adapter/openclaw` clearly isolates runtime-specific assets
- `lib/*` holds runtime-agnostic implementation
- `bin/*` stays thin and executable
- it is simpler than pretending we already have a fully modular package workspace

If we later want package workspaces, we can introduce them after the structure is real.

## Composition flow

### Runtime composition

1. resolve the integration root from runtime config
2. read `integration.json`
3. copy declared skills into the reviewed workspace skill surface
4. expose declared bins into the runtime image or local `PATH`
5. keep the integration staged under a runtime-owned path for inspection

### Skill execution

OpenClaw then sees only the reviewed workspace skill surface.

The runtime does not need to know what those skills do internally.

## Test flow

### Runtime tests

The runtime keeps:

- `agent-runtime local test basic`
- `agent-runtime local test core`
- `agent-runtime local test integration`

These validate runtime health, not workflow semantics.

### Skill tests

The runtime provides generic dispatch:

```bash
agent-runtime local test skill pip-newsletter-digest
agent-runtime cloud test skill pip-newsletter-digest
```

The integration provides the actual implementation via its declared skill test runner.

That means:

- runtime resolves the integration and skill
- integration decides how to test the workflow

This keeps the runtime generic.

## Rules of thumb

### If the runtime needs to know it is a newsletter

That is a smell.

Prefer:

- generic skill dispatch
- generic command exposure
- generic integration staging

### If another runtime would still need the logic

That logic belongs in the integration repo, not the runtime repo.

### If the only reason something exists is migration

Delete it after the new composition path is stable.

## Short-term recommendation

For now:

- keep sibling local checkout composition
- add a small integration manifest
- simplify `agent-newsletter-digest` around `adapter/`, `lib/`, and `bin/`
- keep the runtime generic and manifest-driven

Do not:

- add publishing complexity yet
- add version pinning yet
- build a larger plugin system yet

## Open questions

- whether `workspace/skills/pip-gmail-gog` remains runtime-owned capability guidance or moves into an integration/adaptor repo
- whether Pip-specific cron aliases remain in the runtime repo as the current concrete composition or move behind a more generic integration mechanism
- whether the integration manifest should later grow optional metadata for fixtures, health checks, or docs links
