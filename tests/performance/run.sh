#!/bin/bash
# Run k6 performance tests against a Dockerized NFT Tracker stack.
#
# Usage:
#   ./run.sh [smoke|load|stress|soak] [extra k6 args...]
#
# Environment variables:
#   NFT_TRACKER_IMAGE  - nft_tracker app image (default: registry latest)
#   REWRITER_IMAGE     - nginx rewriter image  (default: registry latest)
#   HAF_IMAGE          - HAF/PostgreSQL image   (default: registry 9f8bc727)
#   VUS / MAX_VUS / DURATION - forwarded to k6 tests
#   BUILD_LOCAL=1      - build images from repo instead of pulling

set -euo pipefail
cd "$(dirname "$0")"

SCENARIO="${1:-smoke}"
shift 2>/dev/null || true

SCRIPT="${SCENARIO}.js"
if [ ! -f "$SCRIPT" ]; then
  echo "ERROR: Unknown scenario '${SCENARIO}'. Available: smoke, load, stress, soak" >&2
  exit 1
fi

# Optionally build images from the local repo
if [ "${BUILD_LOCAL:-}" = "1" ]; then
  echo "Building images from local repo..."
  REPO_ROOT="$(cd ../.. && pwd)"
  docker build -t nft-tracker:local -f "$REPO_ROOT/Dockerfile" "$REPO_ROOT"
  docker build -t nft-tracker-rewriter:local -f "$REPO_ROOT/Dockerfile.rewriter" "$REPO_ROOT"
  export NFT_TRACKER_IMAGE=nft-tracker:local
  export REWRITER_IMAGE=nft-tracker-rewriter:local
fi

cleanup() {
  echo "Tearing down services..."
  docker compose down -v --remove-orphans 2>/dev/null || true
}
trap cleanup EXIT

echo "Starting NFT Tracker stack..."
docker compose up -d --wait nft-tracker-rewriter

echo "Running k6 ${SCENARIO} test..."
docker compose run --rm k6 run "$SCRIPT" "$@"
EXIT_CODE=$?

echo "Tests completed with exit code ${EXIT_CODE}."
exit $EXIT_CODE
