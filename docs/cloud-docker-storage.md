# Cloud Docker storage maintenance

## Cause

The September 2026 investigation found 24 GB in `/var/lib/docker/overlay2`, 41 images, one running container, zero reported BuildKit cache, and only 16 MB in `/tmp`. The VM used Docker 20.10 and Compose 1.29, whose legacy multi-stage builds retain intermediate images. Cleanup of `/tmp` or BuildKit cache alone cannot reclaim those layers.

Commit `b6d1240` fixed deployment staging but intentionally moved image pruning out of lifecycle commands. Repeated image replacements and Go builder stages then accumulated without automatic retention. Sync archives are removed on successful extraction; they were not the observed disk consumer.

## Policy

Cloud deploy/rebuild now runs storage maintenance before building and on exit (including build failures):

- Prune dangling images older than 24 hours and unused BuildKit cache older than 24 hours, retaining a 2 GB cache budget.
- If free space is below 6 GiB, also prune recent dangling images and unused BuildKit cache with a 1 GB retention target.
- Refuse to build if less than 6 GiB remains after cleanup, before stopping the running gateway. Override the threshold with `OPENCLAW_BUILD_MIN_FREE_KB` when invoking the VM lifecycle script directly.
- When the build changes the image, tag the previous container's image as `claw-runtime-openclaw:cloud-rollback` before replacing the container. Repeating a deploy of the same image preserves that rollback tag.
- Preserve the current image, tagged images, all container-referenced images, volumes, bind-mounted state, and backup archives. Cleanup never uses `docker system prune`, `image prune --all`, or volume deletion.

This policy assumes the dedicated cloud Docker daemon supplied by this project. It can remove dangling images/cache from other builds on that daemon; tag anything that must be retained. Local Docker is not automatically pruned. A filesystem lock serializes cloud lifecycle builds and their cleanup; it does not serialize the preceding upload/staging phase, so operators should still avoid concurrent cloud deploy commands.

The older explicit `claw-runtime cloud prune` command remains a broader manual operation: it uses `image prune -a` and can remove tagged rollback images. Use the lifecycle policy for routine maintenance.

Pruning build cache may make a later build recompile gog or re-download packages. Retaining recent cache avoids paying that cost on every normal redeploy. A failed build's Docker-retained containers, deliberately tagged historical images, and large application data are outside this cleanup policy; inspect them explicitly if the free-space guard refuses a build.

An image tag alone is not a complete rollback across OpenClaw state migrations. Restore the corresponding state/config backup when changing runtime versions; see [upgrade notes](openclaw-2026.9.2-upgrade.md).

## Verification

`node --test scripts/runtime/cloud-storage.test.mjs` exercises deploy/rebuild ordering, pressure cleanup, insufficient-space refusal, failed-build cleanup and exit status, rollback preservation, cleanup errors, and lock contention. It is included in `claw-runtime local test integration`. The tests fail against the prior lifecycle implementation.

For live verification, compare `df -h /`, `docker system df`, gateway health, and the rollback image before/after a deploy and a repeated deploy. Disk usage should remain bounded instead of growing by another complete image on each run.

Docker references: [image pruning](https://docs.docker.com/reference/cli/docker/image/prune/), [builder pruning](https://docs.docker.com/reference/cli/docker/builder/prune/), [legacy multi-stage behavior](https://docs.docker.com/build/building/multi-stage/).

Live validation on September 6, 2026: the first deployment reduced the 30 GB root disk from 95% used (1.5 GB free) to 25% used (22 GB free). A second deployment completed at the same 25% usage with zero additional reclaim needed. Gateway health and the existing newsletter cron remained healthy. The local integration suite and all eight storage regression cases passed; seven cases failed against the old lifecycle.
