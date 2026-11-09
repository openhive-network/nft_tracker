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
#   - stack-pins      the HAF test image of .aidev/test-stack.compose.yml is pinned as
#                     hive/nft_tracker/haf-test:<HAF tag>-v2@sha256:<digest>, and that
#                     tag and digest are in the registry (when it is reachable: the
#                     stackless slots run without a network)
#   - install         scripts/install_app.sh into the stack's haf_block_log
#                     (NFTTRACKER_TEST_DB_HOST, default `haf`) through
#                     install_with_app_lock.py (CI's install_app step); the context
#                     and the version row must exist, every function in
#                     nfttracker_endpoints must be STABLE or IMMUTABLE and root()
#                     must run as nfttracker_user READ ONLY
#                     (.aidev/endpoint_volatility_check.sql), and on a HAF with the
#                     application registry the context's only row is `nft_tracker`
#   - regression      ./regress.sh, CI's regression_tests job: pg_regress over every
#                     tests/regression/sql/test_*.sql, each in a fresh HAF database
#                     seeded with mock blocks; one junit case per test in regression.xml
#   - api             tests/api_tests as run_api_tests.sh runs them (a fresh HAF
#                     database, install, the mock data, block processing, PostgREST,
#                     the tavern files); one junit case per test in api.xml
#   - reinstall       scripts/install_app.sh again over the installed schema (an
#                     upgrade in place), paused in the registry; the context and
#                     the paused flag must survive
#   - uninstall       scripts/uninstall_app.sh; the context and schemas must be gone;
#                     then install again from scratch
#   - registry-old-name in a throwaway HAF database, the context registered under
#                     the old name `nfttracker_app`: the install must fail naming
#                     it, and leave that row as it was
#   - sync            in a throwaway HAF database seeded with tests/api_tests'
#                     mock blocks, scripts/process_blocks.sh (haf_app_driver.py
#                     --app=nft_tracker) processes them all
#   - entry-dropped   in a throwaway HAF database, with the registered entry
#                     procedure dropped, scripts/process_blocks.sh is refused the
#                     `nft_tracker` lock ("reinstall the application"); skipped on
#                     a HAF before haf#403
#
# A step that exits 77 is skipped, its log's last `SKIP: ` line the reason.
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
APP=nft_tracker
SKIP=77
DB_HOST="${NFTTRACKER_TEST_DB_HOST:-haf}"
ADMIN_URL="postgresql://haf_admin@$DB_HOST:5432/haf_block_log"
API_PORT=18080

status=0
# record CASES_FILE NAME RC SECONDS LOG
record() {
    if [ "$3" -eq 0 ]; then
        printf 'case\t%s\tpass\t%s\t\n' "$2" "$4" >> "$1"
    elif [ "$3" -eq "$SKIP" ]; then
        printf 'case\t%s\tskip\t%s\t%s\n' "$2" "$4" "$(grep '^SKIP: ' "$5" | tail -n 1)" >> "$1"
    else
        printf 'case\t%s\tfail\t%s\texit %s\t%s\n' "$2" "$4" "$3" "$5" >> "$1"
    fi
}

