# gmail-gog-webhook

Use this skill for Gmail integration through OpenClaw's `gog` webhook flow.

## Purpose

- Set up Gmail Pub/Sub ingestion using `openclaw webhooks gmail setup`
- Run and verify Gmail watch delivery into OpenClaw hooks
- Keep setup local-first before promoting to Docker/cloud
- Keep webhook ingestion available as optional realtime context while workflow reliability can still come from historical pull logic

## Allowed actions

- Configure Gmail webhook integration for the configured workflow mailbox
- Read logs and status for Gmail watch/webhook health

## Not allowed

- Store OAuth/client secrets or bot tokens in repo-managed files
- Enable broad hook routes without review
- Disable safety wrappers for external content without explicit approval

## Requirements

- `openclaw` CLI installed and authenticated
- `gcloud` installed/authenticated
- `gog` installed and authorized for the workflow mailbox
- `tailscale` available if using supported Funnel setup

## Local-first setup

Use the configured workflow Gmail account, or provide one explicitly:

```bash
bash scripts/gmail/setup-gog-local.sh "${GOG_ACCOUNT:-gmail-workflow@example.com}"
```

Use the OpenClaw wizard defaults first. It writes `hooks.gmail` config and the Gmail preset mapping.

## Runtime

Pick one mode:

1. Gateway-managed watcher (recommended)
- Start/restart gateway normally; do not run manual watcher in parallel.

2. Manual watcher
- Set `OPENCLAW_SKIP_GMAIL_WATCHER=1` for gateway runtime.
- Run:
```bash
bash scripts/gmail/run-gog-local.sh
```

## Output requirements

- Summaries should be concise and action-oriented
- Include sender, subject, and priority cue
- Avoid leaking full message bodies unless explicitly needed
