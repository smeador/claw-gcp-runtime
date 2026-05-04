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

- some cloud operator paths still hide too much quoting or transport detail
- cloud-side runtime validation is lighter than the local tiered test surface
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

## Command ergonomics result

We chose the unified runtime CLI path.

Current operator-facing shape:

- `agent-runtime local deploy`
- `agent-runtime cloud deploy`
- `agent-runtime local cron list`
- `agent-runtime local test basic`
- `agent-runtime local test core`
- `agent-runtime local test integration`
- `agent-runtime local test skill pip-newsletter-digest`
- `agent-runtime cloud test skill pip-newsletter-digest`

Supporting implementation changes that are now landed:

- shared lifecycle flow in [scripts/runtime/lifecycle.sh](/path/to/gcp-claw-lab/scripts/runtime/lifecycle.sh)
- shared cron flow in [scripts/runtime/cron.sh](/path/to/gcp-claw-lab/scripts/runtime/cron.sh)
- shared shell/runtime helpers in [scripts/lib/runtime-common.sh](/path/to/gcp-claw-lab/scripts/lib/runtime-common.sh)
- manifest-driven integration staging in [scripts/stage-workspace-integrations.mjs](/path/to/gcp-claw-lab/scripts/stage-workspace-integrations.mjs)
- direct runtime CLI dispatch in [scripts/runtime/cli.mjs](/path/to/gcp-claw-lab/scripts/runtime/cli.mjs)

Preferred in-repo setup:

- enable `direnv`
- use `.envrc` and `.envrc.local`
- let `PATH_add bin` expose `agent-runtime`

Fallbacks:

- `./bin/agent-runtime ...`
- `agent-runtime ...`

We have not needed a separate task runner yet. Shell scripts plus the dedicated runtime CLI have been enough so far.

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

- [scripts/runtime-test-local.mjs](/path/to/gcp-claw-lab/scripts/runtime-test-local.mjs) as the implementation behind `agent-runtime local test basic|core|integration`
- the harness supports `RUNTIME_TEST_SKIP_DEPLOY=1` for quicker reruns when the gateway is already up
- legacy `RUNTIME_SMOKE_SKIP_DEPLOY=1` still works

Cloud still relies more on targeted commands such as:

- `agent-runtime cloud test gmail-read`
- `agent-runtime cloud test gmail-send`
- `agent-runtime cloud test skill <skill>`

Adding cloud-side `basic` and `core` tiers is still a reasonable follow-up, but not required for the current working setup.

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
