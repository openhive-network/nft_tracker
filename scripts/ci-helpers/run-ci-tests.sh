#!/bin/bash
set -euo pipefail

PG_MAJOR=$(pg_config --version | sed 's/PostgreSQL \([0-9]*\).*/\1/')
echo "=== Installing test dependencies (PostgreSQL ${PG_MAJOR}) ==="
sudo apt-get update -qq
# pg_regress requires postgresql-server-dev (PGXS) and make
sudo apt-get install -y -qq "postgresql-server-dev-${PG_MAJOR}" make >/dev/null

echo "=== Copying workspace to writable location ==="
mkdir -p /tmp/nft_tracker
tar -cf - -C /home/haf_admin/workspace --exclude=.git . | tar -xf - -C /tmp/nft_tracker
cd /tmp/nft_tracker

echo "=== Running regression tests ==="
if ! ./regress.sh; then
    echo "=== Tests FAILED ==="
    # Print diffs to job log
    cat tests/regression/regression.diffs 2>/dev/null || true
    exit 1
fi
echo "=== Tests PASSED ==="
