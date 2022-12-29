# It technically _is_ a dir, but this works well enough to get its name:
EXTENSION = $(strip $(notdir $(CURDIR)))

SUBEXTENSION = pg_readme_test_extension

DISTVERSION = $(shell sed -n -E "/default_version/ s/^.*'(.*)'.*$$/\1/p" pg_readme.control)

DATA = $(wildcard $(EXTENSION)*.sql)

REGRESS = $(EXTENSION)

PG_CONFIG = pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

README.md: README.sql install
	psql --quiet postgres < $< > $@

META.json: META.sql install
	psql --quiet postgres < $< > $@

install: install_subextension
install_subextension:
	$(MAKE) -C $(SUBEXTENSION) install

dist:
	git archive --format zip --prefix=$(EXTENSION)-$(DISTVERSION)/ -o $(EXTENSION)-$(DISTVERSION).zip HEAD
