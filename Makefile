EXTENSION = pg_readme

SUBEXTENSION = pg_readme_test_extension

DISTVERSION = $(shell sed -n -E "/default_version/ s/^.*'(.*)'.*$$/\1/p" $(EXTENSION).control)

DATA = $(wildcard sql/$(EXTENSION)*.sql)

REGRESS = tap_tests

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

README.md: sql/README.sql install
	psql --quiet postgres < $< > $@

META.json: sql/META.sql install
	psql --quiet postgres < $< > $@

install: install_subextension
install_subextension:
	$(MAKE) -C $(SUBEXTENSION) install

dist: META.json README.md
	git archive --format zip --prefix=$(EXTENSION)-$(DISTVERSION)/ -o $(EXTENSION)-$(DISTVERSION).zip HEAD
