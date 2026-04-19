# Open Source Plan

## Goal

Work toward open-sourcing this project by separating it into reusable, cleaner public surfaces instead of publishing the current repo as-is.

The likely shape is:

1. an email/digest package that is useful beyond this specific repo and beyond OpenClaw
2. an OpenClaw runtime/setup package for consistent native-local, Docker-local, and cloud usage on GCP

The current repo remains valuable as the proving ground and reference implementation, but it is doing too many jobs at once to open-source cleanly without refactoring.

## Proposed initiatives

### 1. Agent Email Digest

Purpose:

- general-purpose email ingestion
- newsletter extraction
- selection logic
- summarization handoff
- deterministic rendering
- delivery helpers

Audience:

- any agent framework
- any user who wants a structured email-to-digest pipeline

Important design direction:

- the core should not be OpenClaw-specific
- OpenClaw skills should exist as one adapter path, not as the core abstraction

### 2. OpenClaw Runtime on GCP

Purpose:

- provide a reproducible OpenClaw operating model across:
  - native local
  - Docker local
  - cloud
- package the operational patterns for:
  - state layout
  - deploy/rebuild behavior
  - secret rendering
  - cron/job execution
  - gateway access
  - logging and debugging

Audience:

- people who want an opinionated, reproducible OpenClaw setup
- especially people working across local and cloud environments

## Core principle

The main lesson from this repo should become a public design principle:

- code owns deterministic mechanics
- agent instructions own judgment

That means:

- extraction artifacts should be deterministic
- output schemas should be deterministic
- rendering should be deterministic
- send helpers should be deterministic
- agent skills/prompts should focus on selection and synthesis, not operational choreography

## Recommended repo boundaries

### Repo 1: `agent-email-digest`

This should contain:

- core extraction pipeline
- source artifact generation
- digest output schema
- deterministic renderer
- delivery helpers
- provider adapters
- framework adapters
- tests and fixtures

Suggested internal split:

- `core/`
- `providers/`
- `renderers/`
- `transports/`
- `adapters/openclaw/`

### Repo 2: `openclaw-runtime-gcp`

This should contain:

- Docker local setup
- cloud deploy and rebuild flows
- GCP VM/container setup
- state layout rules
- secret rendering
- cron/job tooling
- gateway/tunnel access helpers
- logs/debug commands
- version and dependency management patterns

### Optional example app

Even if it does not become its own repo immediately, keep an example implementation somewhere visible.

It should demonstrate:

- how to combine the runtime with the digest package
- a real digest configuration
- an end-to-end workflow

This matters because otherwise the public packages risk becoming too abstract.

## Public API / contract design

Before splitting repos, define the stable contracts.

### Source artifact contract

For example:

- `metadata.json`
- `links.json`
- `clean.md`
- `extracted.json`

### Digest contract

For example:

- `digest.json`

This should be the source of truth for rendering and send flows.

### Renderer contract

For example:

- `digest.json -> email.html + email.txt`

### Delivery contract

For example:

- helper inputs
- helper outputs
- `send-result.json`

If these contracts are clean and versioned, the package can support:

- OpenClaw
- future agent frameworks
- direct CLI workflows
- non-agent use cases later

## Framework-specific logic should be adapters

If the goal is model/framework agnosticism, skills cannot be the core abstraction.

Better structure:

- core library owns extraction, schemas, rendering, helpers
- adapters own framework-specific prompting and orchestration

Examples of adapter layers:

- OpenClaw skills
- future prompt packs for other frameworks
- direct CLI wrappers

## Security and privacy review

This needs to be broader than just secret scanning.

### Remove or scrub:

- personal email addresses
- domains
- hostnames
- VM names
- project IDs
- local filesystem paths
- session logs
- gateway auth tokens
- runtime config render paths
- cached newsletter artifacts
- screenshots containing private inbox content

### Review operational scripts for:

- assumptions about your specific accounts
- assumptions about your exact directory layout
- assumptions about your secret names
- anything that could be copied and used against you directly

