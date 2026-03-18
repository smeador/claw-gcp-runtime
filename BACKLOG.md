# Backlog

This file tracks deferred follow-up work that we want to preserve without
mixing it into the active setup flow.

## Active Now

- Cloud setup and end-to-end cloud runtime validation

## Later

- Enforce Gmail automation to `pip@meador.me` only
  - Add script-level validation so Gmail automation rejects any other source
    account.
  - Add config/render validation for Gmail automation account settings.
  - Keep `sean@meador.me` recipient-only in automation flows.

- Revisit Docker-local Gmail Pub/Sub and webhook delivery
  - Add the Docker-local Tailscale/Funnel path only after basic Docker Gmail
    read/send flows are fully stable.
  - Keep Pub/Sub/webhook support disabled by default in Docker-local until that
    path is ready.
