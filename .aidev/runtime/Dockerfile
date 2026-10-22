# The image AIDEV runs this project's checks in (`environment.image` in
# .aidev/project.yaml). Checks run with the caller's uid and, for the slots that
# start the HAF test stack (.aidev/test-stack.compose.yml), on that stack's network.
#
#   CI's own regression-test image, hive/nft_tracker/haf-test:<HAF_VERSION>-v2
#   (HAF at .gitlab-ci.yml's HAF_VERSION + postgresql-server-dev + make, built from
#   docker/Dockerfile.test), so psql, pg_regress and PGXS are exactly what CI's
#   regression_tests job runs ./regress.sh with
#   + socat, to forward localhost:5432 to the stack's HAF (tests/regression's
#     Makefile and pg_regress options name localhost)
#   + python3-psycopg2 and /usr/local/bin/install_with_app_lock.py from the psql
#     image the project Dockerfile's PSQL_CLIENT_VERSION names, so `install` takes
#     install_app.sh's advisory-lock path
#   + shellcheck 0.11.0 (static binary)
#   + the postgrest binary of common-ci-configuration/postgrest (v12.0.2) and
#     tavern + pytest in /opt/venv, for tests/api_tests
#
# Pinned: a step's verdict must not move with a new release. The Dockerfile is the
# only input (nothing is copied from the tree). Build and pin it with
# .aidev/runtime/build.sh; see .aidev/README.md.
FROM registry.gitlab.syncad.com/hive/common-ci-configuration/postgrest@sha256:928a9478f8a4b38dab3448846bf40da3f2075ae770c3f94fb9760ff689aa6561 AS postgrest
FROM registry.gitlab.syncad.com/hive/common-ci-configuration/psql:da9ffb6003edfb5cbaf1dfcde8e1847667af7d24@sha256:bf3f0974b0bccfff22060bccfd7cbe469f56e757d8b07535f8ee8b4288e0be67 AS psql
FROM koalaman/shellcheck:v0.11.0@sha256:61862eba1fcf09a484ebcc6feea46f1782532571a34ed51fedf90dd25f925a8d AS shellcheck

FROM registry.gitlab.syncad.com/hive/nft_tracker/haf-test:dfbc6e13-v2@sha256:a540b19306194b1b16e29c42cefe49a1f4b3d2d6afb8e8d72aab04684c14e191

USER root
RUN apt-get update -qq \
    && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends socat python3-psycopg2 curl \
    && rm -rf /var/lib/apt/lists/* \
    && python3 -m venv /opt/venv \
    && /opt/venv/bin/pip install --no-cache-dir tavern==3.7.0 pytest==9.1.1 \
    && ln -s "$(pg_config --bindir)" /usr/local/pgbin

COPY --from=postgrest /bin/postgrest /usr/local/bin/postgrest
COPY --from=shellcheck /bin/shellcheck /usr/local/bin/shellcheck
COPY --from=psql /usr/local/bin/install_with_app_lock.py /usr/local/bin/install_with_app_lock.py

# The image's /usr/bin/psql is HAF's wrapper, which wants a local data directory;
# the PostgreSQL binaries (/usr/local/pgbin -> pg_config --bindir, whatever major
# version the base HAF runs) come first.
ENV HOME=/tmp PYTHONDONTWRITEBYTECODE=1 \
    PATH=/usr/local/pgbin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENTRYPOINT []
CMD ["bash"]
