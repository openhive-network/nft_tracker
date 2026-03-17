# syntax=docker/dockerfile:1.5
ARG PSQL_CLIENT_VERSION=14-2
FROM registry.gitlab.syncad.com/hive/common-ci-configuration/psql:${PSQL_CLIENT_VERSION} AS psql

FROM psql AS version-injection
ARG API_VERSION="0.0.0-dev"
COPY . /tmp/src
WORKDIR /tmp/src
RUN sed -i 's|"version": "[^"]*"|"version": "'"$API_VERSION"'"|' endpoints/endpoint_schema.sql \
    && sed -i 's|^  version: .*|  version: '"$API_VERSION"'|' endpoints/endpoint_schema.sql

FROM psql AS full

ARG BUILD_TIME
ARG GIT_COMMIT_SHA
ARG GIT_CURRENT_BRANCH
ARG GIT_LAST_LOG_MESSAGE
ARG GIT_LAST_COMMITTER
ARG GIT_LAST_COMMIT_DATE
ARG API_VERSION="0.0.0-dev"
LABEL org.opencontainers.image.created="$BUILD_TIME"
LABEL org.opencontainers.image.url="https://hive.io/"
LABEL org.opencontainers.image.documentation="https://gitlab.syncad.com/hive/nft_tracker"
LABEL org.opencontainers.image.source="https://gitlab.syncad.com/hive/nft_tracker"
LABEL org.opencontainers.image.version="$API_VERSION"
LABEL org.opencontainers.image.revision="$GIT_COMMIT_SHA"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.ref.name="NFT Tracker"
LABEL org.opencontainers.image.title="NFT Tracker Image"
LABEL org.opencontainers.image.description="Runs NFT Tracker application"
LABEL io.hive.image.branch="$GIT_CURRENT_BRANCH"
LABEL io.hive.image.commit.log_message="$GIT_LAST_LOG_MESSAGE"
LABEL io.hive.image.commit.author="$GIT_LAST_COMMITTER"
LABEL io.hive.image.commit.date="$GIT_LAST_COMMIT_DATE"

USER root

RUN <<EOF
  set -e
  mkdir /app
  chown hived /app
EOF

USER hived

COPY scripts/install_app.sh /app/scripts/install_app.sh
COPY scripts/uninstall_app.sh /app/scripts/uninstall_app.sh
COPY scripts/process_blocks.sh /app/scripts/process_blocks.sh
COPY db /app/db
COPY --from=version-injection /tmp/src/endpoints /app/endpoints
COPY docker/scripts/block-processing-healthcheck.sh /app/block-processing-healthcheck.sh
COPY docker/scripts/docker-entrypoint.sh /app/docker-entrypoint.sh

ENTRYPOINT ["/app/docker-entrypoint.sh"]
