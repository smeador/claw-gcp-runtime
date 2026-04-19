# Backlog

Source of truth for open backlog items in this repository.

## Prioritized

1. Fix cloud OpenRouter attribution so cloud runs identify as `OpenClaw` instead of `Unknown App` using a supported OpenClaw-side configuration path.
2. Restore Telegram support cleanly after isolating the current Docker/cloud runtime regression:
   - latest tested Docker/cloud images reject `channels.telegram` at startup with `unknown channel id: telegram`
   - adding `plugins.entries.telegram.enabled` did not recover the channel
   - older `2026.3.24` images also reported `plugins.entries.telegram: plugin not found: telegram`
   - preferred restore path is still config-first bootstrap, not imperative cloud-side `openclaw channels add ...`
   - before re-enabling, validate Telegram plugin/channel discovery in the exact container image used for cloud deploys
3. Move more digest orchestration into code with a higher-level runner script so artifact directory creation, staging files, and final send execution are less dependent on skill instructions.
4. Reduce digest token usage further with section-aware trimming and smaller formatter inputs, especially for longer newsletters such as NYT and AI News.
5. Add a lighter-weight config-only cloud rollout and post-deploy verification path so simple config/cron changes do not require the same heavy operator flow as image rebuilds.
6. Revisit a dedicated digest agent using the documented `openclaw agents add ...` bootstrap path if we want stronger isolation without relying on config-only agent registration.
7. Add RSS feed ingestion as an optional supplemental source, normalized into the same artifact pipeline as Gmail-backed newsletter inputs.
8. Add a code-owned digest runner script that orchestrates extraction, formatter handoff, artifact staging, and final send so less of the workflow depends on skill-level file choreography.
9. Add extractor cache versioning so cleanup/parser changes can invalidate stale cached artifacts deterministically instead of reusing older outputs silently.
10. Harden the digest send path so HTML delivery is not dependent on passing the full HTML body as a large shell argument if a file-backed or wrapper-backed alternative is available.
11. Add fixture-based regression tests for newsletter extraction and digest send helpers using sanitized representative inputs.
12. Evaluate bounded parallel synthesis after the runner script exists:
    - keep message selection, extraction, and delivery centralized
    - hand one cleaned artifact bundle per source to a bounded worker/subagent
    - have each worker return only a structured section result
    - assemble the final digest from those bounded section outputs
13. Validate native-local OpenClaw against the current repo-managed workflow/runtime assumptions:
    - confirm the Pip digest still runs cleanly outside Docker
    - verify version parity expectations after the `2026.4.15` bump
    - identify any native-only auth, path, or state differences that still need explicit handling
14. Restore a clean connection-channel story after the current cloud/runtime recovery:
    - re-evaluate Telegram once plugin/channel discovery is reliable again
    - decide whether connection channels should remain config-bootstrapped, be split by environment, or move behind a more explicit bootstrap flow
    - document the supported path for future channel additions so local Docker, native local, and cloud stay aligned

## Additional

- Add monitoring/dashboard coverage for runtime health and cost controls.
- Tighten cloud host package version policy if distro-managed versions become too loose.
- Reduce operator steps further by consolidating more setup flows into deterministic scripts.
- Reduce duplication across local/cloud lifecycle scripts by extracting shared render/setup/apply steps into reusable helpers.
- Keep npm scripts thin and move complex quoted shell logic into named scripts that are easier to audit and debug.
- Add a lightweight post-deploy smoke-check flow for cron status, active model, helper availability, and a manual digest/send sanity check.
- For the digest runner specifically, prefer a stable machine-readable handoff format between extraction, formatting, and send steps so retries and partial reruns do not depend on conversational state.
- Add sanitised sample fixtures for major newsletter types so extractor improvements can be tested without waiting for live mail.
- If RSS is added, normalize feed items into the same cleaned-artifact shape as Gmail-backed inputs so formatter and delivery logic stay shared.
