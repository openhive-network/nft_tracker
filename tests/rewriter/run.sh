#!/usr/bin/env bash
# Tests the rewriter image (Dockerfile.rewriter) in front of PostgREST and HAF with
# nft_tracker installed over tests/api_tests' mock data: starts docker-compose.yml's
# stack and runs the pytest suite of this directory in it.
#
#   tests/rewriter/run.sh [pytest args...]
#
# REWRITER_IMAGE  the rewriter image to test (default: built from Dockerfile.rewriter)
# HAF_IMAGE       default: the haf-test image .aidev/test-stack.compose.yml pins (HAF
#                 develop as the AIDEV stack runs it; CI passes find_haf_image's)
# RESULTS_DIR     where junit.xml (one case per test) and the stack's logs go (default:
#                 a new temporary directory)
# COMPOSE_PROJECT_NAME  the compose project (default: nft-rewriter-test-<pid>). AIDEV's
#                 docker suite scope hands its aidev-dsuite-<token> prefix here, and its
#                 teardown and the host's sweep remove every project under that prefix.
# AIDEV_ENV_CONTAINER_OWNER, AIDEV_ENV_CONTAINER_MEMORY_BYTES  set by AIDEV: every
#                 container of the stack carries the owner label AIDEV's memory budget
#                 counts and reaps by, and is capped at the run's admitted memory
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
results="${RESULTS_DIR:-$(mktemp -d)}"
mkdir -p "$results"
rm -f "$results/junit.xml"

project="${COMPOSE_PROJECT_NAME:-nft-rewriter-test-$$}"
HAF_IMAGE="${HAF_IMAGE:-$(grep -o 'registry[^ "]*/haf-test:[^ "]*' "$root/.aidev/test-stack.compose.yml" | head -1)}"
PSQL_IMAGE="registry.gitlab.syncad.com/hive/common-ci-configuration/psql:$(sed -n 's/^ARG PSQL_CLIENT_VERSION=//p' "$root/Dockerfile")"
built_image=""
if [ -z "${REWRITER_IMAGE:-}" ]; then
    REWRITER_IMAGE="$project-rewriter:local"
    built_image="$REWRITER_IMAGE"
    docker build -f "$root/Dockerfile.rewriter" -t "$REWRITER_IMAGE" "$root"
fi
export HAF_IMAGE PSQL_IMAGE REWRITER_IMAGE

compose_files=(-f "$here/docker-compose.yml")
containment=""
if [ -n "${AIDEV_ENV_CONTAINER_OWNER:-}" ]; then
    containment="$(mktemp)"
    compose_files+=(-f "$containment")
fi

compose() {
    docker compose -p "$project" "${compose_files[@]}" "$@"
}

cleanup() {
    compose logs --no-color > "$results/stack.log" 2>&1 || true
    docker rm -f "$project-tests" > /dev/null 2>&1 || true
    compose --profile setup --profile tests down --volumes --rmi local > /dev/null 2>&1 || true
    if [ -n "$built_image" ]; then docker image rm "$built_image" > /dev/null 2>&1 || true; fi
    if [ -n "$containment" ]; then rm -f "$containment"; fi
}
trap cleanup EXIT

if [ -n "$containment" ]; then
    {
        echo "services:"
        for service in $(docker compose -f "$here/docker-compose.yml" --profile setup --profile tests config --services); do
            echo "  $service:"
            echo "    labels: {testbed.env-container.owner: \"$AIDEV_ENV_CONTAINER_OWNER\"}"
            if [ -n "${AIDEV_ENV_CONTAINER_MEMORY_BYTES:-}" ]; then
                echo "    mem_limit: $AIDEV_ENV_CONTAINER_MEMORY_BYTES"
            fi
        done
    } > "$containment"
fi

compose up --detach --wait haf
tar -cf - -C "$root" scripts db endpoints tests | compose run --rm -T setup
# PostgREST starts after the install, so its schema cache holds the endpoints
compose up --detach nft-tracker-postgrest rewriter

rc=0
compose run --build --name "$project-tests" tests --junitxml=/tmp/junit.xml "$@" || rc=$?
docker cp "$project-tests:/tmp/junit.xml" "$results/junit.xml" || true
echo "Results in $results"
exit "$rc"
