FROM golang:1.25-bookworm AS gog-builder

ARG GOG_VERSION=v0.11.0

RUN CGO_ENABLED=0 go install github.com/steipete/gogcli/cmd/gog@${GOG_VERSION}

FROM node:22-bookworm-slim

ARG OPENCLAW_NPM_DIST_TAG=latest
ARG OPENCLAW_APT_PACKAGES=""

ENV HOME=/home/node
ENV NODE_ENV=production
ENV SHARP_IGNORE_GLOBAL_LIBVIPS=1

RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates curl jq ripgrep tini \
  && if [ -n "${OPENCLAW_APT_PACKAGES}" ]; then apt-get install -y --no-install-recommends ${OPENCLAW_APT_PACKAGES}; fi \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard --version "${OPENCLAW_NPM_DIST_TAG}"

COPY --from=gog-builder /go/bin/gog /usr/local/bin/gog

COPY docker/entrypoint.sh /usr/local/bin/agent-lab-openclaw-entrypoint
RUN chmod +x /usr/local/bin/agent-lab-openclaw-entrypoint \
  && mkdir -p /workspace /home/node/.openclaw \
  && chown -R node:node /workspace /home/node

USER node
WORKDIR /workspace

ENTRYPOINT ["/usr/bin/tini", "--", "agent-lab-openclaw-entrypoint"]
CMD ["gateway", "--bind", "lan", "--port", "18789"]
