#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
docker compose -f docker/compose.cloud.yml up --build -d