step() {
    local name="$1"; shift
    local log="$out/$name.log" t0=$SECONDS rc=0
    echo "== $name" >&2
    "$@" > "$log" 2>&1 < /dev/null || rc=$?
    if [ "$rc" -eq "$SKIP" ]; then
        grep '^SKIP: ' "$log" | tail -n 1 >&2
    elif [ "$rc" -ne 0 ]; then
        status=1; tail -40 "$log" >&2
    fi
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

# CI builds its regression image as haf-test:<HAF tag>-v2 over the HAF develop image
# find_haf_image resolves, which floats; a gate must run a digest-pinned image, so the
# stack pins one such tag (re-pinned when HAF develop moves on, .aidev/README.md).
# (The runtime image follows ccc's haf-app-test-runner instead.)
stack_pins() {
    local f=.aidev/test-stack.compose.yml repo=hive/nft_tracker/haf-test
    local registry=registry.gitlab.syncad.com pin tag digest token ref body
    pin="$(grep -o "$registry/$repo:[^ \"]*" "$f")"
    if [ "$(printf '%s\n' "$pin" | grep -c .)" -ne 1 ] \
        || ! printf '%s\n' "$pin" | grep -qx "$registry/$repo:[0-9a-f]\{8,40\}-v2@sha256:[0-9a-f]\{64\}"; then
        echo "expected one $registry/$repo:<hex tag>-v2@sha256:<digest> in $f, found '$pin'"
        return 1
    fi
    echo "$f: $pin"
    tag="${pin#*:}"; tag="${tag%%@*}"
    digest="${pin#*@}"
    # The stackless slots run without a network: there only the form is checked, and
    # the slots with the stack (which pull this image) check the registry. Only a
    # definite "not there" fails; a registry that does not answer says nothing of the pin.
    body="$(mktemp)"
    registry_get "$body" "https://gitlab.syncad.com/jwt/auth?service=container_registry&scope=repository:$repo:pull"
    if [ -n "$reg_cause" ] || [ "$reg_status" != 200 ]; then
        echo "NOTE: no pull token from gitlab.syncad.com (${reg_cause:-HTTP $reg_status}): the pin's form is checked, its presence in the registry is not"
        rm -f "$body"
        return 0
    fi
    token="$(jq -er .token "$body")" || { echo "could not read a pull token for $repo"; rm -f "$body"; return 1; }
    rm -f "$body"
    for ref in "$tag" "$digest"; do
        registry_get /dev/null -I -H "Authorization: Bearer $token" \
            -H 'Accept: application/vnd.docker.distribution.manifest.v2+json, application/vnd.oci.image.manifest.v1+json, application/vnd.oci.image.index.v1+json, application/vnd.docker.distribution.manifest.list.v2+json' \
            "https://$registry/v2/$repo/manifests/$ref"
        case "$reg_cause:$reg_status" in
            :2??) echo "in the registry: $repo $ref" ;;
            :404|:401|:403)
                echo "MISSING: $registry/$repo $ref is not in the registry (HTTP $reg_status): build and push it, then re-pin (.aidev/README.md)"
                return 1 ;;
            *)
                echo "NOTE: $registry gave no answer for $repo $ref (${reg_cause:-HTTP $reg_status}): the pin's form is checked, its presence in the registry is not"
                return 0 ;;
        esac
    done
}

# registry_get OUT CURL_ARGS...: the response body in OUT and its HTTP status in
# reg_status; reg_cause names why there was no complete answer (a curl exit, or a
# 5xx/429 the registry may answer differently on retry), empty when there was one.
registry_get() {
    local out="$1" rc=0; shift
    reg_status="$(curl -sS --connect-timeout 5 --max-time 30 -o "$out" -w '%{http_code}' "$@")" || rc=$?
    reg_cause=""
    if [ "$rc" -ne 0 ]; then
        reg_cause="curl exit $rc"
    elif [ "$reg_status" = 429 ] || [ "${reg_status#5}" != "$reg_status" ]; then
        reg_cause="HTTP $reg_status"
    fi
}

q() { psql "$ADMIN_URL" -v ON_ERROR_STOP=on -X "$@"; }

