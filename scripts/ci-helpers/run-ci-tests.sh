#!/bin/bash
set -euo pipefail

PG_MAJOR=$(pg_config --version | sed 's/PostgreSQL \([0-9]*\).*/\1/')
echo "=== Installing test dependencies (PostgreSQL ${PG_MAJOR}) ==="
sudo apt-get update -qq
# pg_regress requires postgresql-server-dev (PGXS) and make
sudo apt-get install -y -qq "postgresql-server-dev-${PG_MAJOR}" make >/dev/null 2>&1

echo "=== Copying workspace to writable location ==="
mkdir -p /tmp/nft_tracker
tar -cf - -C /home/haf_admin/workspace --exclude=.git . | tar -xf - -C /tmp/nft_tracker
cd /tmp/nft_tracker

echo "=== Running regression tests ==="
if ! ./regress.sh; then
    echo "=== Tests FAILED ==="
    # Print diffs to job log
    cat tests/regression/regression.diffs 2>/dev/null || true
    # Copy diffs to mounted artifacts directory for CI retrieval
    if [ -d /tmp/test-artifacts ]; then
        cp tests/regression/regression.diffs /tmp/test-artifacts/ 2>/dev/null || true
        cp tests/regression/regression.out /tmp/test-artifacts/ 2>/dev/null || true
    fi
    exit 1
fi
