.PHONY: all
all: test

.PHONY: test
test:
	psql -d postgres -U haf_admin -H localhost -f ../../db/builtin_roles.sql
	/usr/lib/postgresql/17/lib/pgxs/src/test/regress/pg_regress \
	--host=localhost \
	--user=haf_admin \
	--launcher=./launcher.sh \
	`find sql/test_*.sql -print0 | xargs -0 -I{} basename {} .sql | paste -s -d ' '`

.PHONY: refresh
refresh:
	cp results/*.out expected/
