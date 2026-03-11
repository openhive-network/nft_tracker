#! /bin/bash
set -e
set -o pipefail
# Script reponsible for execution of all actions required to finish configuration of the database holding a HAF database to work correctly with hivemind.

print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Allows to start a data collection for nfereputation_tracker application."
    echo "OPTIONS:"
    echo "  --host=VALUE         Allows to specify a PostgreSQL host location (defaults to /var/run/postgresql)"
    echo "  --port=NUMBER        Allows to specify a PostgreSQL operating port (defaults to 5432)"
    echo "  --postgres-url=URL   Allows to specify a PostgreSQL URL (in opposite to separate --host and --port options)"
    echo "  --stop-at-block=num  Allows to stop processing (sync) at given block"
    echo "  --help               Display this help screen and exit"
    echo
}

POSTGRES_USER=${POSTGRES_USER:-"nfttracker_owner"}
POSTGRES_HOST=${POSTGRES_HOST:-"localhost"}
POSTGRES_PORT=${POSTGRES_PORT:-5432}
POSTGRES_URL=${POSTGRES_URL:-""}
PROCESS_BLOCK_LIMIT=${PROCESS_BLOCK_LIMIT:-null}
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
    --stop-at-block=*)
        PROCESS_BLOCK_LIMIT="${1#*=}"
        ;;
    --schema=*)
        NFTTRACKER_SCHEMA="${1#*=}"
        ;;
    --help)
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

POSTGRES_ACCESS=${POSTGRES_URL:-"postgresql://$POSTGRES_USER@$POSTGRES_HOST:$POSTGRES_PORT/haf_block_log"}

process_blocks() {
    local n_blocks="${1:-null}"
    log_file="nfttracker_sync.log"
    date -u +"%Y-%m-%dT%H:%M:%S+00:00" > /tmp/block_processing_startup_time.txt
    exec run_with_reconnect.sh -- psql "$POSTGRES_ACCESS" -v "ON_ERROR_STOP=on" -v NFTTRACKER_SCHEMA="${NFTTRACKER_SCHEMA}" -c "\timing" -c "CALL ${NFTTRACKER_SCHEMA}.main('${NFTTRACKER_SCHEMA}', $n_blocks);"
}

process_blocks "$PROCESS_BLOCK_LIMIT"
