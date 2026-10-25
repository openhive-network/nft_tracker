# The image AIDEV runs this project's checks in. It follows common-ci-configuration's
# haf-app-test-runner:develop (`environment.base` in .aidev/project.yaml): AIDEV
# resolves that tag before each run and builds this Dockerfile on it, so the tool
# versions (psql, shellcheck, postgrest, pytest, tavern, psycopg2 in /python_venv)
# are ccc's docker-bake.hcl versions and none is pinned here. Checks run with the
# caller's uid and, for the slots that start the HAF test stack
# (.aidev/test-stack.compose.yml), on that stack's network.
#
#   ccc's haf-app-test-runner (Ubuntu 26.04, PGDG psql at ccc's PSQL_VERSION, the
#   same PostgreSQL major as HAF)
#   + postgresql-server-dev for that psql major and make, so pg_regress and PGXS
#     run CI's ./regress.sh (CI's haf-test image adds the same two packages to HAF)
#   + socat, to forward localhost:5432 to the stack's HAF (tests/regression's
#     Makefile and pg_regress options name localhost)
#   + /usr/local/bin/install_with_app_lock.py from the psql image the project
#     Dockerfile's PSQL_CLIENT_VERSION names, so `install` takes install_app.sh's
#     advisory-lock path as the application image does
#
# BASE_IMAGE's default is the followed tag, for .aidev/runtime/build.sh's seed build.
# See .aidev/README.md.
ARG BASE_IMAGE=registry.gitlab.syncad.com/hive/common-ci-configuration/haf-app-test-runner:develop

FROM registry.gitlab.syncad.com/hive/common-ci-configuration/psql:da9ffb6003edfb5cbaf1dfcde8e1847667af7d24@sha256:bf3f0974b0bccfff22060bccfd7cbe469f56e757d8b07535f8ee8b4288e0be67 AS psql

FROM ${BASE_IMAGE}

USER root
RUN PG_MAJOR="$(psql --version | sed 's/^psql (PostgreSQL) \([0-9]*\).*/\1/')" \
    && apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
       "postgresql-server-dev-${PG_MAJOR}" make socat \
    && rm -rf /var/lib/apt/lists/*

COPY --from=psql /usr/local/bin/install_with_app_lock.py /usr/local/bin/install_with_app_lock.py

ENV HOME=/tmp PYTHONDONTWRITEBYTECODE=1
ENTRYPOINT []
CMD ["bash"]
