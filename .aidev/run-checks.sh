#!/usr/bin/env bash
# The step functions are called indirectly, through `step`.
# shellcheck disable=SC2317,SC2329
# The checks AIDEV's verification slots run (.aidev/project.yaml), as one junit
# report per suite: each named step is a test case, its log the failure body.
#
#   .aidev/run-checks.sh <suite> <step>...
#
#   - shellcheck      ShellCheck at error severity on the project's scripts (CI
#                     runs no linter; scripts/ carries warnings today), and
#                     at the default severity on .aidev/'s own scripts
#   - sql-registered  every .sql file under db/ and endpoints/ is applied by
#                     scripts/install_app.sh (a file it misses never reaches a database)
#   - stack-pins      the HAF test image of .aidev/test-stack.compose.yml is the
#                     haf-test tag for .gitlab-ci.yml's HAF_VERSION (reads only the tree)
#   - install         scripts/install_app.sh into the stack's haf_block_log
#                     (NFTTRACKER_TEST_DB_HOST, default `haf`) through
#                     install_with_app_lock.py (CI's install_app step); the context
#                     and the version row must exist
#   - regression      ./regress.sh, CI's regression_tests job: pg_regress over every
#                     tests/regression/sql/test_*.sql, each in a fresh HAF database
#                     seeded with mock blocks; one junit case per test in regression.xml
#   - api             tests/api_tests as run_api_tests.sh runs them (a fresh HAF
#                     database, install, the mock data, block processing, PostgREST,
#                     the tavern files); one junit case per test in api.xml
#   - reinstall       scripts/install_app.sh again over the installed schema (an
#                     upgrade in place); the context must survive
#   - uninstall       scripts/uninstall_app.sh; the context and schemas must be gone;
#                     then install again from scratch
#
# The steps from install on need the HAF stack (.aidev/test-stack.compose.yml).
# tests/regression's Makefile and pg_regress options name localhost:5432, so those
# steps forward it to the stack's HAF with socat. Reports go to
# test-results/<suite>/: junit.xml (one case per step), regression.xml, api.xml.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

suite="${1:?usage: $0 <suite> <step>...}"; shift
out="test-results/$suite"
rm -rf "$out"; mkdir -p "$out"
cases="$out/cases.tsv"; : > "$cases"

SCHEMA=nfttracker_app
DB_HOST="${NFTTRACKER_TEST_DB_HOST:-haf}"
ADMIN_URL="postgresql://haf_admin@$DB_HOST:5432/haf_block_log"
API_PORT=18080

status=0
# record CASES_FILE NAME RC SECONDS LOG
record() {
    if [ "$3" -eq 0 ]; then
        printf 'case\t%s\tpass\t%s\t\n' "$2" "$4" >> "$1"
    else
        printf 'case\t%s\tfail\t%s\texit %s\t%s\n' "$2" "$4" "$3" "$5" >> "$1"
    fi
}

step() {
    local name="$1"; shift
    local log="$out/$name.log" t0=$SECONDS rc=0
    echo "== $name" >&2
    "$@" > "$log" 2>&1 < /dev/null || rc=$?
    [ "$rc" -eq 0 ] || { status=1; tail -40 "$log" >&2; }
    record "$cases" "$name" "$rc" "$((SECONDS - t0))" "$log"
}