has_registry() {
    [ "$(psql "$1" -X -Atc "select to_regclass('hafd.applications') is not null")" = t ]
}

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
    local rows
    q -Atc "select hive.app_context_exists('$SCHEMA')" | grep -qx t || { echo "context $SCHEMA does not exist"; return 1; }
    echo "version: $(q -Atc "select git_hash from $SCHEMA.version")"
    q -q -f .aidev/endpoint_volatility_check.sql || return 1
    if ! has_registry "$ADMIN_URL"; then
        echo "no HAF application registry (older than haf#341): registration not checked"
        return 0
    fi
    # Under the lock name, where HAF's lock helpers look it up (haf#403)
    rows="$(q -Atc "select string_agg(name, ',' order by name) from hafd.applications where contexts @> array['$SCHEMA']")" || return 1
    [ "$rows" = "$APP" ] || { echo "registry rows holding $SCHEMA: '$rows', expected only $APP"; return 1; }
    echo "registered as $APP"
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
    local paused
    has_registry "$ADMIN_URL" || { install; return; }
    q -c "SELECT hive.app_pause('$APP')" || return 1
    install || return 1
    paused="$(q -Atc "select paused from hafd.applications where name = '$APP'")" || return 1
    q -c "SELECT hive.app_resume('$APP')" || return 1
    [ "$paused" = t ] || { echo "the reinstall lost $APP's paused flag (paused: '$paused')"; return 1; }
    echo "$APP stayed paused"
}

uninstall() {
    local left
    bash scripts/uninstall_app.sh --postgres-url="$ADMIN_URL" || return 1
    q -Atc "select hive.app_context_exists('$SCHEMA')" | grep -qx f || { echo "context $SCHEMA survived the uninstall"; return 1; }
    left="$(q -Atc "select count(*) from pg_namespace where nspname in ('$SCHEMA','nfttracker_backend','nfttracker_endpoints')")" || return 1
    [ "$left" = 0 ] || { echo "$left nft_tracker schemas survived the uninstall"; return 1; }
    install
}

# with_fresh_db NAME FUNCTION: FUNCTION <url> in a throwaway HAF database NAME,
# dropped afterwards whatever FUNCTION returns
with_fresh_db() {
    local db="$1" fn="$2" rc=0 url
    start_forward || return 1
    url="postgresql://haf_admin@localhost:5432/$db"
    scripts/setup_db.sh --haf-db-name="$db" --haf-db-admin=haf_admin --host=localhost --port=5432 || return 1
    "$fn" "$url" || rc=$?
    # The database's objects belong to the app's roles, which uninstall drops.
    psql "postgresql://haf_admin@localhost:5432/postgres" -X -c "DROP DATABASE IF EXISTS $db WITH (FORCE)" || rc=1
    return "$rc"
}

registry_row() {
    psql "$1" -X -Atc "select name, contexts, process_procedure, paused from hafd.applications where name = '$2'"
}

old_name_case() {
    local url="$1" before after out rc=0
    has_registry "$url" || { echo "SKIP: this HAF has no application registry (older than haf#341)"; return "$SKIP"; }
    bash scripts/install_app.sh --postgres-url="$url" || return 1
    # The registration an install from before the rename left
    psql "$url" -X -v ON_ERROR_STOP=on -c "SET ROLE nfttracker_owner" \
        -c "SELECT hive.app_unregister('$APP')" \
        -c "SELECT hive.app_register('$SCHEMA', ARRAY['$SCHEMA']::hive.contexts_group, '$SCHEMA.process_blocks')" \
        -c "SELECT hive.app_pause('$SCHEMA')" || return 1
    before="$(registry_row "$url" "$SCHEMA")"
    out="$(bash scripts/install_app.sh --postgres-url="$url" 2>&1)" || rc=$?
    echo "$out"
    [ "$rc" -ne 0 ] || { echo "the install succeeded over a row named $SCHEMA"; return 1; }
    if ! grep -qF "Application $SCHEMA in hafd.applications holds context $SCHEMA" <<<"$out" \
        || ! grep -qF "Replay from scratch, or run SELECT hive.app_unregister('$SCHEMA'); and reinstall" <<<"$out"; then
        echo "the install failed without naming the row $SCHEMA and the remedy"; return 1
    fi
    after="$(registry_row "$url" "$SCHEMA")"
    if [ -z "$before" ] || [ "$before" != "$after" ]; then
        echo "row $SCHEMA changed: '$before' -> '$after'"; return 1
    fi
    [ -z "$(registry_row "$url" "$APP")" ] || { echo "a row $APP appeared"; return 1; }
    echo "install refused the row $SCHEMA (exit $rc) and left it unchanged"
}

