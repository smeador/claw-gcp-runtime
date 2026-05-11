# Workspace Cron Composition

This directory holds the concrete cron job definitions for the composed workspace.

- Use [`/Users/sean/Repos/claw-gcp-runtime/config/cron.example.json`](/Users/sean/Repos/claw-gcp-runtime/config/cron.example.json) as the neutral runtime schema example.
- Put real jobs here because they reference concrete installed skills and prompts.
- The runtime does not load these jobs through `openclaw.json`; it reconciles them into OpenClaw runtime state by running `openclaw cron add/edit` after the gateway starts.
- Integration-owned runtime config files can also be composed here when declared through an integration manifest, for example `workspace/config/newsletter-digest.json`.

Current defaults:

- local: [`/Users/sean/Repos/claw-gcp-runtime/workspace/config/cron.local.json`](/Users/sean/Repos/claw-gcp-runtime/workspace/config/cron.local.json)
- cloud: [`/Users/sean/Repos/claw-gcp-runtime/workspace/config/cron.cloud.json`](/Users/sean/Repos/claw-gcp-runtime/workspace/config/cron.cloud.json)
