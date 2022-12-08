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

## Usage

To use `pg_readme` in your extension, the most self-documenting way to do it is
to create a function that calls the `readme.pg_extension_readme(name)`
function.  Here is an example from
[`pg_rowalesce`](https://github.com/bigsmoke/pg_rowalesce):

```sql
create function pg_rowalesce_readme()
    returns text
    volatile
    set search_path from current
    set pg_readme.include_view_definitions to 'true'
    set pg_readme.include_routine_definitions to 'false'
    language plpgsql
    as $plpgsql$
declare
    _readme text;
begin
    create extension if not exists pg_readme
        with version '0.1.0';
    _readme := pg_extension_readme('pg_rowalesce'::name);
    raise transaction_rollback;  -- to drop extension if we happened to `CREATE EXTENSION` for just this.
exception
    when transaction_rollback then
        return _readme;
end;
$plpgsql$;
```

In the above example, the `pg_readme.*` settings are (quite redundantly) set to
their default values.  There is no need to add `pg_readme` to the list of
requirements in your extension's control file; after all, the extension is only
intermittently required, _by you_, when you need to update your extension's
`README.md`.

To make it easy (and self-documenting) to update the readme, add something like
the following recipe to the bottom of your extension's `Makefile`:

```sql
README.md: README.sql install
        psql --quiet postgres < $< > $@
```

And turn the `README.sql` into something like this (again an example from `pg_rowalesce`):

```sql
\pset tuples_only
\pset format unaligned

begin;

create schema rowalesce;

create extension pg_rowalesce
    with schema rowalesce
    cascade;

select rowalesce.pg_rowalesce_readme();

rollback;
```

Now you can update your `README.md` by running:

```
make README.md
```

`COMMENT` (also on your extension), play with it, and never go back.  And don't
forget to send me the pull requests for you enhancements.

## Extension-specific settings

| Setting                                  | Default  |
| ---------------------------------------- | -------- |
| `pg_readme.include_routine_definitions`  | `false`  |
| `pg_readme.include_view_definitions`     | `true`   |

## Missing features

* Support for `<?pg-readme-install?>` PI.
* Table synopsis is not generated yet.
* (Composite) type and domain descriptions are not implemented.
* Function return signatures and `IN`/`INOUT` arguments are not yet described.

<?pg-readme-reference?>

<?pg-readme-colophon?>
$markdown$;

--------------------------------------------------------------------------------------------------------------

create or replace function pg_schema_readme(pg_catalog.regnamespace)
    returns text
    stable
    set search_path from current
    language plpgsql
    as $plpgsql$
declare
    _text text;
begin
    _text := format(
        $markdown$---
pg_schema_name: %s
pg_readme_generated_at: %s
pg_readme_version: %s
---

%s
$markdown$,
        $1::text,
        now(),
        pg_installed_extension_version('pg_readme'::name),
        obj_description($1::regnamespace::oid, 'pg_namespace')
    );

    _text := pg_readme_pis_process(
        unprocessed$ => _text,
        collection_type$ => 'schema'::pg_readme_collection_type,
        collection_name$ => $1::name,
        objects$ => (
            select
                row(
                    array_agg(pg_depend.objid::regclass)
                        filter (where pg_class.relkind in ('r', 'f', 'p'))
                    ,array_agg(pg_depend.objid::regclass)
                        filter (where pg_class.relkind in ('v', 'm'))
                    ,array_agg(pg_depend.objid::regprocedure)
                        filter (where pg_depend.classid = 'pg_catalog.pg_proc'::regclass)
                    ,array_agg(pg_depend.objid::regoperator)
                        filter (where pg_depend.classid = 'pg_catalog.pg_proc'::regclass)
                    ,array_agg(pg_depend.objid::regtype)
                        filter (where pg_depend.classid = 'pg_catalog.pg_type'::regclass)
                )::pg_readme_objects_for_reference
            from
                pg_catalog.pg_depend
            left outer join
                pg_catalog.pg_class
                on pg_depend.classid = 'pg_catalog.pg_class'::regclass
                and pg_class.oid = pg_depend.objid
            where
                pg_depend.refclassid = 'pg_catalog.pg_namespace'::regclass
                and pg_depend.refobjid = $1
        )
    );

    _text := trim(both E'\n' from _text);
    _text := regexp_replace(_text, '\n{3,}', E'\n\n', 'g');
    return _text;
end;
$plpgsql$;

--------------------------------------------------------------------------------------------------------------

create or replace procedure test__pg_readme()
    set search_path from current
    set plpgsql.check_asserts to true
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
# `test__pg_readme` – THE schema of schemas

This schema is amazing!

<?pg-readme-reference context-division-depth="2"?>

<?pg-readme-colophon context-division-depth="2"?>
$markdown$;

    create function test__pg_readme.func(int, text, bool[])
        returns bool language sql return true;
    create function test__pg_readme.func(int, text)
        returns bool language sql return true;

    assert pg_schema_readme('test__pg_readme') = format(
        $markdown$---
pg_schema_name: test__pg_readme
pg_readme_generated_at: %s
pg_readme_version: %s
---

# `test__pg_readme` – THE schema of schemas

This schema is amazing!

### Object reference

#### Routines

##### Function: `test__pg_readme.func(integer,text)`

##### Function: `test__pg_readme.func(integer,text,boolean[])`

### Colophon

This `README.md` for the `test__pg_readme` `schema` was automatically generated using the
[`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL
extension.$markdown$,
        now(),
        pg_installed_extension_version('pg_readme')
    ),
        pg_schema_readme('test__pg_readme');

    raise transaction_rollback;  -- I could have use any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$plpgsql$;

--------------------------------------------------------------------------------------------------------------
