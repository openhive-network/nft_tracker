#!/bin/bash -e

ORIGINAL_ARGS=("$@")
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

# Re-exec under the HAF install-lock wrapper (shipped in the psql base image)
# unless already running under it. The wrapper holds the exclusive advisory
# install lock on 'nft_tracker' for the lifetime of this script, and skips the
# install (exit 0) when a block processor holds the shared lock. When the
# wrapper isn't available (e.g. running outside the production image in CI),
# run without the lock -- it is a production safety mechanism, not a
# correctness requirement for tests.
if [[ -z "${HAF_INSTALL_LOCK_HELD:-}" ]]; then
  export HAF_INSTALL_LOCK_HELD=1
  if command -v python3 >/dev/null 2>&1 && [[ -f /usr/local/bin/install_with_app_lock.py ]]; then
    exec python3 /usr/local/bin/install_with_app_lock.py nft_tracker "$POSTGRES_ACCESS" "$0" "${ORIGINAL_ARGS[@]}"
  fi
  echo "WARNING: install_with_app_lock.py wrapper not found; running install without HAF advisory lock (expected in CI test setups, not in production install images)." >&2
fi

echo "Installing app..."
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../db/builtin_roles.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../db/schema.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../db/operation_types.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../db/nft_actions.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../db/main_loop.sql"

# #11: record the deployed version so /version can serve it. The image bakes the
# git hash into NFTTRACKER_GIT_HASH (see Dockerfile). Local installs without it
# fall back to 'unspecified'.
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -c "SET ROLE nfttracker_owner; SELECT nfttracker_app.set_version('${NFTTRACKER_GIT_HASH:-unspecified}');"

echo "Installing API endpoints..."
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on -c "SET custom.swagger_url = '$SWAGGER_URL';" -f "$SCRIPTPATH/../endpoints/endpoint_schema.sql"

psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/types/nft_type.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/types/nft_instance.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/types/nft_instance_with_type.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/types/trx_result.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/backend/get_nft_instances.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/backend/get_nft_instances_by_trx.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/backend/get_trx_results.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/backend/get_sync_status.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/get_version.sql"
psql "$POSTGRES_ACCESS" -v ON_ERROR_STOP=on  -f "$SCRIPTPATH/../endpoints/get_sync_status.sql"
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
