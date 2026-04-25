# Agent Notes

This file captures project-level working memory for agents operating on the repository itself. It complements [workspace/AGENTS.md](/path/to/gcp-claw-lab/workspace/AGENTS.md), which is the runtime-facing workspace policy file used by the bot inside the reviewed workspace.

## Project Context

- This repo manages a private OpenClaw lab on GCP plus a reviewed workspace for local and cloud agent workflows.
- The main active product workflow is the Pip newsletter digest.
- Newsletter implementation logic now lives in the sibling repo [`/path/to/agent-newsletter-digest`](/path/to/agent-newsletter-digest); this repo should stay runtime-first and integration-generic.
- Treat this file as system-builder guidance, not end-user bot persona guidance.

## Builder Preferences

- Keep explanations concise and operational.
- Prefer making the change over only describing the change.
- When there is a real tradeoff, surface it clearly and briefly.
- Keep local and cloud behavior aligned where it makes sense.
- Prefer deterministic scripts over increasingly complex prompt instructions.
- Keep `workspace/` minimal: it is the composed runtime + integration surface, not the long-term home of workflow mechanics.

## Repo Conventions

- Keep `README.md` at the repo root for GitHub rendering.
- Keep long-form docs in [docs](/path/to/gcp-claw-lab/docs):
  - [docs/spec.md](/path/to/gcp-claw-lab/docs/spec.md)
  - [docs/backlog.md](/path/to/gcp-claw-lab/docs/backlog.md)
  - [docs/openclaw-agent-guide.md](/path/to/gcp-claw-lab/docs/openclaw-agent-guide.md)
- Use lowercase names for docs under `docs/` for consistency.
- Treat repo-managed files as the source of truth; do not rely on VM-side ad hoc edits.

## Key Operational Lessons

- Raw Gmail JSON and raw HTML should not be passed directly into the model when cleaner artifacts can be generated first.
- Artifact-backed workflows are more reliable and cheaper than prompt-only workflows.
- The digest flow is healthier when retrieval, extraction, and send are code-owned, and the model is used for bounded synthesis.
- Cloud runtime artifacts should land under `/opt/openclaw/state/...`, not under the synced app tree.
- Local runtime artifacts should land under `workspace/memory/...`.
- When command strings become deeply nested or depend on long freeform `--message` values, move them into helper scripts.
- For remote interactive agent runs, preserve a TTY if streamed progress in the terminal matters.

## Digest-Specific Working Memory

- The digest skill should be triggered by a simple direct command:
  - `Run pip-newsletter-digest now.`
  - `Run pip-newsletter-digest now in test mode.`
- Avoid overcomplicating the trigger prompt; extra wording has repeatedly caused worse behavior.
- The local Docker digest test path should go through [scripts/run-local-digest-test.sh](/path/to/gcp-claw-lab/scripts/run-local-digest-test.sh).
- Prefer the generic form when updating runtime tooling:
  - `agent-runtime local test skill pip-newsletter-digest`
  - `agent-runtime cloud test skill pip-newsletter-digest`
- The cloud gateway tunnel should go through [scripts/tunnel-cloud-gateway.sh](/path/to/gcp-claw-lab/scripts/tunnel-cloud-gateway.sh).
- The digest formatter should write direct briefing prose, not source-framed prose like `the article says`.
- For Substack-backed items, app-friendly links are preferred when clean `open.substack.com/.../p/...` URLs are available.
- For email typography, prefer email-safe choices over decorative or client-fragile ones. The digest title should use `Georgia`.

## Keep Separate From Runtime Persona

- Do not copy Pip bot voice, persona, or greeting behavior into repo-level guidance.
- Do not store end-user personalization here unless it materially affects system design or operator workflow.
- Put runtime-facing bot behavior in the reviewed workspace files, not in this repo-level file.

## Current Known Fragilities

- The cloud cron job can appear healthy even when the actual digest workflow stops early, so inspect session files and artifacts, not just cron status.
- Remote/cloud commands that use `gcloud compute ssh ... --command ...` are easy to break with nested quoting.
- The installed `gog` CLI command surface should be treated as authoritative. Verify real command names and flags before encoding them in skills.

## Preferred Debugging Order

1. Check run artifacts.
2. Check session files.
3. Check helper script behavior.
4. Check gateway logs.
5. Check cloud/container/environment differences.

## When Adding New Automation

- Prefer a small wrapper script before adding a long npm one-liner.
- Prefer machine-readable artifact handoffs between steps.
- Prefer bounded synthesis over giving the model large, messy source payloads.
- Favor changes that improve local/cloud parity and make failure modes easier to inspect.
- Prefer generic integration staging over reintroducing workflow-specific compatibility wrappers in the runtime repo.
