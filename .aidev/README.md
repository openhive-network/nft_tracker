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
| `ci-config` | every `script`/`before_script`/`after_script` item of `.gitlab-ci.yml` is a string or a nested list of strings (`.aidev/ci_yaml_check.py`; an unquoted `- echo "a: b"` parses as a mapping and GitLab refuses the file). Then the `hive/common-ci-configuration` files it includes, and their own `local:` includes, are fetched from `gitlab.syncad.com/hive/common-ci-configuration/-/raw/<ref>/<file>` without a token, and every `extends` and `!reference [job, …]` target of every job in `.gitlab-ci.yml` and those files must be defined in one of them (e.g. an `extends` of a job in a template file not included); the log names how many files were resolved and each include it does not resolve (`template:`, other projects, remotes, wildcards). An included file that is a definite 404 fails; a fetch with no answer (curl exit, 5xx/429, any other status) passes with a NOTE and leaves the targets unchecked, as in the stackless slots, which have no network. With `GITLAB_TOKEN` set, GitLab's CI lint (dry run on `aidev/integration`) must also report no error but the workflow:rules notice; it also resolves `template:` includes. A lint that gives no answer (connect failure, timeout, TLS error, 5xx/429, any other status without an `errors` body) passes with a NOTE naming the cause |
| `stack-pins` | `.aidev/test-stack.compose.yml` pins `hive/nft_tracker/haf-test:<hex HAF tag>-v2@sha256:<64 hex>`, and that tag and digest are in `registry.gitlab.syncad.com` (queried anonymously; in the stackless slots, which run without a network, only the form is checked) |
| `install` | `scripts/install_app.sh` into the stack's `haf_block_log` (CI's `install_app` step), through `install_with_app_lock.py`; the context `nfttracker_app` and the version row must exist, every function in `nfttracker_endpoints` must be STABLE or IMMUTABLE and `root()` must run as `nfttracker_user` in a READ ONLY transaction (`.aidev/endpoint_volatility_check.sql`), and on a HAF with the application registry the context's only row in `hafd.applications` is `nft_tracker` |
| `regression` | `./regress.sh`, CI's `regression_tests`: pg_regress over every `tests/regression/sql/test_*.sql`, each in a fresh HAF database seeded with mock blocks |
| `reinstall` | `scripts/install_app.sh` again over the installed schema (an upgrade in place), with `nft_tracker` paused in the registry; it must stay paused |
| `uninstall` | `scripts/uninstall_app.sh`; the context and the three schemas must be gone; then `install` again from scratch |
| `registry-old-name` | in a throwaway HAF database, the context registered under the old name `nfttracker_app`: the install must fail with the message naming that row and `hive.app_unregister('nfttracker_app')`, and leave the row unchanged. Skipped on a HAF without the registry |
| `sync` | in a throwaway HAF database seeded with `tests/api_tests/mock_data.sql`, `scripts/process_blocks.sh --stop-at-block=<last mock block>` as `nfttracker_owner` (`haf_app_driver.py --app=nft_tracker --lock=nft_tracker`) must process every block |
| `entry-dropped` | in a throwaway HAF database, with `nfttracker_app.process_blocks(hive.blocks_range)` dropped, `scripts/process_blocks.sh` must be refused the `nft_tracker` lock ("reinstall the application"). Skipped on a HAF before haf#403 |
| `api` | `tests/api_tests` as `run_api_tests.sh` runs them (without its `postgrest.conf` precondition: nothing reads that file). **Not bound to any slot**: CI does not run it, and two of its three files call `get_nft_types`/`get_nft_instances` with parameters the endpoints no longer take (PostgREST `PGRST202`) |

`tests/regression`'s Makefile and pg_regress options name `localhost`, so the steps
that use them forward `localhost:5432` to the stack's HAF with `socat`; `./regress.sh`
itself runs unchanged.

