EXTENSION = uuidv7-sql
EXTVERSION = 1.0
PG_CONFIG = pg_config

DATA = $(wildcard sql/*.sql)

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
