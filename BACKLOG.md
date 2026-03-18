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

- Investigate native vs container OpenClaw startup performance
  - Findings so far:
    - Native local `openclaw --help` was about `2.4s`.
    - Container `openclaw --help` with empty home/workspace/config was about
      `10.3s`.
    - Container control-plane commands with the full bundled plugin tree were
      about `15s` to `17s`.
    - Container control-plane commands dropped to about `1s` when bundled
      plugin discovery was removed.
    - Bundled skills were not the main hotspot; bundled plugins/extensions were.
    - Disabled bundled plugins still appear to incur discovery/manifest cost
      before enable/disable filtering.
  - Current mitigation:
    - Use a curated bundled plugin allowlist in the Docker image instead of the
      full upstream bundled extension tree.
  - Follow-up questions:
    - Separate the baseline container startup penalty from bundled plugin
      discovery overhead more precisely.
    - Determine why containerized OpenClaw CLI startup is substantially slower
      than native local even before bundled plugin discovery is added back.
    - Check whether cache/package-manager differences (`pnpm` host vs `npm`
      image), filesystem/module-loading behavior, or container runtime
      characteristics explain the remaining baseline gap.
    - Check whether OpenClaw has a supported configuration or upstream fix for
      reducing bundled plugin discovery cost in container/server environments.
