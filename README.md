---
pg_extension_name: pg_readme
pg_extension_version: 0.1.0
pg_readme_generated_at: 2022-12-02 12:39:06.385195+00
pg_readme_version: 0.1.0
---

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

## Object reference

### Routines

#### Function: `public.pg_extension_readme(name)`

#### Function: `public.pg_installed_extension_version(name)`

#### Function: `public.pg_readme_colophon(public.pg_readme_collection_type,name,smallint,boolean,text)`

#### Function: `public.pg_readme_object_reference(public.pg_readme_objects_for_reference,public.pg_readme_collection_type,name,smallint,boolean,text)`

#### Function: `public.pg_readme_pi_pseudo_attrs(text,text)`

#### Function: `public.pg_readme_pis_process(text,public.pg_readme_collection_type,name,public.pg_readme_objects_for_reference)`

#### Function: `public.pg_schema_readme(regnamespace)`

#### Procedure: `public.test__pg_readme()`

#### Procedure: `public.test__pg_readme_pi_pseudo_attrs()`

### Types

The following extra types have been defined _besides_ the implicit composite types of the [tables](#tables) and [views](#views) in this extension.

#### Type: `public.pg_readme_objects_for_reference`

TODO: automatic type synopsis in `pg_readme_object_reference()`.

#### Type: `public.pg_readme_collection_type`

TODO: automatic type synopsis in `pg_readme_object_reference()`.

## Colophon

This `README.md` for the `pg_readme` `extension` was automatically generated using the
[`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL
extension.
