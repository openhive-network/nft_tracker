# NFT tracker under AIDEV

AIDEV verifies changes to this repository through the slots in `project.yaml`,
integrates them into `aidev/integration`, and hands that off to `develop` by merge
request (`branches.handoff`), gated by this project's GitLab CI. Merge those merge
requests **keeping the source branch**: `aidev/integration` is protected, and AIDEV's
running work is based on it. GitLab CI doesn't run for AIDEV branches (`ai/*`,
`session/*`, pushes to `aidev/integration`); see `.gitlab-ci.yml` `workflow:`. A
pipeline started from the web UI or the API still runs on `aidev/integration`.

## Suites

`.aidev/run-checks.sh <suite> <step>...` runs the named steps and writes
`test-results/<suite>/junit.xml`, one test case per step, with the step's log tail as
the failure body. `regression` also writes one case per pg_regress test
(`regression.xml`), `api` one per tavern test (`api.xml`).

| Step | What |
|---|---|
| `shellcheck` | ShellCheck at error severity on every `*.sh` outside `.aidev/` (CI runs no linter; `scripts/` carries warnings today), and at its default severity on `.aidev/`'s own scripts |
| `sql-registered` | every `.sql` file under `db/` and `endpoints/` is applied by `scripts/install_app.sh` |
| `stack-pins` | `.aidev/test-stack.compose.yml` and `.aidev/runtime/Dockerfile` pin `hive/nft_tracker/haf-test:<HAF_VERSION>-v2@sha256:…` for `.gitlab-ci.yml`'s `HAF_VERSION` (reads only the tree) |
| `install` | `scripts/install_app.sh` into the stack's `haf_block_log` (CI's `install_app` step), through `install_with_app_lock.py`; the context `nfttracker_app` and the version row must exist |
| `regression` | `./regress.sh`, CI's `regression_tests`: pg_regress over every `tests/regression/sql/test_*.sql`, each in a fresh HAF database seeded with mock blocks |
| `reinstall` | `scripts/install_app.sh` again over the installed schema (an upgrade in place) |
| `uninstall` | `scripts/uninstall_app.sh`; the context and the three schemas must be gone; then `install` again from scratch |
| `api` | `tests/api_tests` as `run_api_tests.sh` runs them (without its `postgrest.conf` precondition: nothing reads that file). **Not bound to any slot**: CI does not run it, and two of its three files call `get_nft_types`/`get_nft_instances` with parameters the endpoints no longer take (PostgREST `PGRST202`) |

`tests/regression`'s Makefile and pg_regress options name `localhost`, so the steps
that use them forward `localhost:5432` to the stack's HAF with `socat`; `./regress.sh`
itself runs unchanged.

| Slot | Steps | Stack |
|---|---|---|
| quick | shellcheck, sql-registered, stack-pins | no |
| coverage | shellcheck, sql-registered | no |
| full, canary | quick's plus install, regression, reinstall, uninstall | yes |
| baseline | install, regression | yes |

`static` and `system` are unbound: AIDEV runs neither for a project. Not bound either,
and left to people: `tests/api_tests` (above) and the k6 `tests/performance`.

A new regression test needs its expected output (`tests/regression/expected/*.out`).
pg_regress writes the actual output to `tests/regression/results/`; review it before
copying it over (`make -C tests/regression refresh`): an unchecked `.out` records
whatever bug the change has as the expected value.

## The test stack (`test-stack.compose.yml`)

One service, `haf`: CI's own regression-test image
(`hive/nft_tracker/haf-test:<HAF_VERSION>-v2`, built by CI from `docker/Dockerfile.test`
over HAF at `HAF_VERSION`) started with `--skip-hived` and trust access from the stack
network, exactly as the `regression_tests` job starts it. Nothing is replayed.

To run the stack checks by hand:

```bash
docker compose -p nft-checks -f .aidev/test-stack.compose.yml up -d --wait
image="$(grep -o 'registry[^"]*aidev-tests@sha256:[0-9a-f]*' .aidev/project.yaml)"
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/w" -w /w --network nft-checks_default "$image" \
    .aidev/run-checks.sh full shellcheck sql-registered stack-pins install regression reinstall uninstall
docker compose -p nft-checks -f .aidev/test-stack.compose.yml down -v
```

When `.gitlab-ci.yml`'s `HAF_VERSION` moves, CI builds the new haf-test tag on its next
`regression_tests` run; then re-pin the compose file's `haf` image and the runtime
Dockerfile's `FROM` to that tag's digest, rebuild the runtime image (below) and put it
into `environment.image`, all in one commit. `stack-pins` fails until both pins match.

## The test runtime image (`runtime/`)

The checks run in a container with your uid: CI's haf-test image (so `psql`,
`pg_regress` and PGXS are exactly what CI's `./regress.sh` uses), plus `socat`,
`python3-psycopg2`, `curl`, `install_with_app_lock.py` from the psql image the project
`Dockerfile`'s `PSQL_CLIENT_VERSION` names, ShellCheck 0.11.0, the `postgrest` binary of
common-ci-configuration (v12.0.2), and `tavern`/`pytest` in `/opt/venv`; all bases
pinned by digest, nothing installed at run time. `/usr/lib/postgresql/17/bin` comes
first on `PATH`: the image's `/usr/bin/psql` is HAF's wrapper, which wants a local data
directory.

When `runtime/Dockerfile` changes, rebuild and re-pin **in the same commit**:

```bash
.aidev/runtime/build.sh --push   # registry digest if aidev-<input hash> exists, else build + push
# put the printed repo@sha256:<digest> into project.yaml environment.image
```

To build through a pull-through registry cache near the build host, set
`AIDEV_IMAGE_CACHE_BY_REGION` to `region=host:port` pairs, e.g.
`eu=cache.example.org:5001,*=cache2.example.org:5001`: a pair applies when its region is
a label of the host's FQDN, and `*` applies to any other host. Unset, the image is built
straight from `registry.gitlab.syncad.com`.
