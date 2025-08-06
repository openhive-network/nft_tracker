.PHONY: all
all: test

.PHONY: test
test:
	psql -d postgres -U haf_admin -H localhost -f ../../db/builtin_roles.sql
	VERBOSE=$(VERBOSE) KEEP_DB=$(KEEP_DB) /usr/lib/postgresql/17/lib/pgxs/src/test/regress/pg_regress \
	--host=localhost \
	--user=haf_admin \
	--launcher=./launcher.sh \
	$(if $(TESTS),$(TESTS),`find sql/test_*.sql -print0 | xargs -0 -I{} basename {} .sql | paste -s -d ' '`)

.PHONY: refresh
refresh:
	cp results/*.out expected/

.PHONY: gitadd
gitadd:
	git add expected/
