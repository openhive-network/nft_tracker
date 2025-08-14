#! /bin/sh

set -e

print_help () {
    cat <<EOF
Usage: $0 [OPTION[=VALUE]]...

Removes NFT tracker from Postgres database.
OPTIONS:
    --host=VALUE             Allows to specify a PostgreSQL host location (defaults to localhost)
    --port=NUMBER            Allows to specify a PostgreSQL operating port (defaults to 5432)
    --user=VALUE             Allows to specify a PostgreSQL user (defaults to haf_admin)
    --postgres-url=URL       Allows to specify a PostgreSQL URL (empty by default, overrides options above)
    --schema=VALUE           Allows to specify NFT tracker schema (defaults to nfttracker_app)
    --help,-h,-?             Displays this help message
EOF
}

POSTGRES_USER=${POSTGRES_USER:-"haf_admin"}
POSTGRES_HOST=${POSTGRES_HOST:-"localhost"}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_URL=${POSTGRES_URL:-""}
NFTTRACKER_SCHEMA=${NFTTRACKER_SCHEMA:-"nfttracker_app"}

while [ $# -gt 0 ]; do
  case "$1" in
    --host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --port=*)
        POSTGRES_PORT="${1#*=}"
        ;;
    --user=*)
        POSTGRES_USER="${1#*=}"
        ;;
    --postgres-url=*)
        POSTGRES_URL="${1#*=}"
        ;;
    --schema=*)
        NFTTRACKER_SCHEMA="${1#*=}"
        ;;
    --help|-h|-?)
        print_help
        exit 0
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option"
        echo
        print_help
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument"
        echo
        print_help
        exit 2
        ;;
    esac
    shift
done

POSTGRES_ACCESS_ADMIN=${POSTGRES_URL:-"postgresql://$POSTGRES_USER@$POSTGRES_HOST:$POSTGRES_PORT/haf_block_log"}


uninstall_app() {
    remove_context_sql=$(cat << EOF
DO
\$\$
BEGIN
  IF hive.app_context_exists('${NFTTRACKER_SCHEMA}') THEN
   PERFORM hive.app_remove_context('${NFTTRACKER_SCHEMA}');
  END IF;
END\$\$;
EOF
)

    drop_users_sql=$(cat <<EOF
DO
\$\$
BEGIN
 IF NOT EXISTS( SELECT 1 FROM hafd.contexts AS hc WHERE owner = 'nfttracker_owner' ) THEN
    DROP OWNED BY nfttracker_owner CASCADE;
    DROP ROLE nfttracker_owner;
    DROP OWNED BY nfttracker_user CASCADE;
    DROP ROLE nfttracker_user;
 END IF;
END\$\$;
EOF
)

    psql "$POSTGRES_ACCESS_ADMIN" -v "ON_ERROR_STOP=OFF" -c "${remove_context_sql}"
    psql "$POSTGRES_ACCESS_ADMIN" -v "ON_ERROR_STOP=OFF" -c "DROP SCHEMA IF EXISTS ${NFTTRACKER_SCHEMA} CASCADE;"

    psql "$POSTGRES_ACCESS_ADMIN" -c "${drop_users_sql}" || true
}

uninstall_app
