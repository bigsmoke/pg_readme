-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_readme" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment
    on extension pg_readme
    is $markdown$
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

  * `&lt;?pg-readme-reference?&gt;` will be replaced with a full references
    with all the objects found by `pg_readme` that belong to the schema or
    extension (when `pg_schema_readme()` or `pg_extension_readme()` are run
    respectively.
  * `&lt;?pg-readme-colophon?&gt;` adds a colophon with information about
    `pg_readme` to the text.

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

## Missing features

* Support for `<?pg-readme-install?>` PI.
* Table synopsis is not generated yet.
* (Composite) type and domain descriptions are not implemented.

<?pg-readme-reference?>

<?pg-readme-colophon?>
$markdown$;

--------------------------------------------------------------------------------------------------------------
