#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"

SETUP_DB_SCRIPT="$PROJECT_ROOT/scripts/setup_db.sh"
INSTALL_APP_SCRIPT="$PROJECT_ROOT/scripts/install_app.sh"
START_POSTGREST_SCRIPT="$PROJECT_ROOT/scripts/start_postgrest.sh"
POSTGREST_CONF="$PROJECT_ROOT/postgrest.conf"

PGHOST="${PGHOST:-localhost}"
PGPORT="${PGPORT:-5432}"
DB_NAME="${DB_NAME:-nft_api_test}"
DB_ADMIN="${DB_ADMIN:-haf_admin}"
POSTGREST_PORT="${POSTGREST_PORT:-8080}"

if [ ! -x "$SETUP_DB_SCRIPT" ]; then
  echo "Error: HAF setup script not found or not executable: $SETUP_DB_SCRIPT" >&2
  exit 1
fi

if [ ! -x "$INSTALL_APP_SCRIPT" ]; then
  echo "Error: NFT tracker install script not found or not executable: $INSTALL_APP_SCRIPT" >&2
  exit 1
fi

if [ ! -x "$START_POSTGREST_SCRIPT" ]; then
  echo "Error: PostgREST start script not found or not executable: $START_POSTGREST_SCRIPT" >&2
  exit 1
fi

if [ ! -f "$POSTGREST_CONF" ]; then
  echo "Error: postgrest.conf not found at: $POSTGREST_CONF" >&2
  exit 1
fi

_psql() {
  psql -w -v ON_ERROR_STOP=1 -h "$PGHOST" -U "$DB_ADMIN" -d "$DB_NAME" "$@"
}

wait_for_postgrest() {
  local max_retries="${1:-30}"
  local sleep_seconds="${2:-1}"

  echo "[api_tests] Waiting for PostgREST to become ready on http://localhost:$POSTGREST_PORT..."

  for i in $(seq 1 "$max_retries"); do
    if curl -fsS "http://localhost:$POSTGREST_PORT/" >/dev/null 2>&1; then
      echo "[api_tests] PostgREST is up (attempt $i/$max_retries)."
      return 0
    fi
    if [ "$i" -eq "$max_retries" ]; then
      echo "[api_tests] ERROR: PostgREST did not become ready after $max_retries attempts" >&2
      exit 1
    fi
    sleep "$sleep_seconds"
  done
}

echo "[api_tests] Setting up fresh HAF database '$DB_NAME' on $PGHOST:$PGPORT..."
"$SETUP_DB_SCRIPT" \
  --haf-db-name="$DB_NAME" \
  --haf-db-admin="$DB_ADMIN" \
  --host="$PGHOST" \
  --port="$PGPORT"

echo "[api_tests] Installing NFT tracker schema and endpoints..."
DB_URL="postgresql://$DB_ADMIN@$PGHOST:$PGPORT/$DB_NAME"
POSTGRES_URL="$DB_URL" SWAGGER_URL="localhost:$POSTGREST_PORT" "$INSTALL_APP_SCRIPT" --postgres-url="$DB_URL"

echo "[api_tests] Loading test helpers and seed data..."
_psql -f "$PROJECT_ROOT/tests/setup.sql"
_psql -f "$PROJECT_ROOT/tests/prelude.sql"
_psql -f "$PROJECT_ROOT/tests/api_tests/mock_data.sql"
_psql -c "CALL nfttracker_sync_blocks();"

echo "[api_tests] Starting PostgREST on port $POSTGREST_PORT using DB '$DB_NAME'..."
DB_URL="postgresql://$DB_ADMIN@$PGHOST:$PGPORT/$DB_NAME"
LOG_FILE="$PROJECT_ROOT/tests/api_tests/postgrest_api_tests.log"
PID_FILE="$PROJECT_ROOT/tests/api_tests/postgrest_api_tests.pid"

cleanup_postgrest() {
  if [ -n "${POSTGREST_PID-}" ] && kill -0 "$POSTGREST_PID" 2>/dev/null; then
    echo "[api_tests] Stopping PostgREST with PID $POSTGREST_PID"
    kill "$POSTGREST_PID" 2>/dev/null || true
  fi
}

trap cleanup_postgrest EXIT

"$START_POSTGREST_SCRIPT" --postgres-url="$DB_URL" --webserver-port="$POSTGREST_PORT" >"$LOG_FILE" 2>&1 &
POSTGREST_PID=$!

echo "$POSTGREST_PID" >"$PID_FILE"

echo "[api_tests] PostgREST started with PID $POSTGREST_PID"
echo "[api_tests] Logs: $LOG_FILE"
echo "[api_tests] PID file: $PID_FILE"

MAX_RETRIES=30
SLEEP_SECONDS=1

wait_for_postgrest "$MAX_RETRIES" "$SLEEP_SECONDS"

echo "[api_tests] Running Tavern API tests..."
cd "$SCRIPT_DIR"
if [ "$#" -gt 0 ]; then
  pytest -vv "$@"
else
  pytest -vv ./*.tavern.yaml
fi
