# Newsletter Split Findings

## Current structure

- the newsletter implementation now lives in the sibling repo:
  - [`/path/to/agent-newsletter-digest`](/path/to/agent-newsletter-digest)
- this runtime repo stages declared integrations from [workspace/integrations.json](/path/to/gcp-claw-lab/workspace/integrations.json)
- staged integrations are copied into:
  - [`.runtime/integrations`](/path/to/gcp-claw-lab/.runtime/integrations)
- the reviewed workspace exposes the composed skill surface by copying staged skills into:
  - [workspace/skills](/path/to/gcp-claw-lab/workspace/skills)

This is intentionally different from the older transition model. The runtime repo no longer carries `compat/newsletter` or repo-root newsletter wrapper scripts.

## Boundary that worked best

The cleanest split is:

- runtime repo:
  - generic local/cloud/GCP/OpenClaw runtime
  - capability provisioning
  - integration staging
  - generic runtime validation
- newsletter repo:
  - newsletter extraction/render/send logic
  - OpenClaw adapter commands
  - skill-owned test entrypoints
- workspace:
  - the concrete composed view of runtime + integrations
  - minimal context-specific glue only

The main correction from the earlier plan is that `workspace/` should not quietly become a second home for newsletter implementation logic.

## Integration findings

### Generic staging beats compatibility shims

The earlier compatibility-wrapper model kept the runtime working, but it blurred ownership and made it too easy for newsletter logic to drift back into the runtime repo.

The better model is:

- runtime repo stages integrations generically
- integration packages provide their own commands and skill assets
- the reviewed workspace exposes copied skill assets without becoming the source of truth for them

### Skills need their own test entrypoint

`agent-runtime` can stay general if it only dispatches to skill-provided tests.

The current shape is:

- runtime command:
  - `agent-runtime local test skill <skill>`
- integration-owned test runner:
  - declared through `integration.json`
- reviewed workspace still exposes:
  - `workspace/skills/<skill>/TEST.sh`

That keeps runtime logic generic while allowing workflow-specific test behavior.

### `gog` still belongs on the runtime side

The newsletter repo can depend on `gog` as an adapter capability, but this runtime repo should keep owning:

- `gog` installation
- auth provisioning
- availability on `PATH`

That boundary still feels correct after the refactor.

## Remaining follow-up

1. keep reducing Pip-specific framing in runtime docs and commands where it is not required for compatibility
2. add more generic skill-test conventions only if a second integration needs them
3. validate the same integration staging model for native local once that work is prioritized
