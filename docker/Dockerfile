FROM node:22-bookworm-slim

WORKDIR /app

RUN apt-get update \
  && apt-get install -y --no-install-recommends ca-certificates tini \
  && rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["bash", "-lc", "echo 'OpenClaw image scaffold is in place. Add the runtime install/start command before production use.' && sleep infinity"]
