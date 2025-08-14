PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)

PGPORT ?= 5432
PGHOST ?= localhost
DB_NAME ?= nft_regression_test
DB_ADMIN ?= haf_admin
export PGPORT
export PGHOST
export DB_NAME
export DB_ADMIN

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
	psql -d postgres -U haf_admin -h localhost -c 'DROP DATABASE IF EXISTS $(DB_NAME)'
	psql -d postgres -U haf_admin -h localhost -c 'CREATE DATABASE $(DB_NAME)'
	psql -d $(DB_NAME) -U haf_admin -h localhost -f ../../db/builtin_roles.sql

.PHONY: test
test: setup_db installcheck

.PHONY: refresh
refresh:
	cp results/*.out expected/

.PHONY: gitadd
gitadd:
	git add expected/*.out
