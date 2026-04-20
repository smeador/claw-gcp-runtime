# Newsletter Compatibility Copy

This directory holds the temporary compatibility copy of the extracted newsletter implementation.

Current split shape:

- the extracted source of truth now lives in the sibling `agent-email-digest` repo
- this runtime repo keeps these copies so local Docker and cloud deploys do not break during the transition
- the runtime-facing entry points under `scripts/email/` and `scripts/gmail/` now act as compatibility shims

Resolution order for those entry points:

1. explicit `AGENT_EMAIL_DIGEST_ROOT`
2. default sibling checkout at `../agent-email-digest` when that checkout has its own `node_modules/`
3. this compatibility copy

This directory should shrink over time as the runtime repo switches to consuming the newsletter repo directly.
