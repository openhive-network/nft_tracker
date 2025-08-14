#!/bin/sh -e

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit 1; pwd -P )"

print_help () {
    cat <<EOF
Usage: $0 [OPTION[=VALUE]]...

Script for setting up the NFT tracker database
OPTIONS:
    --postgres-host=HOSTNAME              PostgreSQL hostname (default: localhost)
    --postgres-port=PORT                  PostgreSQL port (default: 5432)
    --postgres-user=USERNAME              PostgreSQL user name (default: haf_admin)
    --postgres-url=URL                    PostgreSQL URL (if set, overrides three previous options, empty by default)
    --help,-h,-?                          Displays this help message
EOF
}

POSTGRES_USER=${POSTGRES_USER:-"haf_admin"}
POSTGRES_HOST=${POSTGRES_HOST:-"localhost"}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_URL=${POSTGRES_URL:-""}
NFTTRACKER_SCHEMA=${NFTTRACKER_SCHEMA:-"nfttracker_app"}

while [ $# -gt 0 ]; do
  case "$1" in
    --postgres-host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --postgres-port=*)
        POSTGRES_PORT="${1#*=}"
        ;;
    --postgres-user=*)
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
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument"
        echo
        exit 2
        ;;
    esac
    shift
done

POSTGRES_ACCESS=${POSTGRES_URL:-"postgresql://$POSTGRES_USER@$POSTGRES_HOST:$POSTGRES_PORT/haf_block_log"}

echo "Installing app..."
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../db/builtin_roles.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../db/schema.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../db/nft_actions.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../db/main_loop.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -c "SET ROLE nfttracker_owner; GRANT USAGE ON SCHEMA ${NFTTRACKER_SCHEMA} to nfttracker_user;"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -c "SET ROLE nfttracker_owner; GRANT SELECT ON ALL TABLES IN SCHEMA ${NFTTRACKER_SCHEMA} TO nfttracker_user;"
