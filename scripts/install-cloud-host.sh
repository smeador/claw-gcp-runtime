#!/bin/bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  exec sudo -E bash "$0" "$@"
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  jq \
  docker.io \
  docker-compose

systemctl enable --now docker

install -d -o "${SUDO_USER:-root}" -g "${SUDO_USER:-root}" -m 0750 /opt/openclaw/app
