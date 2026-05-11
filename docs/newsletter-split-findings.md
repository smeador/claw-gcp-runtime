# Newsletter Split Findings

Historical note:

- this document captures findings from the repo split and cloud rollout
- it is still useful for rationale and debugging lessons
- use [README.md](/Users/sean/Repos/claw-gcp-runtime/README.md) and [spec.md](/Users/sean/Repos/claw-gcp-runtime/docs/spec.md) for the current repo shape

## Current structure

- the newsletter implementation now lives in the sibling repo:
  - [`/path/to/newsletter-digest`](/path/to/newsletter-digest)
- this runtime repo stages declared integrations from [workspace/integrations.json](/path/to/claw-gcp-runtime/workspace/integrations.json)
- staged integrations are copied into:
  - [`.runtime/integrations`](/path/to/claw-gcp-runtime/.runtime/integrations)
- the reviewed workspace exposes the composed skill surface by copying staged skills into:
  - [workspace/skills](/path/to/claw-gcp-runtime/workspace/skills)

This is intentionally different from the older transition model. The runtime repo no longer carries `compat/newsletter` or repo-root newsletter wrapper scripts.

The current deployed shape is:

- the runtime reads [workspace/integrations.json](/path/to/claw-gcp-runtime/workspace/integrations.json)
- `scripts/stage-workspace-integrations.mjs` copies the sibling integration into [`.runtime/integrations`](/path/to/claw-gcp-runtime/.runtime/integrations)
- cloud sync uploads that staged snapshot as part of the app tree
- the Docker image installs the staged integration package and exposes its declared bins on `PATH`
- the reviewed workspace exposes copied skill assets under [workspace/skills](/path/to/claw-gcp-runtime/workspace/skills)

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

### Packaged sibling snapshots work well for cloud

The working cloud deploy model is:

- develop against a sibling local checkout
- stage that checkout into [`.runtime/integrations`](/path/to/claw-gcp-runtime/.runtime/integrations) at deploy time
- build the image from the staged snapshot

This gave us the development flexibility we wanted without requiring the VM to fetch the integration repo independently.

The main tradeoff is reproducibility:

- the deployed integration version is whatever was checked out locally when `agent-runtime cloud deploy` ran
- that is acceptable for current development, but later we may want explicit integration commit recording or pinning

### Persisted OpenClaw state can drift from rendered config

One of the most useful findings from the rollout was that rendered runtime config was not the full story.

We hit a local Docker failure where:

- rendered OpenRouter config looked correct
- direct OpenRouter requests worked
- OpenClaw agent turns still failed with empty payloads

The real drift was in persisted OpenClaw state under `~/.openclaw`, where `models.json` still held a stale OpenRouter base URL. Correcting that persisted provider state fixed the issue.

This is an important debugging rule for the runtime repo:

- compare rendered config and persisted runtime state when local/cloud behavior diverges

### Cloud host hygiene matters

The cloud rollout also surfaced a few host-level lessons:

- a full root disk can interrupt deploys and leave runtime state looking partially updated
- stale Docker images need to be pruned periodically on the VM
- macOS metadata files such as `.DS_Store` and `._*` should be excluded from staging and cloud sync
- cloud helper scripts should avoid shell features that break on older macOS Bash versions

## Remaining follow-up

1. keep reducing Pip-specific framing in runtime docs and commands where it is not required for compatibility
2. add more generic skill-test conventions only if a second integration needs them
3. validate the same integration staging model for native local once that work is prioritized