| Slot | Steps | Stack |
|---|---|---|
| quick | shellcheck, sql-registered, ci-config, stack-pins | no |
| coverage | shellcheck, sql-registered | no |
| full, canary | quick's plus install, regression, reinstall, uninstall, registry-old-name, sync, entry-dropped | yes |
| baseline | install, regression | yes |

`static` and `system` are unbound: AIDEV runs neither for a project. Not bound either,
and left to people: `tests/api_tests` (above) and the k6 `tests/performance`.

A new regression test needs its expected output (`tests/regression/expected/*.out`).
pg_regress writes the actual output to `tests/regression/results/`; review it before
copying it over (`make -C tests/regression refresh`): an unchecked `.out` records
whatever bug the change has as the expected value.

## The test stack (`test-stack.compose.yml`)

One service, `haf`: CI's own regression-test image
(`hive/nft_tracker/haf-test:<HAF tag>-v2`, built by CI from `docker/Dockerfile.test`
over the HAF `develop` image its `find_haf_image` job resolves) started with `--skip-hived` and trust access from the stack
network, exactly as the `regression_tests` job starts it. Nothing is replayed.

To run the stack checks by hand:

```bash
docker compose -p nft-checks -f .aidev/test-stack.compose.yml up -d --wait
image="$(grep -o 'registry[^"]*aidev-tests@sha256:[0-9a-f]*' .aidev/project.yaml)"
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/w" -w /w --network nft-checks_default "$image" \
    .aidev/run-checks.sh full shellcheck sql-registered ci-config stack-pins install regression reinstall uninstall
docker compose -p nft-checks -f .aidev/test-stack.compose.yml down -v
```

CI floats with HAF `develop` (`find_haf_image`, common-ci-configuration's
`.find_haf_image`), but a gate must run a digest-pinned image, so the stack pins one
haf-test tag. When HAF `develop` moves past the tag the stack runs, re-pin: take the tag
`find_haf_image` resolves (`HAF_UPSTREAM_TAG` in its log), and if
`hive/nft_tracker/haf-test:<tag>-v2` is not in the registry yet (CI builds it on its
next `regression_tests` run), build and push it as CI does:

```bash
docker build -t registry.gitlab.syncad.com/hive/nft_tracker/haf-test:<tag>-v2 \
    --build-arg HAF_IMAGE=registry.gitlab.syncad.com/hive/haf:<tag> -f docker/Dockerfile.test .
docker push registry.gitlab.syncad.com/hive/nft_tracker/haf-test:<tag>-v2
```

then put the pushed `…:<tag>-v2@sha256:<digest>` into the compose file's `haf` image.
`stack-pins` fails while the pin is malformed or not in the registry.

## The test runtime image (`runtime/`)

The checks run in a container with your uid, built on common-ci-configuration's
`haf-app-test-runner:develop`, which `project.yaml` follows (`environment.base`,
`follow: true`): before each run AIDEV resolves that tag and builds `runtime/Dockerfile`
on it, so `psql`, ShellCheck, `postgrest`, `pytest`, `tavern` and `psycopg2` are ccc's
`docker-bake.hcl` versions and this repository pins none of them. The Dockerfile adds
`postgresql-server-dev` for the base's psql major (HAF's) and `make`, so `pg_regress`
and PGXS run CI's `./regress.sh`, `socat`, and `install_with_app_lock.py` from the psql
image the project `Dockerfile`'s `PSQL_CLIENT_VERSION` names (the application image's
own install path).

`environment.image` is only the seed pin the profile requires: it need not move when
the base or the Dockerfile does. To refresh it:

```bash
.aidev/runtime/build.sh --push   # registry digest if aidev-<input hash> exists, else build + push
# put the printed repo@sha256:<digest> into project.yaml environment.image
```

To build through a pull-through registry cache near the build host, set
`AIDEV_IMAGE_CACHE_BY_REGION` to `region=host:port` pairs, e.g.
`eu=cache.example.org:5001,*=cache2.example.org:5001`: a pair applies when its region is
a label of the host's FQDN, and `*` applies to any other host. Unset, the image is built
straight from `registry.gitlab.syncad.com`.
