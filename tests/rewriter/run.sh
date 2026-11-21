#!/usr/bin/env bash
# Tests the rewriter image (Dockerfile.rewriter) in front of PostgREST and HAF with
# nft_tracker installed over tests/api_tests' mock data: starts docker-compose.yml's
# stack and runs the pytest suite of this directory in it, serving the suite's requests
# for a change of the stack (stack_requests.py) while it runs.
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
tests_container="$project-tests"
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
    docker rm -f "$tests_container" > /dev/null 2>&1 || true
    compose --profile setup --profile tests --profile recreate down --volumes --rmi local > /dev/null 2>&1 || true
    if [ -n "$built_image" ]; then docker image rm "$built_image" > /dev/null 2>&1 || true; fi
    if [ -n "$containment" ]; then rm -f "$containment"; fi
}
trap cleanup EXIT

if [ -n "$containment" ]; then
    {
        echo "services:"
        for service in $(docker compose -f "$here/docker-compose.yml" --profile setup --profile tests --profile recreate config --services); do
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

# Recreates the PostgREST alone, with another container holding the address it had, so
# only a rewriter that resolves its name again reaches it (Docker would reuse the address)
recreate_postgrest() {
    compose stop nft-tracker-postgrest &&
        compose --profile recreate up --detach --no-deps address-taker &&
        compose up --detach --no-deps --force-recreate nft-tracker-postgrest
}

rewriter_state() {
    docker inspect --format '{{.Id}} {{.State.StartedAt}} {{.State.Pid}}' "$(compose ps -q rewriter)"
}

# Answers the request the suite left in $STACK_REQUESTS of its container, if any
serve_stack_request() {
    local request reply
    request="$(docker exec "$tests_container" cat /tmp/stack-requests/request 2> /dev/null)" || return 0
    case "$request" in
        recreate-postgrest) if recreate_postgrest >&2; then reply=done; else reply="error: the recreate failed"; fi ;;
        rewriter-state) reply="$(rewriter_state)" || reply="error: no rewriter state" ;;
        *) reply="error: unknown request $request" ;;
    esac
    printf '%s' "$reply" | docker exec -i "$tests_container" sh -c \
        'cd /tmp/stack-requests && rm request && cat > reply.tmp && mv reply.tmp reply' \
        || echo "could not answer the suite's request $request" >&2
}

rc=0
compose run --build -T --name "$tests_container" tests --junitxml=/tmp/junit.xml "$@" < /dev/null &
tests_pid=$!
while kill -0 "$tests_pid" 2> /dev/null; do
    serve_stack_request
    sleep 0.2
done
wait "$tests_pid" || rc=$?
docker cp "$tests_container:/tmp/junit.xml" "$results/junit.xml" || true
echo "Results in $results"
exit "$rc"
