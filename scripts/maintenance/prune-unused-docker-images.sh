#!/bin/bash
set -euo pipefail

echo "Pruning unused Docker images..."
docker image prune -af || true
