# Workspace Cron Composition

This directory holds the concrete cron job definitions for the composed workspace.

- Use [`/Users/sean/Repos/gcp-claw-lab/config/cron.example.json`](/Users/sean/Repos/gcp-claw-lab/config/cron.example.json) as the neutral runtime schema example.
- Put real jobs here because they reference concrete installed skills and prompts.
- The runtime does not load these jobs through `openclaw.json`; it reconciles them into OpenClaw runtime state by running `openclaw cron add/edit` after the gateway starts.

Current defaults:

- local: [`/Users/sean/Repos/gcp-claw-lab/workspace/config/cron.local.json`](/Users/sean/Repos/gcp-claw-lab/workspace/config/cron.local.json)
- cloud: [`/Users/sean/Repos/gcp-claw-lab/workspace/config/cron.cloud.json`](/Users/sean/Repos/gcp-claw-lab/workspace/config/cron.cloud.json)
