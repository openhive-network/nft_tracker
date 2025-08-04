#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
SETUP_SCRIPT="$PROJECT_ROOT/haf/scripts/setup_db.sh"

PGPORT="${PGPORT:-5432}"
PGHOST="${PGHOST:-localhost}"
DB_NAME="${DB_NAME:-nft_regression_test}"
DB_ADMIN="${DB_ADMIN:-haf_admin}"

_psql() {
    psql -w -v ON_ERROR_STOP=1 -h localhost -U haf_admin -d "$DB_NAME" "$@"
}

quiet() {
    if [ "$VERBOSE" = "1" ]; then
        "$@"
    else
        "$@" >/dev/null 2>&1
    fi
}

cleanup() {
    quiet _psql -d postgres -c "DROP DATABASE IF EXISTS ${DB_NAME}"
}

if [ "$KEEP_DB" != "1" ]; then
    trap cleanup EXIT
fi

cleanup

quiet _psql -d postgres -c "CREATE DATABASE ${DB_NAME}"

quiet "$SETUP_SCRIPT" \
    --haf-db-name="$DB_NAME" \
    --haf-db-admin="$DB_ADMIN" \
    --host="$PGHOST" \
    --port="$PGPORT"

quiet _psql -f ../setup.sql
quiet _psql -f ../../db/schema.sql -f ../../db/nft_actions.sql -f ../../db/main_loop.sql
quiet _psql -f ../prelude.sql

if [ "$VERBOSE" = "1" ]; then
    VERBOSITY=""
else
    VERBOSITY="--set=VERBOSITY=terse"
fi

"$@" "$VERBOSITY" -d "$DB_NAME" 2>&1 | sed \
    -E 's/nfttracker processed block ([0-9]+) successfully in [0-9.]+ s/nfttracker processed block \1 successfully in _ s/'
