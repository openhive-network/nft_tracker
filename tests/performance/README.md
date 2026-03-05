# NFT Tracker API Performance Tests

Performance test suite using [k6](https://k6.io/) for the NFT Tracker REST API.

## Prerequisites

Install k6: https://grafana.com/docs/k6/latest/set-up/install-k6/

```bash
# Ubuntu/Debian
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg \
  --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D68
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" \
  | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update && sudo apt-get install k6

# macOS
brew install k6

# Docker
docker run --rm -i grafana/k6 run - <script.js
```

## Test Scenarios

| Script | Purpose | Default VUs | Duration |
|--------|---------|-------------|----------|
| `smoke.js` | Verify all endpoints respond correctly | 1 | 1 iteration |
| `load.js` | Sustained normal traffic | 10 | 2 min |
| `stress.js` | Find breaking points under high load | 50 (peak) | ~4 min |
| `soak.js` | Detect degradation over time | 5 | 15 min |

## Docker (full stack)

The included `docker-compose.yml` and `run.sh` start the entire NFT Tracker stack
(HAF, app install, PostgREST, nginx rewriter) and run k6 against it. Only Docker
and Docker Compose are required - no local k6 install needed.

```bash
cd tests/performance

# Smoke test (pull pre-built images from registry)
./run.sh smoke

# Load test with custom parameters
VUS=20 DURATION=5m ./run.sh load

# Stress test
MAX_VUS=100 ./run.sh stress

# Build images from the local repo instead of pulling
BUILD_LOCAL=1 ./run.sh load

# Pass extra k6 flags after the scenario name
./run.sh load --out json=/tests/results.json
```

The script tears down all containers automatically on exit.

### Image overrides

| Variable | Default |
|----------|---------|
| `NFT_TRACKER_IMAGE` | `registry.gitlab.syncad.com/hive/nft_tracker:latest` |
| `REWRITER_IMAGE` | `registry.gitlab.syncad.com/hive/nft_tracker/postgrest-rewriter:latest` |
| `HAF_IMAGE` | `registry.gitlab.syncad.com/hive/haf:9f8bc727` |

To test CI-built images, set the image variables to the commit-SHA-tagged images:

```bash
NFT_TRACKER_IMAGE=registry.gitlab.syncad.com/hive/nft_tracker:abc1234 \
REWRITER_IMAGE=registry.gitlab.syncad.com/hive/nft_tracker/postgrest-rewriter:abc1234 \
./run.sh load
```

## Direct k6 usage (against an existing instance)

If you already have a running NFT Tracker API, install k6 locally and point it
at the target URL.

```bash
# Run against local instance (default: http://localhost:8080/nft-tracker-api)
k6 run tests/performance/smoke.js

# Custom target URL
k6 run -e BASE_URL=https://api.example.com/nft-tracker-api tests/performance/load.js

# Adjust concurrency and duration
k6 run -e VUS=20 -e DURATION=5m tests/performance/load.js
k6 run -e MAX_VUS=100 tests/performance/stress.js

# With real data (comma-separated creators/symbols matching your database)
k6 run -e CREATORS=alice,bob -e SYMBOLS=CARD,ART -e TRX_IDS=abc123 tests/performance/load.js

# JSON output for CI integration
k6 run --out json=results.json tests/performance/load.js
```

## Configuration

All tests accept environment variables via `-e KEY=VALUE`:

| Variable | Description | Default |
|----------|-------------|---------|
| `BASE_URL` | API base URL | `http://localhost:8080/nft-tracker-api` |
| `VUS` | Virtual users (load/soak) | 10 / 5 |
| `MAX_VUS` | Peak virtual users (stress) | 50 |
| `DURATION` | Test duration (load/soak) | 2m / 15m |
| `CREATORS` | Comma-separated creator accounts | `alice,bob,charlie` |
| `SYMBOLS` | Comma-separated NFT symbols | `CARD,ART,BADGE` |
| `TAGS` | Pipe-separated tag patterns | `item,collectible\|rare` |
| `TRX_IDS` | Comma-separated transaction IDs | `abc123def456,789012345678` |

## Default Thresholds

- **p(95) < 500ms** response time
- **p(99) < 1000ms** response time
- **< 1%** error rate (load), **< 5%** (stress)

## Endpoints Tested

- `GET /` - OpenAPI specification
- `GET /version` - API version
- `GET /nfts` - List NFT types (with pagination)
- `GET /nfts/{creator}/{symbol}` - List instances (with holder filter)
- `GET /nfts/{creator}/{symbol}/{tags}` - Filter instances by tags
- `GET /nfts/by-trx/{trx_id}` - Instances by transaction ID
