#!/bin/sh

_psql() {
    psql -w -v ON_ERROR_STOP=1 -h localhost -U haf_admin "$@"
}

run_test() {(
    set -e
    TEST="$1"
    DB_NAME="$2"
    ./haf/scripts/setup_db.sh --haf-db-name="$DB_NAME"
    _psql -d "$DB_NAME" -f tests/setup.sql
    _psql -d "$DB_NAME" -f db/schema.sql -f db/builtin_roles.sql -f db/nft_actions.sql -f db/main_loop.sql
    _psql -d "$DB_NAME" -f "tests/functions.sql" -f "tests/$TEST.sql" -c 'CALL test_given()' -c 'CALL test_when()' -c 'CALL test_then()'
)}

find ./tests/ -type f -iname test-\*.sql | while read -r file; do
    echo "Running $file"
    stem=$(basename "$file" .sql)
    run_test "$stem" "nft_$(echo "$stem" | sed -E s/[^[:alnum:]]+/_/g)"
done
