# NFT Tracker - Claude Code Project Memory

## Project Overview

NFT Tracker is a blockchain-based NFT (Non-Fungible Token) management and tracking system for the Hive blockchain. It provides:

- **NFT Type Registration**: Register custom NFT types with symbols (format: `namespace/name`) and metadata
- **NFT Instance Management**: Track individual NFT instances with ownership, tags, and soulbinding capabilities
- **REST API**: OpenAPI-documented endpoints via PostgREST
- **Block Processing**: Sync NFT operations from Hive blockchain custom_json operations

**Supported Operations:** `register`, `modify`, `issue`, `soulbind`, `set_data`, `transfer`

## Tech Stack

| Component | Technology |
|-----------|------------|
| Database | PostgreSQL 14+ (via HAF - Hive Application Framework) |
| API | PostgREST (auto-generates REST from PostgreSQL) |
| Gateway | Nginx/OpenResty (URL rewriting, proxying) |
| Framework | HAF database extension (no submodule, uses common-ci-configuration) |
| Testing | pg_regress (SQL), Tavern (API tests) |
| CI/CD | GitLab CI with Docker Buildx |

**No Python backend** - pure PostgreSQL + PostgREST approach.

## Directory Structure

```
nft_tracker/
├── db/                          # Database schema and logic
│   ├── schema.sql               # Tables: types, instances, authorized_issuers
│   ├── nft_actions.sql          # Core NFT operation handlers
│   ├── main_loop.sql            # Block processing orchestration
│   └── builtin_roles.sql        # PostgreSQL roles
├── endpoints/                   # REST API endpoints
│   ├── endpoint_schema.sql      # OpenAPI spec and root endpoint
│   ├── types/                   # Composite type definitions
│   ├── backend/                 # Backend query functions
│   ├── get_version.sql
│   ├── get_nft_types.sql
│   └── get_nft_instances*.sql
├── scripts/                     # Application scripts
│   ├── install_app.sh           # Install to PostgreSQL
│   ├── uninstall_app.sh         # Remove from PostgreSQL
│   ├── process_blocks.sh        # Main block processor
│   ├── start_postgrest.sh       # Start API server
│   ├── setup_db.sh              # HAF database setup (for tests)
│   └── ci-helpers/              # CI build scripts
├── docker/                      # Docker configs
│   └── scripts/                 # Entrypoint, healthcheck
├── tests/
│   ├── regression/              # SQL regression tests (17 tests)
│   │   ├── sql/                 # Test SQL files
│   │   ├── expected/            # Expected outputs
│   │   └── launcher.sh          # Test runner
│   ├── api_tests/               # Tavern REST API tests
│   ├── prelude.sql              # Test helper functions
│   └── setup.sql                # Test setup
├── Dockerfile                   # Main app container
├── Dockerfile.rewriter          # Nginx gateway container
├── docker-bake.hcl              # Docker Buildx config
└── .gitlab-ci.yml               # CI/CD pipeline
```

## Development Commands

### Installation & Setup

```bash
# Install app into PostgreSQL (requires running HAF database)
./scripts/install_app.sh \
  --postgres-host=localhost \
  --postgres-port=5432 \
  --postgres-user=haf_admin \
  --swagger-url=localhost

# Uninstall app
./scripts/uninstall_app.sh --host=localhost --user=haf_admin

# Start processing blockchain blocks
./scripts/process_blocks.sh \
  --host=localhost \
  --port=5432 \
  --stop-at-block=NUM  # optional

# Start PostgREST API server
./scripts/start_postgrest.sh \
  --host=localhost \
  --webserver-port=8080 \
  --admin-port=3001
```

### Testing

```bash
# Run all regression tests
./regress.sh

# Run specific tests
./regress.sh test_register test_issue test_modify

# Verbose output
./regress.sh -v

# Keep database after tests
./regress.sh -k

# Run API tests (Tavern)
cd tests/api_tests && ./run_api_tests.sh

# Update test baselines after changes
cd tests/regression && make refresh && make gitadd
```

### Docker Build

```bash
# Build all images with docker-bake
docker buildx bake -f docker-bake.hcl

# Build main app image
docker build -t nft_tracker:latest .

# Build rewriter (Nginx) image
docker build -t nft_tracker-rewriter:latest -f Dockerfile.rewriter .
```

## Important Files

### Entry Points
- `docker/scripts/docker-entrypoint.sh` - Container entrypoint (dispatches to install/process/uninstall)
- `db/main_loop.sql` - `main()` procedure for block processing

### Core Logic
- `db/schema.sql` - Schema `nfttracker_app` with tables and domains
- `db/nft_actions.sql` - All NFT operation handlers (`register()`, `issue()`, `transfer()`, etc.)

### API
- `endpoints/endpoint_schema.sql` - OpenAPI 3.1.0 spec (embedded in SQL comments)
- `rewrite_rules.conf` - Nginx URL rewrites (REST paths to PostgREST RPC)

### Configuration
- `docker/nft_tracker_nginx.conf.template` - Nginx config template
- `.gitlab-ci.yml` - CI/CD pipeline definition

## Database Roles

| Role | Purpose |
|------|---------|
| `nfttracker_owner` | Full schema control |
| `nfttracker_user` | Read-only API access |

## API Endpoints

Base path: `/nft-tracker-api/`

| Endpoint | Description |
|----------|-------------|
| `GET /` | OpenAPI specification |
| `GET /version` | API version |
| `GET /nfts` | List NFT types |
| `GET /nfts/{creator}/{symbol}` | List instances for type |
| `GET /nfts/{creator}/{symbol}/{tags}` | Filter instances by tags |

**Pagination:** `p_count` (max 1000), `p_last_id` parameters

## CI/CD Notes

**Pipeline Stages:**
1. **build** - Build Docker images, tag with commit SHA
2. **publish** - Push to registries on version tags

**Registries:**
- `registry.gitlab.syncad.com/hive/nft_tracker`
- `registry-upload.hive.blog/nft_tracker`

**Branch Tags:**
- `develop` branch: tagged as `develop`
- Version tags (`v*`): tagged as version + `latest`

**Environment Variables (Container):**
```
POSTGRES_HOST     # default: haf
POSTGRES_PORT     # default: 5432
POSTGRES_USER     # default: haf_admin
NFTTRACKER_SCHEMA # default: nfttracker_app
SWAGGER_URL       # default: localhost
```

## Key Patterns

- **OpenAPI from SQL**: Spec embedded in SQL comments, processed by `process_openapi.py` (fetched from common-ci-configuration)
- **Symbol Format**: `namespace/name` (e.g., `alice/CARD`)
- **Custom Types**: `nft_type`, `nft_instance` composite types for API responses
- **Authorization**: Symbol creator manages authorized issuers; instances have single holder
- **Soulbinding**: NFTs can be made permanently non-transferable

## Test Structure

**Regression Tests** (`tests/regression/sql/`):
- `test_register.sql` - Type registration
- `test_issue.sql` - Instance issuance
- `test_modify.sql` - Type modification
- `test_transfer.sql` - Ownership transfer
- `test_soulbind.sql` - Soulbinding
- And 12 more covering edge cases and error conditions

**API Tests** (`tests/api_tests/`):
- Pagination tests for types and instances
- Uses Tavern YAML format
