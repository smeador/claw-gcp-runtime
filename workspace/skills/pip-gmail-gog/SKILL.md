# pip-gmail-gog

Use this skill for Pip's Gmail integration through OpenClaw's `gog` webhook flow.

## Purpose

- Set up Gmail Pub/Sub ingestion using `openclaw webhooks gmail setup`
- Run and verify Gmail watch delivery into OpenClaw hooks
- Keep setup local-first before promoting to Docker/cloud
- Keep webhook ingestion available as optional context/future realtime mode while daily digest reliability comes from historical pull logic in `pip-newsletter-digest`

## Allowed actions

- Configure Gmail webhook integration for Pip's mailbox
- Read logs and status for Gmail watch/webhook health

## Not allowed

- Store OAuth/client secrets or bot tokens in repo-managed files
- Enable broad hook routes without review
- Disable safety wrappers for external content without explicit approval

## Requirements

- `openclaw` CLI installed and authenticated
- `gcloud` installed/authenticated
- `gog` installed and authorized for Pip's mailbox
- `tailscale` available if using supported Funnel setup

## Local-first setup

```bash
bash scripts/gmail/setup-gog-local.sh automation@example.com
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
