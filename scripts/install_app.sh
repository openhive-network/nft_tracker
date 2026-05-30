#!/bin/sh -e

SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 || exit 1; pwd -P )"

# Re-exec under the install-lock wrapper if not already running under it AND
# the wrapper plus python3 are actually available (e.g. inside the production
# install image). The wrapper holds an exclusive advisory lock on 'nft_tracker'
# for the lifetime of this script; if a block-processor is holding the shared
# lock the wrapper logs the holder and exits 0 without running the install.
# When the wrapper isn't installed (e.g. running this script directly on a
# CI runner host outside the production image), skip the re-exec and run the
# install without the lock -- the lock is a production safety mechanism, not
# a correctness requirement for isolated test runs.
# POSIX sh has no arrays, so the re-exec happens before the arg-parse loop
# (while "$@" is intact) with a minimal scan just to build the DSN.
if [ -z "${HAF_INSTALL_LOCK_HELD:-}" ] \
    && command -v python3 >/dev/null 2>&1 \
    && [ -f /usr/local/bin/install_with_app_lock.py ]; then
  _pg_user="${POSTGRES_USER:-haf_admin}"
  _pg_host="${POSTGRES_HOST:-localhost}"
  _pg_port="${POSTGRES_PORT:-5432}"
  _pg_url="${POSTGRES_URL:-}"
  for _arg in "$@"; do
    case "$_arg" in
      --postgres-host=*) _pg_host="${_arg#*=}" ;;
      --postgres-port=*) _pg_port="${_arg#*=}" ;;
      --postgres-user=*) _pg_user="${_arg#*=}" ;;
      --postgres-url=*)  _pg_url="${_arg#*=}" ;;
    esac
  done
  _dsn="${_pg_url:-postgresql://$_pg_user@$_pg_host:$_pg_port/haf_block_log}"
  export HAF_INSTALL_LOCK_HELD=1
  exec python3 /usr/local/bin/install_with_app_lock.py nft_tracker "$_dsn" "$0" "$@"
fi

print_help () {
    cat <<EOF
Usage: $0 [OPTION[=VALUE]]...

Script for setting up the NFT tracker database
OPTIONS:
    --postgres-host=HOSTNAME              PostgreSQL hostname (default: localhost)
    --postgres-port=PORT                  PostgreSQL port (default: 5432)
    --postgres-user=USERNAME              PostgreSQL user name (default: haf_admin)
    --postgres-url=URL                    PostgreSQL URL (if set, overrides three previous options, empty by default)
    --swagger-url=URL                     Server URL for OpenAPI documentation (default: localhost)
    --help,-h,-?                          Displays this help message
EOF
}

POSTGRES_USER=${POSTGRES_USER:-"haf_admin"}
POSTGRES_HOST=${POSTGRES_HOST:-"localhost"}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_URL=${POSTGRES_URL:-""}
NFTTRACKER_SCHEMA=${NFTTRACKER_SCHEMA:-"nfttracker_app"}
SWAGGER_URL=${SWAGGER_URL:-"localhost"}

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
    --swagger-url=*)
        SWAGGER_URL="${1#*=}"
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
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../db/operation_types.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../db/nft_actions.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../db/main_loop.sql"

echo "Installing API endpoints..."
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -c "SET custom.swagger_url = '$SWAGGER_URL';" -f "$SCRIPTPATH/../endpoints/endpoint_schema.sql"

psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/types/nft_type.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/types/nft_instance.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/types/nft_instance_with_type.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/types/trx_result.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/backend/get_nft_instances.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/backend/get_nft_instances_by_trx.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/backend/get_trx_results.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/get_version.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/get_nft_types.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/get_nft_instances_with_tags.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/get_nft_instances.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/get_nft_instances_by_trx.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/get_trx_results.sql"

echo "Granting permissions..."
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -c "SET ROLE nfttracker_owner; GRANT USAGE ON SCHEMA ${NFTTRACKER_SCHEMA} to nfttracker_user;"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -c "SET ROLE nfttracker_owner; GRANT SELECT ON ALL TABLES IN SCHEMA ${NFTTRACKER_SCHEMA} TO nfttracker_user;"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -c "SET ROLE nfttracker_owner; GRANT USAGE ON SCHEMA nfttracker_endpoints to nfttracker_user;"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -c "SET ROLE nfttracker_owner; GRANT USAGE ON SCHEMA nfttracker_backend to nfttracker_user;"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -c "SET ROLE nfttracker_owner; GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA nfttracker_endpoints TO nfttracker_user;"
