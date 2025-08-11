PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
REGRESS=$(if $(TESTS),$(TESTS),`find sql/test_*.sql -print0 | xargs -0 -I{} basename {} .sql | paste -s -d ' '`)
REGRESS_OPTS= \
	--host=localhost \
	--user=haf_admin \
	--launcher=./launcher.sh \

include $(PGXS)

.PHONY: all
all: test

.PHONY: setup_db
setup_db:
	psql -d postgres -U haf_admin -h localhost -f ../../db/builtin_roles.sql

.PHONY: test
test: setup_db installcheck

.PHONY: refresh
refresh:
	cp results/*.out expected/

.PHONY: gitadd
gitadd:
	git add expected/*.out
