# Backlog

Source of truth for open backlog items in this repository.

## Prioritized

1. Fix cloud OpenRouter attribution so cloud runs identify as `OpenClaw` instead of `Unknown App` using a supported OpenClaw-side configuration path.
2. Tighten the connection-channel story now that Telegram support is restored in `2026.5.4`:
   - keep Telegram on the config-first path (`channels.telegram` in the template + `channels.telegram.botToken` in secret overlays)
   - verify whether local Docker should default to disabled while cloud remains the primary Telegram runtime
   - document the exact operator flow for future channel additions so local Docker, native local, and cloud stay aligned
3. **Implemented in `newsletter-digest`:** `newsletter-digest-run` owns production orchestration; the skill invokes it and reports the result.
4. Reduce digest token usage further with section-aware trimming and smaller formatter inputs, especially for longer newsletters such as NYT and AI News.
5. Add a lighter-weight config-only cloud rollout and post-deploy verification path so simple config/cron changes do not require the same heavy operator flow as image rebuilds.
6. Revisit a dedicated digest agent using the documented `openclaw agents add ...` bootstrap path if we want stronger isolation without relying on config-only agent registration.
7. Add RSS feed ingestion as an optional supplemental source, normalized into the same artifact pipeline as Gmail-backed newsletter inputs.
8. **Implemented:** the code-owned runner covers extraction, formatting, artifact staging, and send (same work as item 3).
9. **Implemented in `newsletter-digest`:** cached extraction requires the current `extractorVersion` and the complete artifact set.
10. Harden the digest send path so HTML delivery is not dependent on passing the full HTML body as a large shell argument if a file-backed or wrapper-backed alternative is available.
11. **Implemented in `newsletter-digest`:** fixture and contract coverage exists for extraction, rendering, finalization, and delivery. Continue extending cases as behavior changes.
12. Evaluate bounded parallel synthesis after the runner script exists:
    - keep message selection, extraction, and delivery centralized
    - hand one cleaned artifact bundle per source to a bounded worker/subagent
    - have each worker return only a structured section result
    - assemble the final digest from those bounded section outputs
13. Validate native-local OpenClaw against the current repo-managed workflow/runtime assumptions:
    - confirm the newsletter digest still runs cleanly outside Docker
    - **Verified:** OpenClaw 2026.9.2 and Node 22.23.2 parity, bounded inference, adapter transports, and Gmail reads; full native digest delivery remains a separate check
    - identify any native-only auth, path, or state differences that still need explicit handling
14. Decide whether additional connection channels beyond Telegram should remain config-bootstrapped, be split by environment, or move behind a more explicit bootstrap flow.
15. Revisit cloud OpenClaw CLI performance:
   - see [current measurement guidance](runtime-performance.md) before treating old numbers as current
   - historical pre-2026.9.2 evidence showed a `5x` to `7x` cloud penalty in heavier CLI bootstrap paths
   - packaged compile cache is active, but it only helps modestly
   - reducing bundled enabled plugins from `67` to `8` did not materially improve timings
   - local `2 CPU / 4 GB` limits did not reproduce the cloud slowdown
   - next useful comparison is a faster VM class or a more focused filesystem/syscall trace

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
