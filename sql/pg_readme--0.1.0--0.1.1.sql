-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_readme" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment
    on extension pg_readme
    is $markdown$
# `pg_readme`

The `pg_readme` PostgreSQL extension provides functions to generate
a `README.md` document for a database extension or schema, based on
[`COMMENT`](https://www.postgresql.org/docs/current/sql-comment.html) objects
found in the
[`pg_description`](https://www.postgresql.org/docs/current/catalog-pg-description.html)
system catalog.

## Extension-specific settings

| Setting                                  | Default  |
| ---------------------------------------- | -------- |
| `pg_readme.include_routine_definitions`  | `false`  |
| `pg_readme.include_view_definitions`     | `true`   |

## Missing features

* Support for `<?pg-readme-install?>` PI.
* `pg_schema_readme(regnamespace)` is not actually implemented yet.
* Table synopsis is not generated yet.
* (Composite) type and domain descriptions are not implemented.

<?pg-readme-reference?>

<?pg-readme-colophon?>
$markdown$;

--------------------------------------------------------------------------------------------------------------

alter function pg_extension_readme(pg_catalog.name)
    set search_path from current;

--------------------------------------------------------------------------------------------------------------

alter function pg_schema_readme(pg_catalog.regnamespace)
    set search_path from current;

--------------------------------------------------------------------------------------------------------------

create or replace procedure test__pg_readme()
    set search_path from current
    language plpgsql
    as $plpgsql$
begin
    comment on extension pg_readme is $markdown$
# `my_ext`

Simplified ext. description.

<?pg-readme-reference context-division-depth="1" context-division-is-self="false"?>

<?pg-readme-colophon context-division-depth="1" context-dvision-is-self="false"?>
$markdown$;

    assert pg_extension_readme('pg_readme') = format(
        $markdown$---
pg_extension_name: pg_readme
pg_extension_version: %s
pg_readme_generated_at: %s
pg_readme_version: %s
---

# `my_ext`

Simplified ext. description.

## Object reference

### Routines

#### Function: `readme.pg_extension_readme(name)`

#### Function: `readme.pg_installed_extension_version(name)`

#### Function: `readme.pg_readme_colophon(readme.pg_readme_collection_type,name,smallint,boolean,text)`

#### Function: `readme.pg_readme_object_reference(readme.pg_readme_objects_for_reference,readme.pg_readme_collection_type,name,smallint,boolean,text)`

#### Function: `readme.pg_readme_pi_pseudo_attrs(text,text)`

#### Function: `readme.pg_readme_pis_process(text,readme.pg_readme_collection_type,name,readme.pg_readme_objects_for_reference)`

#### Function: `readme.pg_schema_readme(regnamespace)`

#### Procedure: `readme.test__pg_readme()`

#### Procedure: `readme.test__pg_readme_pi_pseudo_attrs()`

### Types

The following extra types have been defined _besides_ the implicit composite types of the [tables](#tables) and [views](#views) in this extension.

#### Type: `readme.pg_readme_objects_for_reference`

TODO: automatic type synopsis in `pg_readme_object_reference()`.

#### Type: `readme.pg_readme_collection_type`

TODO: automatic type synopsis in `pg_readme_object_reference()`.

## Colophon

This `README.md` for the `pg_readme` `extension` was automatically generated using the
[`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL
extension.$markdown$,
        pg_installed_extension_version('pg_readme'),
        now(),
        pg_installed_extension_version('pg_readme')
    ),
        pg_extension_readme('pg_readme');

    create schema test__pg_readme;
    comment on schema test__pg_readme is $markdown$
This schema is amazing!

<?pg-readme-reference context-division-depth="2"?>
$markdown$;
    create function test__pg_readme.func(int, text, bool[])
        returns bool language sql return true;
    create function test__pg_readme.func(int, text)
        returns bool language sql return true;

    raise transaction_rollback;  -- I could have use any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$plpgsql$;

--------------------------------------------------------------------------------------------------------------
