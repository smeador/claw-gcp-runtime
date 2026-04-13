#!/bin/bash
set -euo pipefail

echo "Pruning unused Docker images after successful build/deploy..."
docker image prune -af >/dev/null || true
