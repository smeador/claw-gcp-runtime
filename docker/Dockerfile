ARG GO_IMAGE=golang:1.26-bookworm
ARG NODE_IMAGE=node:22-bookworm-slim
ARG GOG_VERSION=v0.27.0
ARG OPENCLAW_NPM_DIST_TAG=2026.6.6

FROM ${GO_IMAGE} AS gog-builder
ARG GOG_VERSION

RUN CGO_ENABLED=0 go install github.com/steipete/gogcli/cmd/gog@${GOG_VERSION}

FROM ${NODE_IMAGE}

ARG GOG_VERSION=v0.27.0
ARG OPENCLAW_NPM_DIST_TAG=2026.6.6
ARG OPENCLAW_APT_PACKAGES=""

ENV HOME=/home/node
ENV NODE_ENV=production
ENV SHARP_IGNORE_GLOBAL_LIBVIPS=1
ENV OPENCLAW_BUNDLED_PLUGINS_DIR=/usr/local/lib/node_modules/openclaw/dist/extensions
ENV CLAW_RUNTIME_ROOT=/opt/claw-runtime

RUN apt-get update \
  && apt-get install -y --no-install-recommends bash ca-certificates curl jq ripgrep tini \
  && if [ -n "${OPENCLAW_APT_PACKAGES}" ]; then apt-get install -y --no-install-recommends ${OPENCLAW_APT_PACKAGES}; fi \
  && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard --version "${OPENCLAW_NPM_DIST_TAG}"

COPY --from=gog-builder /go/bin/gog /usr/local/bin/gog
COPY package.json package-lock.json ${CLAW_RUNTIME_ROOT}/
COPY scripts/install-staged-integrations.mjs ${CLAW_RUNTIME_ROOT}/scripts/install-staged-integrations.mjs
COPY .runtime/integrations ${CLAW_RUNTIME_ROOT}/integrations

RUN cd "${CLAW_RUNTIME_ROOT}" \
  && npm ci --omit=dev --ignore-scripts \
  && node "${CLAW_RUNTIME_ROOT}/scripts/install-staged-integrations.mjs" "${CLAW_RUNTIME_ROOT}/integrations" /usr/local/bin

COPY docker/entrypoint.sh /usr/local/bin/claw-runtime-openclaw-entrypoint
RUN chmod +x /usr/local/bin/claw-runtime-openclaw-entrypoint \
  && mkdir -p /workspace /home/node/.openclaw \
  && chown -R node:node /workspace /home/node

USER node
WORKDIR /

ENTRYPOINT ["/usr/bin/tini", "--", "claw-runtime-openclaw-entrypoint"]
CMD ["gateway", "--bind", "lan", "--port", "18789"]
