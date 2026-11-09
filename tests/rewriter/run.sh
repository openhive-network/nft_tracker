#!/usr/bin/env bash
# Tests the rewriter image (Dockerfile.rewriter) in front of PostgREST and HAF with
# nft_tracker installed over tests/api_tests' mock data: starts docker-compose.yml's
# stack and runs the pytest suite of this directory in it.
#
#   tests/rewriter/run.sh [pytest args...]
#
# REWRITER_IMAGE  the rewriter image to test (default: built from Dockerfile.rewriter)
# HAF_IMAGE       default: $HAF_REGISTRY:$HAF_VERSION of .gitlab-ci.yml
# RESULTS_DIR     where junit.xml and the stack's logs go (default: a new temporary
#                 directory)
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
root="$(cd "$here/../.." && pwd)"
results="${RESULTS_DIR:-$(mktemp -d)}"
mkdir -p "$results"

ci_variable() {
    sed -n "s/^ *$1: *\"\{0,1\}\([^\"]*\)\"\{0,1\} *$/\1/p" "$root/.gitlab-ci.yml" | head -1
}

project="nft-rewriter-test-$$"
HAF_IMAGE="${HAF_IMAGE:-$(ci_variable HAF_REGISTRY):$(ci_variable HAF_VERSION)}"
PSQL_IMAGE="registry.gitlab.syncad.com/hive/common-ci-configuration/psql:$(sed -n 's/^ARG PSQL_CLIENT_VERSION=//p' "$root/Dockerfile")"
built_image=""
if [ -z "${REWRITER_IMAGE:-}" ]; then
    REWRITER_IMAGE="$project-rewriter:local"
    built_image="$REWRITER_IMAGE"
    docker build -f "$root/Dockerfile.rewriter" -t "$REWRITER_IMAGE" "$root"
fi
export HAF_IMAGE PSQL_IMAGE REWRITER_IMAGE

compose() {
    docker compose -p "$project" -f "$here/docker-compose.yml" "$@"
}

cleanup() {
    compose logs --no-color > "$results/stack.log" 2>&1 || true
    docker rm -f "$project-tests" > /dev/null 2>&1 || true
    compose --profile setup --profile tests down --volumes --rmi local > /dev/null 2>&1 || true
    if [ -n "$built_image" ]; then docker image rm "$built_image" > /dev/null 2>&1 || true; fi
}
trap cleanup EXIT

compose up --detach --wait haf
tar -cf - -C "$root" scripts db endpoints tests | compose run --rm -T setup
# PostgREST starts after the install, so its schema cache holds the endpoints
compose up --detach nft-tracker-postgrest rewriter

rc=0
compose run --build --name "$project-tests" tests --junitxml=/tmp/junit.xml "$@" || rc=$?
docker cp "$project-tests:/tmp/junit.xml" "$results/junit.xml" || true
echo "Results in $results"
exit "$rc"
