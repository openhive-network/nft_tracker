#!/bin/bash
set -euo pipefail

echo "=== Copying workspace to writable location ==="
mkdir -p /tmp/nft_tracker
tar -cf - -C /home/hived/workspace --exclude=.git . | tar -xf - -C /tmp/nft_tracker
cd /tmp/nft_tracker

echo "=== Running regression tests ==="
if ! ./regress.sh; then
    echo "=== Tests FAILED ==="
    # Print diffs to job log
    cat tests/regression/regression.diffs 2>/dev/null || true
    exit 1
fi
echo "=== Tests PASSED ==="