## Legal / copyright / content concerns

If the digest package processes newsletters, avoid shipping real content unless you are certain that is okay.

Preferred open-source posture:

- synthetic fixtures
- neutral example newsletters
- sanitized examples

Avoid publishing:

- full real newsletter bodies
- real cached source artifacts
- long copied excerpts from proprietary newsletters

## Configuration model

The public version should move more behavior into config and less into repo-specific conventions.

Good candidates for config:

- source definitions
  - sender matching
  - subject matching
  - extraction hints
- section definitions
  - order
  - required vs optional
  - empty-state handling
- rendering/theme definitions
- delivery definitions
- framework adapter settings

If config is clean, the package becomes reusable rather than just portable.

## Rendering and theming

The digest renderer should not be locked forever to one style.

Recommended direction:

- deterministic renderer core
- theme configuration
- a small number of built-in email-safe themes

This reduces the need for downstream forks just to change typography or layout.

## Provider abstraction

Separate these concerns explicitly:

- inbox provider
  - Gmail first
  - IMAP later if needed
- delivery provider
  - Gmail send first
  - SMTP later if needed
- agent framework
  - OpenClaw first
  - others later

Important seams:

- search
- fetch/extract
- render
- send

## Testing strategy

Open source needs stronger regression protection than an internal proving-ground repo.

Recommended coverage:

- extractor fixture tests
- renderer snapshot tests
- helper CLI tests
- end-to-end dry-run tests
- regression fixtures for known bad cases

Known special cases worth protecting:

- Substack app links
- redirect links
- Daily Upside Sunday long-form editions
- empty sections
- malformed HTML
- sources with heavy newsletter chrome

## Release and versioning strategy

### Digest package

Version:

- output schema
- extractor cache format
- renderer theme behavior if needed

### Runtime repo

Version:

- Docker/runtime defaults
- operational commands
- compatibility expectations

Recommended compatibility story:

- runtime version X works with digest package version Y

Without this, updates will become harder to reason about over time.

## Opinionated vs configurable

The project should stay opinionated in the right places.

Good places to stay opinionated:

- artifact structure
- state layout
- helper outputs
- error handling
- version pinning strategy

Good places to stay configurable:

- source matching
- digest section composition
- rendering theme
- delivery destination
- scheduling

## Operational ergonomics for the runtime repo

The OpenClaw runtime repo should feel easy to run confidently.

Important areas to improve:

- command naming consistency
- deploy vs rebuild clarity
- tunnel/gateway access
- session/activity log commands
- cron test ergonomics
- state inspection commands
- cleanup/prune commands
- health checks and smoke tests

## Support boundary

Define what is supported versus experimental.

Example:

- supported:
  - OpenClaw
  - Gmail
  - Docker local
  - GCP VM/cloud runtime
- experimental:
  - other clouds
  - other inbox providers
  - other agent frameworks

This will help avoid accidental maintenance commitments.

## Dependency management

Dependency management is a key part of the eventual open-source story.

Recommended principles:

- pin important runtime versions explicitly
- keep generated dependency/config files derived from a small source of truth
- version compatibility between runtime and digest layers
- keep lockfiles intentional and current
- document what is manually pinned vs auto-bumped

## Readiness checklist

Before splitting into public repos:

1. inventory all sensitive material
2. define the core contracts and boundaries
3. move repo-specific assumptions into config
4. separate deterministic code from framework-specific prompt logic
5. replace real examples with sanitized fixtures
6. add regression tests for the ugliest known cases
7. document support boundaries and compatibility expectations
8. decide license, contribution, and maintenance model

## Recommended next step

Do not start with repo extraction yet.

Start with one design phase inside this repo:

- define what belongs in the digest package
- define what belongs in the runtime repo
- define the core contracts
- define adapter boundaries
- define the security scrub checklist
- define the release/versioning model

Once those boundaries are clear, splitting into separate repos will be much cleaner.
