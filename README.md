---
pg_extension_name: pg_readme
pg_extension_version: 0.6.5
pg_readme_generated_at: 2023-11-28 17:37:41.050744+00
pg_readme_version: 0.6.5
---

# The `pg_readme` PostgreSQL extension

The `pg_readme` PostgreSQL extension provides functions to generate
a `README.md` document for a database extension or schema, based on
[`COMMENT`](https://www.postgresql.org/docs/current/sql-comment.html) objects
found in the
[`pg_description`](https://www.postgresql.org/docs/current/catalog-pg-description.html)
system catalog.

## Usage

To use `pg_readme` in your extension, the most self-documenting way to do it is
to create a function that calls the `readme.pg_extension_readme(name)`
function.  Here is an example take from the
[`pg_rowalesce`](https://github.com/bigsmoke/pg_rowalesce) extension:

```sql
create function pg_rowalesce_readme()
    returns text
    volatile
    set search_path from current
    set pg_readme.include_view_definitions to 'true'
    set pg_readme.include_routine_definition_like to '{test__%}'
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

## Markdown

The `pg_readme` author has made the choice for Markdown, not out of love for
Markdown, but out of practicality: Markdown, in all its neo-formal
interprations, has become ubiquitous.  Also, it has a straight-forward
fall-through to (X)HTML.  And we're not creating tech. books here (where TEI or
DocBook would have been the superior choice); we're merely generating
online/digital documentation on the basis of inline `COMMENT`s.

To make the pain of Markdown's many competing extensions and implementations
_somewhat_ bearable, `pg_readme` attempts to stick to those Markdown constructs
that are valid both according to:

  * [GitHub Flavored Markdown](https://github.github.com/gfm/) (GFM), and
  * [CommonMark](https://commonmark.org/).

“Attempts to”, because `pg_readme` relies heavily on MarkDown tables, which
_are_ supported by GFM, but _not_ by CommonMark.

## Processing instructions

`pg_readme` has support for a bunch of special XML processing instructions that
you can include in the Markdown `COMMENT ON EXTENSION` or `COMMENT ON SCHEMA`
objects:

  * <code>&lt;?pg-readme-reference?&gt;</code> will be replaced with a full
    reference with all the objects found by `pg_readme` that belong to the
    schema or extension (when
    [`pg_schema_readme()`](#function-pg_schema_readme-regnamespace) or
    [`pg_extension_readme()`](#function-pg_extension_readme-name) are run
    respectively.
  * <code>&lt;?pg-readme-colophon?&gt;</code> adds a colophon with information
    about `pg_readme` to the text.

<!--
<code></code> instead of `` is used to encode the above processing
instructions to jump into raw HTML mode, so that the &lt; and &gt; entity
references are not escaped.  And we need those entity references to keep
pg_readme from putting the full object reference and the colophon in the middle
of these list items.
-->

The following pseudo-attributes are supported for these processing instructions:

| Pseudo-attribute           | Coerced to | Default value                        |
| -------------------------- | ---------- | ------------------------------------ |
| `context-division-depth`   | `smallint` | `1`                                  |
| `context-division-is-self` | `boolean`  | `false`                              |
| `division-title`           | `text`     | `'Object reference'` / `'Colophon'`  |

(These attributes are called _pseudo-attributes_, because the XML spec does not
prescribe any particular structure for a processing instruction's content.

## Extension-specific settings

| Setting                                      | Default                                                         |
| -------------------------------------------- | --------------------------------------------------------------- |
| `pg_readme.include_view_definitions`         | `true`                                                          |
| `pg_readme.readme_url`                       | `'https://github.com/bigsmoke/pg_readme/blob/master/README.md'` |
| `pg_readme.include_routine_definitions_like` | `'{test__%}'`                                                   |
| `pg_readme.include_this_routine_definition`  | `null`                                                          |

`pg_readme.include_this_routine_definition` is meant to be only used on a
routine-local level to make sure that the definition for that particular
routine is either _always_ or _never_ included in the reference, regardless of
the `pg_readme.include_routine_definitions_like` setting.

For `pg_readme` version 0.3.0, `pg_readme.include_routine_definitions` has been
deprecated in favor of `pg_readme.include_routine_definitions_like`, and
`pg_readme.include_routine_definitions` is now interpreted as:

| Legacy setting                                  | Deduced setting                                                 |
| ----------------------------------------------- | --------------------------------------------------------------- |
| `pg_readme.include_routine_definitions is null` | `pg_readme.include_routine_definitions_like = array['test__%']` |
| `pg_readme.include_routine_definitions = true`  | `pg_readme.include_routine_definitions_like = array['%']`       |
| `pg_readme.include_routine_definitions = false` | `pg_readme.include_routine_definitions_like = array[]::text[]`  |

## To-dos and to-maybes

### Missing features

* Table synopsis is not generated yet.

### Ideas for improvement

* Support for `<?pg-readme-install?>` PI could be nice.
* Support for a `<?pg-readme-table-rows?>` PI in the `COMMENT` of specific
  tables could be a nice addition for extensions/schemas that have type-type
  tables.
* Automatically turning references to objects from other/builtin extensions or
  schemas into links could be a plus.  But this might also render the raw markup
  unreadable.  That, at least, would be a good argument against doing the same
  for extension-local object references.

## The origins of the `pg_readme` extension

`pg_readme`, together with a sizeable number of other PostgreSQL extensions, was
developed as part of the backend for the super-scalable [FlashMQ MQTT SaaS
service](https://www.flashmq.com).  Bundling and releasing this code publically
has:

- made the PostgreSQL schema architecture cleaner, with fewer
  interdependencies;
- made the documentation more complete and up-to-date;
- increased the amount of polish; and
- reduced the number of rough edges.

The public gaze does improve quality!

## Object reference

### Routines

#### Function: `pg_extension_readme (name)`

`pg_extension_readme()` automatically generates a `README.md` for the given extension, taking the `COMMENT ON EXTENSION` as the prelude, and optionally adding a full reference (with neatly layed out object characteristics from the `pg_catalog`) in the place where a <code>&lt;?pg-readme-reference?&gt;</code> processing instruction is encountered in the `COMMENT ON EXTENSION`.

See the [_Processing instructions_](#processing-instructions) section for
details about the processing instructions that are recognized and which
pseudo-attributes they support.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `name`                                                               |  |

Function return type: `text`

Function attributes: `STABLE`

Function-local settings:

  *  `SET search_path TO readme, ext, pg_temp`

#### Function: `pg_readme_colophon (pg_readme_collection_type, name, smallint, boolean, text)`

`pg_readme_colophon()` is a function internal to `pg_readme` that is used by `pg_readme_pis_process()` to replace <code>&lt;?pg-readme-colophon?&gt;</code> processing instructions with a standard colophon indicating that `pg_readme` was used to generate a schema or extension README.

See the [_Processing instructions_](#processing-instructions) section for an
overview of the processing instructions and their pseudo-attributes.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` | `collection_type$`                                                | `pg_readme_collection_type`                                          |  |
|   `$2` |       `IN` | `collection_name$`                                                | `name`                                                               |  |
|   `$3` |       `IN` | `context_division_depth$`                                         | `smallint`                                                           | `1` |
|   `$4` |       `IN` | `context_division_is_self$`                                       | `boolean`                                                            | `false` |
|   `$5` |       `IN` | `division_title$`                                                 | `text`                                                               | `'Colophon'::text` |

Function return type: `text`

Function attributes: `IMMUTABLE`, `LEAKPROOF`, `PARALLEL SAFE`

#### Function: `pg_readme_meta_pgxn()`

Returns the JSON meta data that has to go into the `META.json` file needed for [PGXN—PostgreSQL Extension Network](https://pgxn.org/) packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to
refresh the meta file with the function's current output, including the
`default_version`.

Function return type: `jsonb`

Function attributes: `STABLE`

#### Function: `pg_readme_object_reference (pg_readme_objects_for_reference, pg_readme_collection_type, name, smallint, boolean, text)`

`pg_readme_object_reference()` is a function internal to `pg_readme` that is delegated to by `pg_readme_pis_process()` to replace <code>&lt;?pg-readme-reference?&gt;</code> processing instructions with a standard colophon indicating that `pg_readme` was used to generate a schema or extension README.

See the [_Processing instructions_](#processing-instructions) section for an
overview of the processing instructions and their pseudo-attributes.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` | `objects$`                                                        | `pg_readme_objects_for_reference`                                    |  |
|   `$2` |       `IN` | `collection_type$`                                                | `pg_readme_collection_type`                                          |  |
|   `$3` |       `IN` | `collection_name$`                                                | `name`                                                               |  |
|   `$4` |       `IN` | `context_division_depth$`                                         | `smallint`                                                           | `1` |
|   `$5` |       `IN` | `context_division_is_self$`                                       | `boolean`                                                            | `false` |
|   `$6` |       `IN` | `division_title$`                                                 | `text`                                                               | `'Object reference'::text` |

Function return type: `text`

Function attributes: `STABLE`

Function-local settings:

  *  `SET search_path TO readme, ext, pg_temp`

#### Function: `pg_readme_object_reference__rel_attr_list (pg_class)`

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `pg_class`                                                           |  |

Function return type: `text`

Function attributes: `STABLE`

#### Function: `pg_readme_pi_pseudo_attrs (text, text)`

`pg_readme_pi_pseudo_attrs()` extracts the pseudo-attributes from the XML processing instruction with the given `pi_target$` found in the given`haystack$` argument.

See the `test__pg_readme_pi_pseudo_attrs()` procedure source for examples.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` | `haystack$`                                                       | `text`                                                               |  |
|   `$2` |       `IN` | `pi_target$`                                                      | `text`                                                               |  |

Function return type: `hstore`

Function attributes: `IMMUTABLE`, `LEAKPROOF`, `RETURNS NULL ON NULL INPUT`, `PARALLEL SAFE`

#### Function: `pg_readme_pis_process (text, pg_readme_collection_type, name, pg_readme_objects_for_reference)`

`pg_readme_object_reference()` is a function internal to `pg_readme` that is responsible for replacing processing instructions in the source text with generated content.

See the [_Processing instructions_](#processing-instructions) section for an overview of the processing instructions and their pseudo-attributes.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` | `unprocessed$`                                                    | `text`                                                               |  |
|   `$2` |       `IN` | `collection_type$`                                                | `pg_readme_collection_type`                                          |  |
|   `$3` |       `IN` | `collection_name$`                                                | `name`                                                               |  |
|   `$4` |       `IN` | `objects$`                                                        | `pg_readme_objects_for_reference`                                    |  |

Function return type: `text`

Function attributes: `STABLE`, `LEAKPROOF`, `RETURNS NULL ON NULL INPUT`, `PARALLEL SAFE`

Function-local settings:

  *  `SET search_path TO readme, ext, pg_temp`

#### Function: `pg_schema_readme (regnamespace)`

`pg_schema_readme()` automatically generates a `README.md` for the given schema, taking the `COMMENT ON SCHEMA` as the prelude, and optionally adding a full reference (with neatly layed out object characteristics from the `pg_catalog`) in the place where a <code>&lt;?pg-readme-reference?&gt;</code> processing instruction is encountered in the `COMMENT ON SCHEMA`.

See the [_Processing instructions_](#processing-instructions) section for
details about the processing instructions that are recognized and which
pseudo-attributes they support.

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `regnamespace`                                                       |  |

Function return type: `text`

Function attributes: `STABLE`

Function-local settings:

  *  `SET search_path TO readme, ext, pg_temp`

#### Function: `string_diff (text, text)`

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `text`                                                               |  |
|   `$2` |       `IN` |                                                                   | `text`                                                               |  |

Function return type: `text`

Function attributes: `IMMUTABLE`, `LEAKPROOF`, `RETURNS NULL ON NULL INPUT`

#### Procedure: `test__pg_readme()`

This routine tests the `pg_readme` extension.

The routine name is compliant with the `pg_tst` extension. An intentional choice has been made to not _depend_ on the `pg_tst` extension its test runner or developer-friendly assertions to keep the number of inter-extension dependencies to a minimum.

Procedure-local settings:

  *  `SET search_path TO readme, ext, pg_temp`
  *  `SET pg_readme.include_this_routine_definition TO false`
  *  `SET plpgsql.check_asserts TO true`

#### Procedure: `test__pg_readme_pi_pseudo_attrs()`

This routine tests the `pg_readme_pi_pseudo_attrs()` function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.

Procedure-local settings:

  *  `SET search_path TO readme, ext, pg_temp`

```sql
CREATE OR REPLACE PROCEDURE readme.test__pg_readme_pi_pseudo_attrs()
 LANGUAGE plpgsql
 SET search_path TO 'readme', 'ext', 'pg_temp'
AS $procedure$
begin
    assert pg_readme_pi_pseudo_attrs(
        '<?muizen-stapje soort="woelmuis" hem-of-haar="piep" a1="4"?>',
        'muizen-stapje'
    ) = hstore('soort=>woelmuis, hem-of-haar=>piep, a1=>4');

    assert pg_readme_pi_pseudo_attrs(
        'Blabla bla <?muizen-stapje soort="woelmuis" hem-of-haar="piep"?> Frotsepots',
        'muizen-stapje'
    ) = hstore('soort=>woelmuis, hem-of-haar=>piep');

    assert pg_readme_pi_pseudo_attrs(
        'Blabla bla <?muizen-stapje ?> Frotsepots',
        'muizen-stapje'
    ) is null;
end;
$procedure$
```

### Types

The following extra types have been defined _besides_ the implicit composite types of the [tables](#tables) and [views](#views) in this extension.

#### Composite type: `pg_readme_objects_for_reference`

```sql
CREATE TYPE pg_readme_objects_for_reference AS (
  table_objects regclass[],
  view_objects regclass[],
  procedure_objects regprocedure[],
  operator_objects regoperator[],
  type_objects regtype[]
);
```

#### Domain: `pg_readme_collection_type`

```sql
CREATE DOMAIN pg_readme_collection_type AS text
  CHECK ((VALUE = ANY (ARRAY['extension'::text, 'schema'::text])));
```

## Authors and contributors

* [Rowan](https://www.bigsmoke.us/) originated this extension in 2022 while
  developing the PostgreSQL backend for the [FlashMQ SaaS MQTT cloud
  broker](https://www.flashmq.com/).  Rowan does not like to see himself as a
  tech person or a tech writer, but, much to his chagrin, [he
  _is_](https://blog.bigsmoke.us/category/technology). Some of his chagrin
  about his disdain for the IT industry he poured into a book: [_Why
  Programming Still Sucks_](https://www.whyprogrammingstillsucks.com/).  Much
  more than a “tech bro”, he identifies as a garden gnome, fairy and ork rolled
  into one, and his passion is really to [regreen and reenchant his
  environment](https://sapienshabitat.com/).  One of his proudest achievements
  is to be the third generation ecological gardener to grow the wild garden
  around his beautiful [family holiday home in the forest of Norg, Drenthe,
  the Netherlands](https://www.schuilplaats-norg.nl/) (available for rent!).

## Colophon

This `README.md` for the `pg_readme` extension was automatically generated using the [`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL extension.
