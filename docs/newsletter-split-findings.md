# Newsletter Split Findings

## Current transition shape

- the extracted newsletter repo is now bootstrapped as a sibling checkout:
  - `/Users/sean/Repos/agent-newsletter-digest`
- this runtime repo still carries a compatibility copy of the deterministic newsletter implementation under:
  - `/Users/sean/Repos/gcp-claw-lab/compat/newsletter`
- runtime-facing entry points in `scripts/email/` and `scripts/gmail/` now resolve to:
  1. `AGENT_EMAIL_DIGEST_ROOT`
  2. sibling `agent-newsletter-digest` checkout
  3. local compatibility copy

## Why the compatibility copy still exists

Today the runtime repo still deploys a single reviewed workspace tree into Docker-local and cloud.

That means a clean repo split needs a transition period where:

- the new repo can become the extracted source of truth
- this repo can continue to deploy without immediately depending on a second checkout or a packaging step

Keeping compatibility copies here lets us make the boundary real now without breaking the live workflow.

## Notable integration findings

### `.mjs` compatibility entry points should stay Node wrappers

The original extract and render entry points lived at `.mjs` paths and some wrappers still expected JavaScript there.

Using shell shims at those paths was possible but confusing. The better transition shape is:

- keep `.mjs` entry points as Node wrappers
- keep `.sh` entry points as shell wrappers
- execute repo fallback scripts via their shebangs in workspace wrappers

### Automatic sibling-repo switchover should only happen when the extracted repo is actually runnable

Once the sibling `agent-newsletter-digest` checkout exists, the runtime repo can find it even before its dependencies are installed.

That created a bad transition mode where the runtime repo would prefer the sibling checkout even though `cheerio` and `turndown` were not present yet.

The runtime-side shims now only auto-switch to the sibling repo when its `node_modules/` directory exists.

The explicit override remains:

- `AGENT_NEWSLETTER_DIGEST_ROOT=/path/to/agent-newsletter-digest`
- legacy fallback:
  - `AGENT_EMAIL_DIGEST_ROOT=/path/to/agent-newsletter-digest`

### `gog` remains a runtime capability

The extracted newsletter repo can own `gog`-based adapter logic, but this repo should keep owning:

- `gog` installation
- auth provisioning
- runtime availability on `PATH`

That boundary still feels right after the first extraction pass.

## Next migration steps

1. add provider and transport interface docs to the extracted repo
2. add sanitized fixtures and regression tests there
3. choose the long-term integration mode for this runtime repo
4. remove compatibility copies once this repo consumes the extracted repo directly
