# OpenClaw Adapter Runtime Expectations

Historical note:

- this document is still directionally useful, but it was written for the split-era newsletter adapter contract
- the live integration-owned expectations should now live with the integration repo
- keep this file as a runtime-side reference, not as the primary workflow contract

This contract defines what the OpenClaw-facing newsletter adapter may assume about the runtime environment.

The skill is the agent-facing entry point.

This document covers the environment-facing promises that make the skill usable.

## Purpose

The newsletter repo should not need to own runtime provisioning details.

Instead:

- the runtime repo provisions capabilities
- the newsletter adapter consumes those capabilities

## Expected capabilities

### OpenClaw runtime

The environment provides:

- a working OpenClaw runtime
- a writable OpenClaw home/state path
- a reviewed workspace mounted at `/workspace` in Docker-local/cloud environments

### `gog`

The environment provides:

- `gog` on `PATH`
- Gmail auth already provisioned for the configured workflow account
- the configured workflow account exposed through `GOG_ACCOUNT`

The newsletter adapter may assume:

- it can call `gog gmail search`
- it can call `gog gmail send`

The newsletter adapter should not assume:

- responsibility for installing `gog`
- responsibility for bootstrapping the auth store from scratch

### Workspace paths

In Docker-local/cloud, the adapter may assume:

- `/workspace` exists
- `/workspace/memory` is writable
- `/workspace/memory/.tmp` is writable
- `/workspace/.openclaw` is writable

The adapter should not assume:

- `/workspace` itself is writable
- `/workspace/.tmp` is writable

### Helper availability

The adapter may assume that helper entry points are available through:

- installed integration commands on `PATH`
- skill-local entrypoints shipped with the integration package

In cloud and Docker-local, those helpers come from a staged integration snapshot that the runtime installs into the image during deploy/build time.

The adapter should not assume:

- repo-root runtime wrapper scripts for workflow logic
- `compat/newsletter` fallback copies
- that `workspace/` is the implementation home for newsletter mechanics

The intended shape is:

- the runtime provisions generic capabilities
- the integration package exposes its own commands and skill test entrypoints
- the reviewed workspace composes those skills into the active runtime

## Runtime-specific path expectations

### Docker-local / cloud

Normal writable working paths:

- `/workspace/memory/`
- `/workspace/memory/.tmp/`
- `/workspace/.openclaw/`

### Native local

Native local may differ in exact filesystem layout, but should still satisfy:

- a writable artifact root
- a writable scratch root
- working `gog`
- working OpenClaw environment

## Account expectations

For the current Pip workflow, the adapter should assume:

- the Gmail workflow account comes from runtime configuration, not from a literal hardcoded address
- an explicit recipient may be passed in by the caller
- if no recipient is passed, workflow-specific logic may reuse the newest prior digest recipient from artifacts

These are workflow configuration details, not universal adapter requirements.

## Skill/runtime boundary

The skill owns:

- workflow invocation semantics
- retrieval/synthesis instructions
- how to use the available helpers
- any skill-local `TEST.sh` entrypoint used by generic runtime testing

The runtime owns:

- installing capabilities
- mounting writable paths
- providing auth and secrets
- staging integration packages into the composed workspace
- packaging sibling integrations from the local checkout into the deploy/build snapshot
- exposing generic runtime commands such as `agent-runtime test skill <skill>`

## Failure model

If a runtime expectation is not satisfied, the adapter should fail clearly.

Examples:

- `gog` missing
- configured Gmail auth missing
- writable scratch path missing
- helper wrapper not found
- stale persisted OpenClaw state conflicting with rendered runtime config

These should be treated as environment/runtime failures, not as reasons for the skill to invent a new execution path.
