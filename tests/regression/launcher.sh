#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SETUP_SCRIPT="$PROJECT_ROOT/scripts/setup_db.sh"

: "${PGPORT:?Error: PGPORT is not defined}"
: "${PGHOST:?Error: PGHOST is not defined}"
: "${DB_NAME:?Error: DB_NAME is not defined}"
: "${DB_ADMIN:?Error: DB_ADMIN is not defined}"

VERBOSE="${VERBOSE:-}"
KEEP_DB="${KEEP_DB:-}"

_psql() {
    psql -w -v ON_ERROR_STOP=1 -h "$PGHOST" -U "$DB_ADMIN" -d "$DB_NAME" "$@"
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

quiet "$SETUP_SCRIPT" \
    --haf-db-name="$DB_NAME" \
    --haf-db-admin="$DB_ADMIN" \
    --host="$PGHOST" \
    --port="$PGPORT"

quiet _psql -f ../setup.sql
quiet _psql -f ../../db/schema.sql -f ../../db/operation_types.sql -f ../../db/nft_actions.sql -f ../../db/main_loop.sql
quiet _psql -c "SET custom.swagger_url = 'localhost';" -f ../../endpoints/endpoint_schema.sql
quiet _psql \
    -f ../../endpoints/types/nft_type.sql \
    -f ../../endpoints/types/nft_instance.sql \
    -f ../../endpoints/types/nft_instance_with_type.sql \
    -f ../../endpoints/backend/get_nft_instances.sql \
    -f ../../endpoints/backend/get_nft_instances_by_trx.sql \
    -f ../../endpoints/get_version.sql \
    -f ../../endpoints/get_nft_types.sql \
    -f ../../endpoints/get_nft_instances_with_tags.sql \
    -f ../../endpoints/get_nft_instances.sql \
    -f ../../endpoints/get_nft_instances_by_trx.sql
quiet _psql -f ../prelude.sql

if [ "$VERBOSE" = "1" ]; then
    VERBOSITY=""
else
    VERBOSITY="--set=VERBOSITY=terse"
fi

"$@" "$VERBOSITY" -P 'null=(null)' -d "$DB_NAME" 2>&1 | sed \
    -E 's/nfttracker processed block ([0-9]+) successfully in [0-9.]+ s/nfttracker processed block \1 successfully in _ s/'