run_shellcheck() {
    shellcheck --version | head -2
    find . -name .git -prune -o -name .aidev -prune -o -name test-results -prune -o -type f -name '*.sh' -print0 | sort -z \
        | xargs -0 shellcheck -S error -f gcc || return 1
    shellcheck -f gcc .aidev/*.sh .aidev/runtime/*.sh
}

sql_registered() {
    local f missing=0
    while IFS= read -r f; do
        if ! grep -qF "\$SCRIPTPATH/../$f\"" scripts/install_app.sh; then
            echo "not applied by scripts/install_app.sh: $f"
            missing=1
        fi
    done < <(find db endpoints -name '*.sql' | sort)
    [ "$missing" -eq 0 ] && echo "every .sql file under db/ and endpoints/ is applied"
    return "$missing"
}

# CI builds its regression image as haf-test:${HAF_VERSION}-v2; the stack must run
# that same tag. (The runtime image follows ccc's haf-app-test-runner instead.)
stack_pins() {
    local version want f=.aidev/test-stack.compose.yml
    version="$(sed -n 's/^ *HAF_VERSION: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' .gitlab-ci.yml)"
    if [ -z "$version" ] || [ "$(printf '%s\n' "$version" | wc -l)" -ne 1 ]; then
        echo "expected one HAF_VERSION in .gitlab-ci.yml, found '$version'"
        return 1
    fi
    want="registry.gitlab.syncad.com/hive/nft_tracker/haf-test:$version-v2@sha256:"
    echo ".gitlab-ci.yml HAF_VERSION: $version"
    if ! grep -q "${want}[0-9a-f]\{64\}" "$f"; then
        echo "STALE: $f does not pin ${want}<digest>: re-pin it (.aidev/README.md)"
        return 1
    fi
    echo "$f: $(grep -o 'hive/nft_tracker/haf-test:[^ "]*' "$f" | head -1)"
}

q() { psql "$ADMIN_URL" -v ON_ERROR_STOP=on -X "$@"; }

# localhost:5432 -> the stack's HAF, for the project's own scripts that name localhost.
forward=""
start_forward() {
    [ -n "$forward" ] && return 0
    socat TCP-LISTEN:5432,bind=127.0.0.1,fork,reuseaddr "TCP:$DB_HOST:5432" &
    forward=$!
    local i
    for i in $(seq 1 50); do
        psql -h localhost -U haf_admin -d haf_block_log -Atc 'select 1' >/dev/null 2>&1 && return 0
        sleep 0.1
    done
    echo "could not reach $DB_HOST:5432 through localhost:5432"
    return 1
}

postgrest_pid=""
cleanup() {
    if [ -n "$postgrest_pid" ]; then kill "$postgrest_pid" 2>/dev/null || true; fi
    if [ -n "$forward" ]; then kill "$forward" 2>/dev/null || true; fi
}
trap cleanup EXIT

check_installed() {
    q -Atc "select hive.app_context_exists('$SCHEMA')" | grep -qx t || { echo "context $SCHEMA does not exist"; return 1; }
    echo "version: $(q -Atc "select git_hash from $SCHEMA.version")"
}

install() {
    local log
    log="$(mktemp)"
    bash scripts/install_app.sh --postgres-url="$ADMIN_URL" 2>&1 | tee "$log"
    [ "${PIPESTATUS[0]}" -eq 0 ] || return 1
    if grep -q 'install_with_app_lock.py wrapper not found' "$log"; then
        echo "install ran without the HAF install lock"
        return 1
    fi
    check_installed
}

reinstall() {
    install
}

uninstall() {
    local left
    bash scripts/uninstall_app.sh --postgres-url="$ADMIN_URL" || return 1
    q -Atc "select hive.app_context_exists('$SCHEMA')" | grep -qx f || { echo "context $SCHEMA survived the uninstall"; return 1; }
    left="$(q -Atc "select count(*) from pg_namespace where nspname in ('$SCHEMA','nfttracker_backend','nfttracker_endpoints')")" || return 1
    [ "$left" = 0 ] || { echo "$left nft_tracker schemas survived the uninstall"; return 1; }
    install
}

# CI's regression_tests job runs ./regress.sh in the HAF container; here it runs in
# the runtime image (the same psql, pg_regress and PGXS) against the stack's HAF.
regression() {
    local rc=0 log
    start_forward || return 1
    log="$(mktemp)"
    ./regress.sh 2>&1 | tee "$log"
    rc="${PIPESTATUS[0]}"
    python3 .aidev/pg_regress_junit.py "$1" regression "$log" || true
    if [ "$rc" -ne 0 ]; then
        cat tests/regression/regression.diffs 2>/dev/null
    fi
    return "$rc"
}

# tests/api_tests/run_api_tests.sh, without its postgrest.conf precondition (the
# file is not in the tree and nothing reads it).
api() {
    local junit="$1" db=nft_api_test url i
    start_forward || return 1
    url="postgresql://haf_admin@localhost:5432/$db"
    scripts/setup_db.sh --haf-db-name="$db" --haf-db-admin=haf_admin --host=localhost --port=5432 || return 1
    POSTGRES_URL="$url" SWAGGER_URL="localhost:$API_PORT" bash scripts/install_app.sh --postgres-url="$url" || return 1
    psql "$url" -v ON_ERROR_STOP=1 -X -f tests/setup.sql -f tests/prelude.sql -f tests/api_tests/mock_data.sql \
        -c 'CALL nfttracker_sync_blocks();' || return 1
    scripts/start_postgrest.sh --postgres-url="$url" --webserver-port="$API_PORT" --admin-port=13001 &
    postgrest_pid=$!
    for i in $(seq 1 30); do
        curl -fsS "http://localhost:$API_PORT/" >/dev/null 2>&1 && break
        [ "$i" -eq 30 ] && { echo "PostgREST did not become ready"; return 1; }
        sleep 1
    done
    # The tavern files name http://localhost:8080 (tavern_global_config.yaml).
    local tdir
    tdir="$(mktemp -d)"
    cp tests/api_tests/*.yaml "$tdir/"
    sed -i "s|http://localhost:8080|http://localhost:$API_PORT|" "$tdir/tavern_global_config.yaml"
    local rc=0
    (cd "$tdir" && pytest -vv -p no:cacheprovider --junitxml="$OLDPWD/$junit" ./*.tavern.yaml) || rc=$?
    kill "$postgrest_pid" 2>/dev/null; wait "$postgrest_pid" 2>/dev/null; postgrest_pid=""
    # The database's objects belong to the app's roles, which uninstall drops.
    psql "postgresql://haf_admin@localhost:5432/postgres" -X -c "DROP DATABASE IF EXISTS $db WITH (FORCE)" || rc=1
    return "$rc"
}

for s in "$@"; do
    case "$s" in
        shellcheck) step shellcheck run_shellcheck ;;
        sql-registered) step sql-registered sql_registered ;;
        stack-pins) step stack-pins stack_pins ;;
        install) step install install ;;
        regression) step regression regression "$out/regression.xml" ;;
        api) step api api "$out/api.xml" ;;
        reinstall) step reinstall reinstall ;;
        uninstall) step uninstall uninstall ;;
        *) echo "unknown step: $s" >&2; exit 2 ;;
    esac
done
python3 .aidev/junit_cases.py "$out/junit.xml" "$suite" "$cases"
exit "$status"
