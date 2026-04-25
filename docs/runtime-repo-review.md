# Runtime Repo Review

This note captures the current runtime-repo ergonomics review and the recommended next steps before broader open-source hardening.

## Current state

The repo already has reasonably good verb parity between local and cloud:

- `deploy`
- `restart`
- `rebuild`
- `ps`
- `logs`
- `agent:logs`
- `shell`
- `cron:*`
- `test:*`

The main problems are:

- the command surface is duplicated as `local:*` and `cloud:*`
- cloud commands hide substantial quoting complexity inside `package.json`
- there is no simple runtime-level smoke test for the operator command surface
- the repo still mixes "general runtime" responsibilities with "active integration shell" responsibilities without naming that clearly

Recent finding:

- `local:deploy` previously raced the gateway and could fail while applying cron jobs immediately after container start
- the runtime now waits for gateway readiness before local/cloud cron reconciliation

## Integration/composition stance

For now, this repo should be treated as:

- the general OpenClaw runtime repo
- and the active integration shell for sibling workflow repos during development

That means:

- generic runtime mechanics stay here
- workflow implementation does not move back here
- sibling integrations like `agent-newsletter-digest` are first-class development inputs

## Command ergonomics options

### Option A: keep the current `local:*` and `cloud:*` model

Pros:

- no migration risk
- explicit and easy to grep

Cons:

- duplicated operator surface
- high mental overhead
- awkward to document as one system

### Option B: add a unified runtime facade over the existing scripts

Example:

- `agent-runtime local deploy`
- `agent-runtime cloud deploy`
- `agent-runtime local cron list`

Pros:

- minimal migration risk
- preserves existing implementation scripts
- gives us one environment-parameterized operator surface

Cons:

- still uses npm as the outer entry point
- not as elegant as a dedicated task runner

### Option C: adopt a dedicated task runner as the primary UX

Examples:

- `just local deploy`
- `task cloud:deploy`

Pros:

- cleaner operator UX
- easier grouping and aliases
- better help/listing semantics

Cons:

- new tool dependency
- still requires underlying scripts or a rewrite
- more moving parts right now

## Recommendation

Recommended near-term path:

1. adopt Option B now
2. keep shell scripts as the implementation layer
3. revisit a task runner later if the facade still feels too clumsy

This gives us a better UX without a disruptive rewrite.

Current operator-facing shape:

- `agent-runtime local deploy`
- `agent-runtime cloud deploy`
- `agent-runtime local cron list`
- `agent-runtime local test basic`
- `agent-runtime local test core`
- `agent-runtime local test integration`
- `agent-runtime local test skill pip-newsletter-digest`
- `agent-runtime cloud test digest`
- `agent-runtime cloud test skill pip-newsletter-digest`
- `./bin/agent-runtime local deploy`
- `./bin/agent-runtime cloud deploy`
- `./bin/agent-runtime local cron list`
- `./bin/agent-runtime local test basic`
- `./bin/agent-runtime local test core`
- `./bin/agent-runtime local test integration`
- `./bin/agent-runtime local test skill pip-newsletter-digest`
- `./bin/agent-runtime cloud test digest`
- `./bin/agent-runtime cloud test skill pip-newsletter-digest`

Preferred in-repo setup:

- enable `direnv`
- use `.envrc` and `.envrc.local`
- let `PATH_add bin` expose `agent-runtime`

Fallbacks:

- `./bin/agent-runtime ...`
- `agent-runtime ...`

## Runtime test framework

The runtime repo should have a tiered local Docker runtime test surface.

### `basic`

- deploy works
- the gateway is present in `ps`
- logs are readable
- cron listing works

### `core`

- `basic`
- gateway health reports `ok`
- model status resolves
- workspace mount expectations are correct
- required runtime binaries are present

### `integration`

- `core`
- runtime facade works
- staged integration commands are callable
- skill-owned test entrypoints are present inside the composed workspace

These tiers stay intentionally smaller than full workflow or Gmail tests. They validate the runtime command surface and runtime setup itself.

Implemented first pass:

- [scripts/runtime-test-local.mjs](/Users/sean/Repos/gcp-claw-lab/scripts/runtime-test-local.mjs)
- [scripts/runtime-test-local.mjs](/Users/sean/Repos/gcp-claw-lab/scripts/runtime-test-local.mjs) as the implementation behind `agent-runtime local test basic|core|integration`
- the harness supports `RUNTIME_TEST_SKIP_DEPLOY=1` for quicker reruns when the gateway is already up
- legacy `RUNTIME_SMOKE_SKIP_DEPLOY=1` still works

## Framework alternatives worth considering

These are the main alternatives worth keeping in view.

### Command runner

- `just`
- `Task`

These improve the operator UX more than the implementation model.

### Deployment/configuration automation

- `Ansible`

This is the most plausible replacement if remote host bootstrapping and deploy steps become too complex for shell scripts.

### Configuration language/validation

- `CUE`

This is the strongest candidate if runtime config rendering and integration schemas keep growing in complexity.

### Reproducible developer environments

- `Devbox`
- `Nix`

These are best viewed as developer-environment layers, not direct replacements for the runtime scripts themselves.

## Suggested adoption order

1. unified runtime facade
2. local smoke tests
3. optional task runner later
4. optional CUE or Ansible only if complexity actually justifies it
