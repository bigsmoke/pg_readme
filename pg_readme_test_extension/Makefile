# It technically _is_ a dir, but this works well enough to get its name:
EXTENSION =$(strip $(notdir $(CURDIR)))

DATA = $(wildcard $(EXTENSION)*.sql)

REGRESS = $(EXTENSION)

PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

README.md: README.sql install
	psql --quiet postgres < $< > $@
