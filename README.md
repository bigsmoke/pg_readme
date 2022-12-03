---
pg_extension_name: pg_readme
pg_extension_version: 0.1.1
pg_readme_generated_at: 2022-12-03 09:50:26.741217+00
pg_readme_version: 0.1.1
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

## Missing features

* Support for `<?pg-readme-install?>` PI.
* `pg_schema_readme(regnamespace)` is not actually implemented yet.
* Table synopsis is not generated yet.
* (Composite) type and domain descriptions are not implemented.

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
extension.