registry_old_name() {
    with_fresh_db nft_registry_test old_name_case
}

# scripts/process_blocks.sh as the production image runs it, as nfttracker_owner
process_blocks_as_owner() {
    local url="$1"; shift
    command -v haf_app_driver.py >/dev/null || { echo "haf_app_driver.py is not on PATH"; return 1; }
    # The driver's psycopg2 is in ccc's venv
    [ -d /python_venv/bin ] && PATH="/python_venv/bin:$PATH"
    timeout 120 bash scripts/process_blocks.sh --postgres-url="${url/haf_admin@/nfttracker_owner@}" "$@"
}

sync_case() {
    local url="$1" top current types out rc=0
    bash scripts/install_app.sh --postgres-url="$url" || return 1
    psql "$url" -v ON_ERROR_STOP=1 -X -q -f tests/setup.sql -f tests/prelude.sql -f tests/api_tests/mock_data.sql || return 1
    top="$(psql "$url" -X -Atc "select max(num) from hafd.blocks")" || return 1
    out="$(process_blocks_as_owner "$url" --stop-at-block="$top" 2>&1)" || rc=$?
    echo "$out"
    [ "$rc" -eq 0 ] || { echo "process_blocks.sh exited $rc"; return 1; }
    grep -qF "application '$APP'" <<<"$out" || { echo "haf_app_driver.py did not run application $APP"; return 1; }
    current="$(psql "$url" -X -Atc "select hive.app_get_current_block_num('$SCHEMA')")" || return 1
    types="$(psql "$url" -X -Atc "select count(*) from $SCHEMA.types")" || return 1
    [ "$current" -ge "$top" ] || { echo "processed up to block $current, expected $top"; return 1; }
    [ "$types" -eq 6 ] || { echo "$types NFT types after processing, expected the mock data's 6"; return 1; }
    echo "processed blocks up to $current under $APP: $types NFT types"
}

sync_blocks() {
    with_fresh_db nft_sync_test sync_case
}

entry_dropped_case() {
    local url="$1" out rc=0
    if [ "$(psql "$url" -X -Atc "select to_regprocedure('hive._missing_app_process_procedure(text)') is not null")" != t ]; then
        echo "SKIP: this HAF predates haf#403 (no hive._missing_app_process_procedure), so it does not refuse the lock"
        return "$SKIP"
    fi
    bash scripts/install_app.sh --postgres-url="$url" || return 1
    psql "$url" -X -v ON_ERROR_STOP=on -c "SET ROLE nfttracker_owner" \
        -c "DROP PROCEDURE $SCHEMA.process_blocks(hive.blocks_range)" || return 1
    out="$(process_blocks_as_owner "$url" 2>&1)" || rc=$?
    echo "$out"
    if [ "$rc" -ne 0 ] && [ "$rc" -ne 124 ] \
        && grep -q "Cannot take block-processor lock on $APP: .*reinstall the application" <<<"$out"; then
        echo "HAF refused the $APP lock with the entry procedure dropped"
        return 0
    fi
    echo "process_blocks.sh was not refused the $APP lock (exit $rc)"
    return 1
}

entry_dropped() {
    with_fresh_db nft_entry_dropped_test entry_dropped_case
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
        registry-old-name) step registry-old-name registry_old_name ;;
        sync) step sync sync_blocks ;;
        entry-dropped) step entry-dropped entry_dropped ;;
        *) echo "unknown step: $s" >&2; exit 2 ;;
    esac
done
python3 .aidev/junit_cases.py "$out/junit.xml" "$suite" "$cases"
exit "$status"
