# Runtime command performance

Measure these costs separately when investigating slow OpenClaw commands:

1. CLI startup, module loading, and config/state initialization.
2. Gateway requests over an existing local connection.
3. Model/provider latency and any agent tool turns.
4. Operator transport, especially a fresh `gcloud compute ssh` / IAP connection.

## Repeatable checks

Select the repository's Node version with `nvm use`. Check `openclaw --version` and `node --version` in each environment. Native state and Docker state are separate; `claw-runtime local` targets Docker.

Inside a native shell or an already-open `claw-runtime local shell` / `cloud shell`, time each command once to warm it, then at least three more times:

```bash
time openclaw --version
time openclaw health --json
time openclaw status --json
time openclaw sessions --json
```

Measure an HTTP liveness probe separately. Inside either gateway container the port is 18789; the local Docker host mapping is 18790:

```bash
curl --silent --output /dev/null --write-out '%{http_code} %{time_total}\n' \
  http://127.0.0.1:18789/healthz
```

The HTTP liveness endpoint is narrower than OpenClaw's health/status diagnostics; a fast 200 response does not validate providers, skills, or a completed workflow. Do not expose the gateway publicly to benchmark it.

For end-to-end operator timing, measure the outer `claw-runtime cloud ...` command separately. Repeated commands in an existing shell avoid repeatedly paying SSH/IAP setup. Keep first-observed and warm timings separate; a fresh process does not imply cold OS or Node compile caches.

## Model work

For an explicitly authorized model probe, use a tiny prompt, an explicit provider/model, and matching thinking settings. Compare `openclaw infer model run --local` with `--gateway`. Compare full `openclaw agent` calls only in isolated sessions and omit `--deliver` when no channel delivery is intended.

A full agent call includes workspace instructions, skills/tool schemas, and possibly multiple provider turns. A bounded inference call is a better match for a deterministic runner that already owns orchestration. Measure real workflow latency through its model-call and run-summary artifacts; a tiny reply is not a digest throughput benchmark.

## Comparing versions

Run older packages in separate temporary state directories and, when necessary, separate loopback gateways. Never point an older package at migrated production SQLite state. Use the same machine, Node, minimal config, command, and warmup policy; record package-manager/dependency differences and sample ranges. Help-command improvements alone do not establish faster real gateway or agent requests.

The older cloud investigation in [the agent guide](openclaw-agent-guide.md#historical-cloud-cli-performance-findings) is historical evidence. Re-measure the deployed version before claiming that a cloud bottleneck is fixed. Keep deployment-specific measurements and raw diagnostics in the private deployment repository.
