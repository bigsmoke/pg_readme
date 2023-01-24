-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_readme" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- Fix PI formatting.
-- Fix inline code by replacing faulty trailing single quote with backtick.
comment on function pg_extension_readme(name) is
$md$`pg_extension_readme()` automatically generates a `README.md` for the given extension, taking the `COMMENT ON EXTENSION` as the prelude, and optionally adding a full reference (with neatly layed out object characteristics from the `pg_catalog`) in the place where a <code>&lt;?pg-readme-reference?&gt;</code> processing instruction is encountered in the `COMMENT ON EXTENSION`.

See the [_Processing instructions_](#processing-instructions) section for
details about the processing instructions that are recognized and which
pseudo-attributes they support.
$md$;

--------------------------------------------------------------------------------------------------------------

-- Fix PI formatting.
comment on function pg_readme_colophon(pg_readme_collection_type, name, smallint, bool, text) is
$md$`pg_readme_colophon()` is a function internal to `pg_readme` that is used by `pg_readme_pis_process()` to replace <code>&lt;?pg-readme-colophon?&gt;</code> processing instructions with a standard colophon indicating that `pg_readme` was used to generate a schema or extension README.

See the [_Processing instructions_](#processing-instructions) section for an
overview of the processing instructions and their pseudo-attributes.
$md$;

--------------------------------------------------------------------------------------------------------------

-- Fix PI formatting.
comment on function pg_readme_object_reference is
$md$`pg_readme_object_reference()` is a function internal to `pg_readme` that is delegated to by `pg_readme_pis_process()` to replace <code>&lt;?pg-readme-reference?&gt;</code> processing instructions with a standard colophon indicating that `pg_readme` was used to generate a schema or extension README.

See the [_Processing instructions_](#processing-instructions) section for an
overview of the processing instructions and their pseudo-attributes.
$md$;

--------------------------------------------------------------------------------------------------------------

-- Fix PI formatting.
-- Fix inline code by replacing faulty trailing single quote with backtick.
comment on function pg_schema_readme(regnamespace) is
$md$`pg_schema_readme()` automatically generates a `README.md` for the given schema, taking the `COMMENT ON SCHEMA` as the prelude, and optionally adding a full reference (with neatly layed out object characteristics from the `pg_catalog`) in the place where a <code>&lt;?pg-readme-reference?&gt;</code> processing instruction is encountered in the `COMMENT ON SCHEMA`.

See the [_Processing instructions_](#processing-instructions) section for
details about the processing instructions that are recognized and which
pseudo-attributes they support.
$md$;

--------------------------------------------------------------------------------------------------------------
