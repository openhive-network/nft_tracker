#!/bin/bash
#
# Setup HAF database for testing
# Based on haf/scripts/setup_db.sh but simplified for nft_tracker tests
#
# This script creates a fresh HAF database with the hive_fork_manager extension.
# The unix user account executing this script must be associated to the DB_ADMIN role.
#

set -euo pipefail

print_help () {
    echo "Usage: $0 [OPTION[=VALUE]]..."
    echo
    echo "Create and setup a database to be filled with HAF data. Drops any already existing HAF database!!!"
    echo "OPTIONS:"
    echo "  --host=VALUE                    Specify a PostgreSQL host location (defaults to /var/run/postgresql)."
    echo "  --port=NUMBER                   Specify a PostgreSQL operating port (defaults to 5432)."
    echo "  --haf-db-name=NAME              Specify the HAF database name to use."
    echo "  --haf-app-user=NAME             Specify name of a database role to act as an APP user of the HAF database."
    echo "                                  Specify multiple times to add multiple roles."
    echo "                                  The role MUST already exist on the Postgres cluster!!!"
    echo "  --haf-db-admin=NAME             Specify name of a database admin role with permission to create the database and install the HAF extension."
    echo "                                  The role MUST already exist on the Postgres cluster!!!"
    echo "                                  If omitted, defaults to haf_admin role."
    echo "  --no-create-schema              Skips the final steps of creating the schema, extension and database roles."
    echo "  --version                       Specify the hive fork manager version to use."
    echo "  --help                          Display this help screen and exit."
    echo
}

DB_NAME="haf_block_log"
DB_ADMIN="haf_admin"
HAF_TABLESPACE_NAME="haf_tablespace"

DEFAULT_DB_USERS=()
DB_USERS=()
POSTGRES_HOST="/var/run/postgresql"
POSTGRES_PORT=5432
NO_CREATE_SCHEMA=false
VERSION=

while [ $# -gt 0 ]; do
  case "$1" in
    --host=*)
        POSTGRES_HOST="${1#*=}"
        ;;
    --port=*)
        POSTGRES_PORT="${1#*=}"
        ;;
    --haf-db-name=*)
        DB_NAME="${1#*=}"
        ;;
    --haf-app-user=*)
        USER="${1#*=}"
        DB_USERS+=($USER)
        DEFAULT_DB_USERS=() # clear all default users.
        ;;
    --haf-db-admin=*)
        DB_ADMIN="${1#*=}"
        ;;
    --help)
        print_help
        exit 0
        ;;
    --no-create-schema)
        NO_CREATE_SCHEMA=true
        ;;
    --version=*)
        VERSION="${1#*=}"
        if [ "$VERSION" != "${VERSION//[^a-zA-Z0-9]/}" ]; then
            echo "Invalid version $VERSION"
            exit 3
        fi
        VERSION="VERSION '${VERSION}'"
        ;;
    -*)
        echo "ERROR: '$1' is not a valid option."
        echo
        print_help
        exit 1
        ;;
    *)
        echo "ERROR: '$1' is not a valid argument."
        echo
        print_help
        exit 2
        ;;
    esac
    shift
done

POSTGRES_ACCESS="--host $POSTGRES_HOST --port $POSTGRES_PORT"

DB_USERS+=("${DEFAULT_DB_USERS[@]}")

# Create database
psql -aw $POSTGRES_ACCESS -d postgres -v ON_ERROR_STOP=on -U "$DB_ADMIN" -f - << EOF
  DROP DATABASE IF EXISTS "$DB_NAME";
  CREATE DATABASE "$DB_NAME" WITH OWNER $DB_ADMIN TABLESPACE ${HAF_TABLESPACE_NAME} encoding UTF8 LC_COLLATE 'C' LC_CTYPE 'C' TEMPLATE template0;
EOF


if [ ${NO_CREATE_SCHEMA} = true ]; then
    exit 0
fi


# Install HAF extension
psql -aw $POSTGRES_ACCESS -d "$DB_NAME" -v ON_ERROR_STOP=on -U "$DB_ADMIN" -c "CREATE EXTENSION hive_fork_manager $VERSION CASCADE;"

psql -aw $POSTGRES_ACCESS -d postgres -v ON_ERROR_STOP=on -U "$DB_ADMIN" -f - << EOF
  GRANT CREATE ON DATABASE "$DB_NAME" to hive_applications_owner_group;
EOF

for u in "${DB_USERS[@]}"; do
  psql -aw $POSTGRES_ACCESS -d postgres -v ON_ERROR_STOP=on -U "$DB_ADMIN" -f - << EOF
    GRANT CREATE ON DATABASE "$DB_NAME" TO $u;
EOF

done
