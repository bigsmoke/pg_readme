-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_readme" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

comment on extension pg_readme is
$md$
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

<?pg-readme-reference?>

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

<?pg-readme-colophon?>
$md$;

--------------------------------------------------------------------------------------------------------------

do $$
declare
    _ddl_cmd_to_set_pg_readme_url text;
begin
    _ddl_cmd_to_set_pg_readme_url := 'ALTER DATABASE ' || current_database()
        || ' SET pg_readme.readme_url = ''https://github.com/bigsmoke/pg_readme/blob/master/README.md''';
    execute _ddl_cmd_to_set_pg_readme_url;
exception
    when insufficient_privilege then
        -- We say `superuser = false` in the control file; so let's just whine a little instead of crashing.
        raise warning using
            message = format(
                'Because you''re installing the pg_readme extension as non-superuser and because you'
                || ' are also not the owner of the %I DB, the database-level `pg_readme.readme_url` setting'
                || ' has not been set.',
                current_database()
            )
            ,detail = 'Settings of the form `<extension_name>.readme_url` are used by `pg_readme` to'
                || ' cross-link between extensions their README files.'
            ,hint = 'If you want full inter-extension README cross-linking, you can ask your friendly'
                || E' neighbourhood DBA to execute the following statement:\n'
                || _ddl_cmd_to_set_pg_readme_url || ';';
end;
$$;

--------------------------------------------------------------------------------------------------------------

do $$
begin
    if not exists(
        select from
            pg_catalog.pg_proc
        where
            pg_proc.pronamespace = current_schema::regnamespace
            and pg_proc.proname = 'pg_installed_extension_version'
    )
    then
        create function pg_installed_extension_version(pg_catalog.name)
            returns text
            stable
            set pg_readme.include_this_routine_definition to true
            language sql
            return (
                select
                    pg_extension.extversion
                from
                    pg_catalog.pg_extension
                where
                    pg_extension.extname = $1
            );

        alter extension pg_readme
            drop function pg_installed_extension_version(name);
    end if;
end;
$$;

comment on function pg_installed_extension_version(name) is
$md$`pg_installed_extension_version()` returns the version string of the currently installed version of the given extension.
$md$;

--------------------------------------------------------------------------------------------------------------

create function pg_readme_meta_pgxn()
    returns jsonb
    stable
    language sql
    return jsonb_build_object(
        'name'
        ,'pg_readme'
        ,'abstract'
        ,'Generates a Markdown README from COMMENT objects found in the pg_description system catalog.'
        ,'description'
        ,'The pg_readme PostgreSQL extension provides functions to generate a README.md document for a'
            ' database extension or schema, based on COMMENT objects found in the pg_description system'
            ' catalog.'
        ,'version'
        ,pg_installed_extension_version('pg_readme')
        ,'maintainer'
        ,array[
            'Rowan Rodrik van der Molen <rowan@bigsmoke.us>'
        ]
        ,'license'
        ,'postgresql'
        ,'prereqs'
        ,'{
            "runtime": {
                "requires": {
                    "hstore": 0
                }
            },
            "test": {
                "requires": {
                    "pgtap": 0
                }
            }
        }'::jsonb
        ,'provides'
        ,('{
            "pg_readme": {
                "file": "pg_readme--0.6.6.sql",
                "version": "' || pg_installed_extension_version('pg_readme') || '",
                "docfile": "README.md"
            }
        }')::jsonb
        ,'resources'
        ,'{
            "homepage": "https://blog.bigsmoke.us/tag/pg_readme",
            "bugtracker": {
                "web": "https://github.com/bigsmoke/pg_readme/issues"
            },
            "repository": {
                "url": "https://github.com/bigsmoke/pg_readme.git",
                "web": "https://github.com/bigsmoke/pg_readme",
                "type": "git"
            }
        }'::jsonb
        ,'meta-spec'
        ,'{
            "version": "1.0.0",
            "url": "https://pgxn.org/spec/"
        }'::jsonb
        ,'generated_by'
        ,'`select pg_readme_meta_pgxn()`'
        ,'tags'
        ,array[
            'documentation',
            'markdown',
            'meta',
            'plpgsql',
            'function',
            'functions'
        ]
    );

comment on function pg_readme_meta_pgxn() is
$md$Returns the JSON meta data that has to go into the `META.json` file needed for [PGXN—PostgreSQL Extension Network](https://pgxn.org/) packages.

The `Makefile` includes a recipe to allow the developer to: `make META.json` to
refresh the meta file with the function's current output, including the
`default_version`.
$md$;

--------------------------------------------------------------------------------------------------------------

create function pg_readme_object_reference__rel_attr_list(pg_class)
    returns text
    stable
    language plpgsql
    as $plpgsql$
declare
    _text text;
    _attr record;
    _constraint_text text;
begin
    _text = '';

    if ($1).relnatts > 0 then
        _text := _text || 'The `'
            || ($1).relname || '` '
            || case
                when ($1).relkind = 'r' then 'table'
                when ($1).relkind = 'v' then 'view'
                when ($1).relkind = 'm' then 'materialized view'
                when ($1).relkind = 'c' then 'composite type'
                when ($1).relkind = 'f' then 'foreign table'
                when ($1).relkind = 'p' then 'partitioned table'
                else '[missing `pg_class.relkind` = ''' || (($1).relkind)::text || ''' support]'
            end || E' has ' || ($1).relnatts::text || E' attributes:\n\n';

        for _attr in
            select
                pg_attribute.*
                ,pg_attrdef.*
                ,constraint_agg.constraint_arr
            from
                pg_catalog.pg_attribute
            left outer join
                pg_catalog.pg_attrdef
                on pg_attrdef.adrelid = pg_attribute.attrelid
                and pg_attrdef.adnum = pg_attribute.attnum
            cross join lateral (
                select
                    array_agg(pg_get_constraintdef(pg_constraint.oid, true)) as constraint_arr
                from
                    pg_catalog.pg_constraint
                where
                    pg_constraint.conrelid = pg_attribute.attrelid
                    and array_length(pg_constraint.conkey, 1) = 1
                    and pg_constraint.conkey[1] = pg_attribute.attnum
            ) as constraint_agg
            where
                pg_attribute.attrelid = ($1).oid
                and pg_attribute.attnum >= 1
        loop
            _text := _text || E'\n' || _attr.attnum::text || '. '
                || '`' || ($1).relname || '.' || _attr.attname || '` `' || _attr.atttypid::regtype::text
                || '`' || E'\n\n';
            _text := _text
                || coalesce(
                    regexp_replace(
                        col_description(($1).oid, _attr.attnum),
                        '^',
                        '   ',
                        'ng'
                    ) || E'\n\n',
                    ''
                );
            if _attr.attnotnull then
                _text := _text || E'   - `NOT NULL`\n';
            end if;
            if _attr.attidentity != '' then
                _text := _text || '   - `GENERATED '
                    || case
                        when _attr.attidentity = 'a'
                        then 'ALWAYS'
                        else 'BY DEFAULT'
                    end || ' AS IDENTITY'
                    -- TODO: sequence_options
                    || E'`\n'
                end;
            elsif _attr.atthasdef then
                _text := _text || '   - ' || case
                    when _attr.attgenerated = 's'
                    then '`GENERATED ALWAYS AS ('
                        || pg_get_expr(_attr.adbin, _attr.attrelid, true)
                        || ') STORED`' || E'\n'
                    else '`DEFAULT ' || pg_get_expr(_attr.adbin, _attr.attrelid, true) || E'`\n'
                end;
            end if;
            if _attr.constraint_arr is not null then
                foreach _constraint_text in array _attr.constraint_arr loop
                    _text := _text || '   - `' || _constraint_text || E'`\n';
                end loop;
            end if;
            _text := _text || E'\n' ;
        end loop;
    end if;

    return _text;
end;
$plpgsql$;

--------------------------------------------------------------------------------------------------------------

create type pg_readme_objects_for_reference as (
    table_objects regclass[]
    ,view_objects regclass[]
    ,procedure_objects regprocedure[]
    ,operator_objects regoperator[]
    ,type_objects regtype[]
);

--------------------------------------------------------------------------------------------------------------

create domain pg_readme_collection_type
    as text
    check (value in ('extension', 'schema'));

--------------------------------------------------------------------------------------------------------------

create function pg_readme_object_reference(
        objects$ pg_readme_objects_for_reference
        ,collection_type$ pg_readme_collection_type
        ,collection_name$ name
        ,context_division_depth$ smallint = 1
        ,context_division_is_self$ boolean = false
        ,division_title$ text = 'Object reference'
    )
    returns text
    stable
    set search_path from current
    language plpgsql
    as $plpgsql$
declare
    _text text;
    _regclass regclass;
    _pg_class pg_catalog.pg_class;
    _pg_proc pg_catalog.pg_proc;
    _pg_type pg_catalog.pg_type;
    _real_nargs int2;
    _regop regoperator;
    _regtype regtype;
    _extension_schema name;
begin
    perform set_config(
        'pg_readme.include_routine_definitions_like',
        coalesce(
            nullif(current_setting('pg_readme.include_routine_definitions_like', true), '')::text,
            case
                when nullif(current_setting('pg_readme.include_routine_definitions', true), '') is null
                then array['test__%']
                when current_setting('pg_readme.include_routine_definitions', true)::bool
                then array['%']
                else array[]::text[]
            end::text
        )::text,
        true
    );

    _text := '';
    if not context_division_is_self$ then
        context_division_depth$ = context_division_depth$ + 1;
        _text := _text || repeat('#', context_division_depth$)
            || ' ' || division_title$
            || E'\n\n';
    end if;
    assert _text is not null;

    if collection_type$ = 'extension' then
        _extension_schema := (
            select
                pg_available_extension_versions."schema"
            from
                pg_catalog.pg_available_extension_versions
            where
                pg_available_extension_versions.name = collection_name$
                and pg_available_extension_versions.installed
        );
        if _extension_schema is not null then
            _text := _text || repeat('#', context_division_depth$ + 1)
                || ' Schema: `' || quote_ident(_extension_schema) || '`'
                || E'\n\n'
                || '`' || quote_ident(collection_name$) || '` must be installed in the'
                || ' `' || quote_ident(_extension_schema) || '` schema.  Hence, it is not relocatable.'
                || E'\n\n'
                || coalesce(
                    E'---\n\n'
                        || obj_description(_extension_schema::regnamespace, 'pg_namespace') || E'\n\n'
                    ,''
                );
        end if;
    end if;

    if array_length((objects$).table_objects, 1) > 0 then
        _text := _text || repeat('#', context_division_depth$ + 1)
            || ' Tables'
            || E'\n\n';

        if collection_type$ = 'extension' then
            _text := _text || 'There are ' || array_length((objects$).table_objects, 1)::text || ' tables'
                || ' that directly belong to the `' || collection_name$ || E'` extension.\n\n';
        elsif collection_type$ = 'schema' then
            _text := _text || 'There are ' || array_length((objects$).table_objects, 1)::text || ' tables'
                || ' within the `' || collection_name$ || E'` schema.\n\n';
        end if;

        for _pg_class in
            select
                pg_class.*
            from
                pg_catalog.pg_class
            where
                pg_class.oid = any ((objects$).table_objects)
            order by
                pg_class.relnamespace::regnamespace::text
                ,pg_class.relname
        loop
            _text := _text || repeat('#', context_division_depth$ + 2)
                || ' Table: `'
                || _pg_class.relname || '`'
                || E'\n\n';

            _text := _text || coalesce(obj_description(_pg_class.oid, 'pg_class') || E'\n\n',  '');

            _text := _text || pg_readme_object_reference__rel_attr_list(_pg_class.*);
            -- TODO: Show synopsis with table column definitions, including constraints and defaults
            -- TODO: Show table constraint
            -- TODO: Show table indexes
            -- TODO: Show table triggers
        end loop;
    end if;
    assert _text is not null;

    if array_length((objects$).view_objects, 1) > 0 then
        _text := _text || repeat('#', context_division_depth$ + 1)
            || ' Views'
            || E'\n\n';

        foreach _regclass in array (objects$).view_objects loop
            _text := _text || repeat('#', context_division_depth$ + 2)
                || ' View: `'
                || _regclass::text || '`'
                || E'\n\n';
            _text := _text || coalesce(obj_description(_regclass, 'pg_class') || E'\n\n',  '');
            if coalesce(
                nullif(pg_catalog.current_setting('pg_readme.include_view_definitions', true), '')::bool,
                true
            ) then
                _text := _text || E'```sql\n'
                    || pg_catalog.pg_get_viewdef(_regclass, 80)
                    ||  E'\n```\n\n';
            end if;
        end loop;
    end if;
    assert _text is not null;

    if array_length((objects$).procedure_objects, 1) > 0 then
        _text := _text || repeat('#', context_division_depth$ + 1)
            || ' Routines'
            || E'\n\n';

        for _pg_proc in
            select
                pg_proc.*
            from
                pg_catalog.pg_proc
            where
                pg_proc.oid = any ((objects$).procedure_objects)
            order by
                pg_proc.oid::regprocedure::text
        loop
            _text := _text || repeat('#', context_division_depth$ + 2) || ' '
                || case when _pg_proc.prokind = 'p' then 'Procedure' else 'Function' end
                || ': `'
                || regexp_replace(
                    regexp_replace(_pg_proc.oid::regprocedure::text, '(\(.+\))$', ' \1'),
                    ',',
                    ', ',
                    'g'
                ) || '`'
                || E'\n\n';
            _text := _text || coalesce(obj_description(_pg_proc.oid, 'pg_proc') || E'\n\n',  '');
            if length(pg_get_function_arguments(_pg_proc.oid)) > 0 then
                _real_nargs := coalesce(array_length(_pg_proc.proallargtypes, 1), _pg_proc.pronargs);
                _text := _text || case when _pg_proc.prokind = 'p' then 'Procedure' else 'Function' end
                    || E' arguments:\n\n'
                    || E'| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |\n'
                    || E'| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |\n'
                    || (
                        select
                            string_agg(
                                '| ' || lpad('`$' || arg_types.arg_pos::text || '`', 6, ' ')
                                    || ' | '
                                    || lpad(
                                        '`' || case arg_modes.arg_mode
                                                when 'i' then 'IN'
                                                when 'o' then 'OUT'
                                                when 'b' then 'INOUT'
                                                when 'v' then 'VARIADIC'
                                                when 't' then 'TABLE' end || '`',
                                        10,
                                        ' '
                                    )
                                    || ' | '
                                    || rpad(
                                        coalesce('`' || arg_names.arg_name || '`', ''),
                                        current_setting('max_identifier_length')::int + 2,
                                        ' '
                                    )
                                    || ' | '
                                    || rpad(
                                            '`' || arg_types.arg_type::regtype::text || '`',
                                            current_setting('max_identifier_length')::int + 5,
                                            ' '
                                    )
                                    || ' | '
                                    || coalesce('`' || arg_defaults.arg_default::text || '`', '')
                                    || ' |',
                                E'\n'
                            )
                        from unnest(
                            coalesce(_pg_proc.proallargtypes::oid[], _pg_proc.proargtypes)
                        ) with ordinality as arg_types(arg_type, arg_pos)
                        inner join unnest(
                            coalesce(_pg_proc.proargmodes::char[], array_fill('i'::char, array[_real_nargs]))
                        ) with ordinality as arg_modes(arg_mode, arg_pos)
                            on arg_types.arg_pos = arg_modes.arg_pos
                        inner join unnest(
                            coalesce(_pg_proc.proargnames::text[], array_fill(null::text, array[_real_nargs]))
                        ) with ordinality as arg_names(arg_name, arg_pos)
                            on arg_modes.arg_pos = arg_names.arg_pos
                        left join lateral (
                            select
                                arg_default
                                ,_pg_proc.pronargs - _pg_proc.pronargdefaults + optional_arg_pos as arg_pos
                            from
                                unnest(string_to_array(pg_get_expr(_pg_proc.proargdefaults, 0), ', '))
                                    with ordinality
                                    as opt_arg_defaults(arg_default, optional_arg_pos)
                        ) as arg_defaults
                            on arg_defaults.arg_pos = arg_modes.arg_pos
                    ) || E'\n\n';
            end if;
            if _pg_proc.prokind != 'p' then
                _text := _text || 'Function return type: `' || pg_get_function_result(_pg_proc.oid) || E'`\n\n';
            end if;
            _text := _text || coalesce(
                case when _pg_proc.prokind = 'p' then 'Procedure' else 'Function' end
                || ' attributes: '
                || nullif(
                    array_to_string(
                        array[
                            (
                                case
                                    when _pg_proc.provolatile = 'i' then '`IMMUTABLE`'
                                    when _pg_proc.provolatile = 's' then '`STABLE`'
                                    else null  -- `VOLATILE` is the default
                                end
                            ),
                            (
                                case
                                    when _pg_proc.proleakproof then '`LEAKPROOF`'
                                    else null
                                end
                            ),
                            (
                                case
                                    when _pg_proc.proisstrict then '`RETURNS NULL ON NULL INPUT`'
                                    else null  -- `CALLED ON NULL INPUT` is the default
                                end
                            ),
                            (
                                case
                                    when _pg_proc.prosecdef then '`SECURITY DEFINER`'
                                    else null  -- `SECURITY INVOKER` is the default
                                end
                            ),
                            (
                                case
                                    when _pg_proc.proparallel = 's' then '`PARALLEL SAFE`'
                                    when _pg_proc.proparallel = 'r' then '`PARALLEL RESTRICTED`'
                                    else null  -- `PARALLEL UNSAFE` is the default
                                end
                            ),
                            (
                                case
                                    when _pg_proc.procost <> 100.0 then 'COST ' || _pg_proc.procost::text
                                    else null
                                end
                            ),
                            (
                                case
                                    when _pg_proc.prorows > 0.0 then 'ROWS ' || _pg_proc.prorows::text
                                    else null
                                end
                            )
                        ],
                        ', '
                    ),
                    ''
                ) || E'\n\n',
                ''
            );
            _text := _text || coalesce(
                case when _pg_proc.prokind = 'p' then 'Procedure' else 'Function' end
                    || E'-local settings:\n\n'
                    || (
                        select
                            string_agg(
                                '  *  `SET ' || (regexp_match(raw, '^([^=]+)=(.*)$'))[1] || ' TO '
                                    || (regexp_match(raw, '^([^=]+)=(.*)$'))[2] || '`',
                                E'\n'
                            )
                        from
                            unnest(_pg_proc.proconfig) as raw_cfg(raw)
                    ) || E'\n\n',
                ''
            );
            if (_pg_proc.proname like any (current_setting('pg_readme.include_routine_definitions_like')::text[])
                and not 'pg_readme.include_this_routine_definition=false' = any (_pg_proc.proconfig)
                ) or 'pg_readme.include_this_routine_definition=true' = any (_pg_proc.proconfig)

            then
                _text := _text || E'```sql\n'
                    || pg_catalog.pg_get_functiondef(_pg_proc.oid)
                    ||  E'```\n\n';
            end if;

            assert _text is not null, format('NULL result for pg_proc: %s', jsonb_pretty(to_jsonb(_pg_proc)));
        end loop;
    end if;
    assert _text is not null;

    if array_length((objects$).type_objects, 1) > 0 then
        _text := _text || repeat('#', context_division_depth$ + 1)
            || ' Types'
            || E'\n\n'
            || 'The following extra types have been defined _besides_ the implicit composite types of'
            || ' the [tables](#tables) and [views](#views) in this ' || collection_type$
            || E'.\n\n';

        for _pg_type in
            select
                pg_type.*
            from
                pg_catalog.pg_type
            where
                pg_type.oid = any ((objects$).type_objects)
        loop
            _text := _text || repeat('#', context_division_depth$ + 2)
                || case
                    when _pg_type.typtype = 'c'
                        then ' Composite type'
                    when _pg_type.typtype = 'd'
                        then ' Domain'
                    when _pg_type.typtype = 'e'
                        then ' Enum type'
                    when _pg_type.typtype = 'r'
                        then ' Range type'
                    when _pg_type.typtype = 'm'
                        then ' Multirange type'
                    else
                        'Type'
                end || ': `'
                || _pg_type.typname || '`'
                || E'\n\n';
            _text := _text || coalesce(obj_description(_pg_type.oid, 'pg_type') || E'\n\n',  '');
            if _pg_type.typtype = 'd' then
                _text := _text || E'```sql\n'
                    || 'CREATE DOMAIN ' || format_type(_pg_type.oid, null)
                    || ' AS ' || format_type(_pg_type.typbasetype, _pg_type.typtypmod)
                    || coalesce(
                        (
                            select  E'\n  ' || string_agg(pg_get_constraintdef(pg_constraint.oid), E'\n  ')
                            from    pg_catalog.pg_constraint
                            where   pg_constraint.contypid = _pg_type.oid
                        )
                        ,''
                    )
                    || coalesce(
                        (
                            select  E'\n  COLLATE ' || quote_ident(pg_collation.collname)
                            from    pg_catalog.pg_collation
                            where   pg_collation.oid = _pg_type.typcollation
                                    and pg_collation.collname != 'default'
                        )
                        ,''
                    )
                    || coalesce(E'\n  DEFAULT ' || _pg_type.typdefault, '')
                    || E';\n```\n\n';
            elsif _pg_type.typtype = 'c' then
                _text := _text || E'```sql\n'
                    || 'CREATE TYPE ' || format_type(_pg_type.oid, null)
                    || E' AS ('
                    || coalesce(
                        (
                            select
                                E'\n  ' || string_agg(
                                    quote_ident(pg_attribute.attname)
                                        || ' '
                                        || format_type(pg_attribute.atttypid, pg_attribute.atttypmod)
                                        || coalesce(
                                            E'\n    COLLATE ' || quote_ident(pg_collation.collname),
                                            ''
                                        ),
                                    E',\n  '
                                    order by pg_attribute.attnum
                                )
                            from
                                pg_catalog.pg_class
                            join
                                pg_catalog.pg_attribute
                                on pg_attribute.attrelid = pg_class.oid
                                and pg_attribute.attnum > 0
                            left join
                                pg_catalog.pg_collation
                                on pg_collation.oid = pg_attribute.attcollation
                                and pg_collation.collname != 'default'
                            where
                                pg_class.oid = _pg_type.typrelid
                        )
                        ,''
                    )
                    || E'\n);\n```\n\n';
            elsif _pg_type.typtype = 'e' then
                _text := _text || E'```sql\n'
                    || 'CREATE TYPE ' || format_type(_pg_type.oid, null)
                    || E' AS ENUM (\n    '
                    || (
                        select
                            string_agg(
                                quote_literal(pg_enum.enumlabel)
                                ,E',\n    '
                                order by pg_enum.enumsortorder
                            )
                        from
                            pg_catalog.pg_enum
                        where
                            pg_enum.enumtypid = _pg_type.oid
                    )
                    || E'\n);\n```\n\n';
            end if;
        end loop;
    end if;
    assert _text is not null;

    return _text;
end;
$plpgsql$;

comment on function pg_readme_object_reference is
$md$`pg_readme_object_reference()` is a function internal to `pg_readme` that is delegated to by `pg_readme_pis_process()` to replace <code>&lt;?pg-readme-reference?&gt;</code> processing instructions with a standard colophon indicating that `pg_readme` was used to generate a schema or extension README.

See the [_Processing instructions_](#processing-instructions) section for an
overview of the processing instructions and their pseudo-attributes.
$md$;

--------------------------------------------------------------------------------------------------------------

create function pg_readme_colophon(
        collection_type$ pg_readme_collection_type
        ,collection_name$ name
        ,context_division_depth$ smallint = 1
        ,context_division_is_self$ boolean = false
        ,division_title$ text = 'Colophon'
    )
    returns text
    immutable
    leakproof
    parallel safe
    return
        case
            when not context_division_is_self$
            then repeat('#', context_division_depth$ + 1) || ' ' || division_title$ || E'\n'
            else ''
        end
        || format(
            E'\nThis `README.md` for the `%s` %s was automatically generated using the [`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL extension.\n',
            collection_name$,
            collection_type$
        );

comment on function pg_readme_colophon(pg_readme_collection_type, name, smallint, bool, text) is
$md$`pg_readme_colophon()` is a function internal to `pg_readme` that is used by `pg_readme_pis_process()` to replace <code>&lt;?pg-readme-colophon?&gt;</code> processing instructions with a standard colophon indicating that `pg_readme` was used to generate a schema or extension README.

See the [_Processing instructions_](#processing-instructions) section for an
overview of the processing instructions and their pseudo-attributes.
$md$;

--------------------------------------------------------------------------------------------------------------

create function pg_readme_pi_pseudo_attrs(haystack$ text, pi_target$ text)
    returns hstore
    immutable
    leakproof
    parallel safe
    returns null on null input
    language sql
    return hstore(
        (
            select
                array_agg(m)
            from
                regexp_matches(
                    (regexp_match(haystack$, '<\?' || pi_target$ || '(.*?)\?>'))[1],
                    '\s+([a-z][a-z0-9-]+)="([^"]*)"',
                    'g'
                ) as m
        )::text[][2]
    );

comment on function pg_readme_pi_pseudo_attrs(text, text) is
$md$`pg_readme_pi_pseudo_attrs()` extracts the pseudo-attributes from the XML processing instruction with the given `pi_target$` found in the given`haystack$` argument.

See the `test__pg_readme_pi_pseudo_attrs()` procedure source for examples.
$md$;

--------------------------------------------------------------------------------------------------------------

create procedure test__pg_readme_pi_pseudo_attrs()
    language plpgsql
    set search_path from current
    as $plpgsql$
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
$plpgsql$;

comment on procedure test__pg_readme_pi_pseudo_attrs() is
$md$This routine tests the `pg_readme_pi_pseudo_attrs()` function.

The routine name is compliant with the `pg_tst` extension. An intentional
choice has been made to not _depend_ on the `pg_tst` extension its test runner
or developer-friendly assertions to keep the number of inter-extension
dependencies to a minimum.
$md$;

--------------------------------------------------------------------------------------------------------------

create function pg_readme_pis_process(
        unprocessed$ text
        ,collection_type$ pg_readme_collection_type
        ,collection_name$ name
        ,objects$ pg_readme_objects_for_reference
    )
    returns text
    stable
    leakproof
    parallel safe
    returns null on null input
    set search_path from current
    language plpgsql
    as $plpgsql$
declare
    _pi_psuedo_attrs hstore;
    _pi_target text;
    _target_function name;
    _generated text;
    _processed text;
begin
    _processed = unprocessed$;

    foreach _pi_target in array array['pg-readme-reference', 'pg-readme-colophon'] loop
        _target_function := case
            when _pi_target = 'pg-readme-reference'
                then 'pg_readme_object_reference'
            when _pi_target = 'pg-readme-colophon'
                then 'pg_readme_colophon'
        end;
        _pi_psuedo_attrs := pg_readme_pi_pseudo_attrs(unprocessed$, _pi_target);

        execute format(
            'SELECT %I(
                collection_type$ => %L::pg_readme_collection_type
                ,collection_name$ => %L::name
                %s
                %s
                %s
                %s
            )',
            _target_function,
            collection_type$,
            collection_name$,
            coalesce(
                ',context_division_depth$ => '
                    || (_pi_psuedo_attrs->'context-division-depth')::smallint::text
                    || '::smallint',
                ''
            ),
            coalesce(
                ',context_division_is_self$ => '
                    || (_pi_psuedo_attrs->'context-division-is-self')::bool::text
                    || '::bool',
                ''
            ),
            coalesce(
                ',division_title$ => '
                    || quote_literal(_pi_psuedo_attrs->'division-title')
                    || '::text',
                ''
            ),
            case
                when _target_function = 'pg_readme_object_reference'
                then ',objects$ => '
                        || quote_literal(objects$::text)
                        || '::pg_readme_objects_for_reference'
                else ''
            end
        ) into _generated;

        _processed := regexp_replace(_processed, '<\?' || _pi_target || '.*?\?>', _generated);
    end loop;

    return _processed;
end;
$plpgsql$;

comment on function pg_readme_pis_process is
$md$`pg_readme_object_reference()` is a function internal to `pg_readme` that is responsible for replacing processing instructions in the source text with generated content.

See the [_Processing instructions_](#processing-instructions) section for an overview of the processing instructions and their pseudo-attributes.
$md$;

--------------------------------------------------------------------------------------------------------------

create function pg_extension_readme(pg_catalog.name)
    returns text
    stable
    set search_path from current
    language plpgsql
    as $plpgsql$
declare
    _text text;
    _ext_oid oid;
    _reference_pi_attrs hstore;
    _colophon_pi_attrs hstore;
begin
    _ext_oid := (select oid from pg_catalog.pg_extension where extname = $1);

    _text := format(
        $markdown$---
pg_extension_name: %s
pg_extension_version: %s
pg_readme_generated_at: %s
pg_readme_version: %s
---

%s
$markdown$,
        $1::text,
        pg_installed_extension_version($1),
        now(),
        pg_installed_extension_version('pg_readme'::name),
        obj_description(_ext_oid, 'pg_extension')
    );

    _text = pg_readme_pis_process(
        unprocessed$ => _text,
        collection_type$ => 'extension',
        collection_name$ => $1,
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
                pg_depend.refclassid = 'pg_catalog.pg_extension'::regclass
                and pg_depend.refobjid = _ext_oid
        )
    );

    _text := trim(both E'\n' from _text);
    _text := regexp_replace(_text, '(?:^ *\n){2,}', E'\n', 'ng');
    _text := regexp_replace(_text, '^ +$', '', 'gn');
    return _text;
end;
$plpgsql$;

comment on function pg_extension_readme(name) is
$md$`pg_extension_readme()` automatically generates a `README.md` for the given extension, taking the `COMMENT ON EXTENSION` as the prelude, and optionally adding a full reference (with neatly layed out object characteristics from the `pg_catalog`) in the place where a <code>&lt;?pg-readme-reference?&gt;</code> processing instruction is encountered in the `COMMENT ON EXTENSION`.

See the [_Processing instructions_](#processing-instructions) section for
details about the processing instructions that are recognized and which
pseudo-attributes they support.
$md$;

--------------------------------------------------------------------------------------------------------------

create function pg_schema_readme(pg_catalog.regnamespace)
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

comment on function pg_schema_readme(regnamespace) is
$md$`pg_schema_readme()` automatically generates a `README.md` for the given schema, taking the `COMMENT ON SCHEMA` as the prelude, and optionally adding a full reference (with neatly layed out object characteristics from the `pg_catalog`) in the place where a <code>&lt;?pg-readme-reference?&gt;</code> processing instruction is encountered in the `COMMENT ON SCHEMA`.

See the [_Processing instructions_](#processing-instructions) section for
details about the processing instructions that are recognized and which
pseudo-attributes they support.
$md$;

--------------------------------------------------------------------------------------------------------------

create function string_diff(text, text)
    returns text
    immutable
    leakproof
    returns null on null input
    language plpgsql
    as $$
declare
    _a text[];
    _b text[];
    _line_count int;
    _line_no int;
    _diff text;
begin
    if $1 = $2 then
        return null;
    end if;

    _diff := '';

    _a := string_to_array($1, E'\n');
    _b := string_to_array($2, E'\n');
    _line_count := greatest(array_length(_a, 1), array_length(_b, 1));

    _line_no := 0;
    while _line_no < _line_count loop
        _line_no := _line_no + 1;

        if _a[_line_no] != _b[_line_no] then
            _diff := _diff || _line_no::text || E'\n'
                || '< ' || _a[_line_no] || E'\n'
                || '> ' || _b[_line_no] || E'\n';
        end if;
    end loop;

    return _diff;
end;
$$;

--------------------------------------------------------------------------------------------------------------

create procedure test__pg_readme()
    set search_path from current
    set pg_readme.include_this_routine_definition to false
    set plpgsql.check_asserts to true
    language plpgsql
    as $plpgsql$
declare
    _generated_extension_readme text;
    _expected_extension_readme text;
begin
    create extension pg_readme_test_extension
        with version 'forever';

    _expected_extension_readme := format(
        $markdown$---
pg_extension_name: pg_readme_test_extension
pg_extension_version: %s
pg_readme_generated_at: %s
pg_readme_version: %s
---

# `pg_readme_test_extension`

The `pg_readme_test_extension` PostgreSQL extension is sort of a sub-extension
of `pg_readme`, in the sense that the former's purpose is to test the latter's
capability to generate a comprehensive `README.md` for an extension.

The reason that this extension exists as a separate set of `.control` and `sql`
files is because we need an extension to fully test `pg_readme` its
`pg_extension_readme()` function.

## Reference

### Tables

There are 2 tables that directly belong to the `pg_readme_test_extension` extension.

#### Table: `my_2nd_table`

The `my_2nd_table` table has 3 attributes:

1. `my_2nd_table.a` `bigint`

   - `NOT NULL`
   - `PRIMARY KEY (a)`
   - `FOREIGN KEY (a) REFERENCES my_table(a) ON DELETE CASCADE`

2. `my_2nd_table.c` `bigint`

   - `NOT NULL`
   - `GENERATED BY DEFAULT AS IDENTITY`
   - `UNIQUE (c)`

3. `my_2nd_table.d` `timestamp without time zone`

   A column with a comment.

   Second paragraph of column comment.

   - `DEFAULT now()`

#### Table: `my_table`

A table with a comment.

The `my_table` table has 3 attributes:

1. `my_table.a` `bigint`

   - `NOT NULL`
   - `GENERATED ALWAYS AS IDENTITY`
   - `PRIMARY KEY (a)`

2. `my_table.b` `bigint`

   - `NOT NULL`
   - `GENERATED ALWAYS AS (a + 2) STORED`
   - `UNIQUE (b)`

3. `my_table.z` `text`

### Views

#### View: `my_view`

This is a view _with_ a `COMMENT`.

```sql
 SELECT my_table.a, my_table.b, my_2nd_table.*::my_2nd_table AS my_2nd_table,
    my_2nd_table.c, my_table.z
   FROM my_table
     LEFT JOIN my_2nd_table ON my_2nd_table.a = my_table.a;
```

#### View: `view_without_comment`

```sql
 SELECT my_table.a, my_table.b, my_2nd_table.*::my_2nd_table AS my_2nd_table,
    my_2nd_table.c, my_table.z
   FROM my_table
     JOIN my_2nd_table ON my_2nd_table.a = my_table.a;
```

### Routines

#### Function: `my_variadic_func (integer, integer[])`

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` | `boe$`                                                            | `integer`                                                            |  |
|   `$2` | `VARIADIC` | `bla$`                                                            | `integer[]`                                                          |  |

Function return type: `void`

#### Function: `my_view__upsert()`

Function return type: `trigger`

#### Procedure: `test__my_view()`

Procedure-local settings:

  *  `SET search_path TO readme, pg_temp`

```sql
CREATE OR REPLACE PROCEDURE readme.test__my_view()
 LANGUAGE plpgsql
 SET search_path TO 'readme', 'pg_temp'
AS $procedure$
declare
    _my_view my_view;
begin
    insert into my_view (z) values ('blah')
        returning *
        into _my_view;
    update my_view
        set z = 'bleh'  -- “bleh” is obviously better than “blah”
        where a = _my_view.a;
    delete from my_view
        where a = _my_view.a;

    raise transaction_rollback;  -- I could have use any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$procedure$
```

#### Procedure: `test__something_very_verbose()`

Procedure-local settings:

  *  `SET search_path TO readme, pg_temp`
  *  `SET pg_readme.include_this_routine_definition TO false`

### Types

The following extra types have been defined _besides_ the implicit composite types of the [tables](#tables) and [views](#views) in this extension.

#### Domain: `my_upper`

Must be uppercase text.

```sql
CREATE DOMAIN my_upper AS text
  CHECK ((VALUE = upper(VALUE)));
```

#### Composite type: `my_composite_type`

`my_composite_type` doesn't do much.

```sql
CREATE TYPE my_composite_type AS (
  "name with spaces" text[],
  created_at timestamp with time zone
);
```

#### Enum type: `my_enum_type`

```sql
CREATE TYPE my_enum_type AS ENUM (
    'FIRSTBLA',
    '2NDBLA'
);
```

## Appendices

### Appendix A. Colophon

This `README.md` for the `pg_readme_test_extension` extension was automatically generated using the [`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL extension.$markdown$,
        pg_installed_extension_version('pg_readme_test_extension'),
        now(),
        pg_installed_extension_version('pg_readme')
    );
    _generated_extension_readme := pg_extension_readme('pg_readme_test_extension');
    assert _generated_extension_readme = _expected_extension_readme,
        format(
            E'Generated extension README is not what expected (%s vs %s chars):\n\n%s',
            length(_generated_extension_readme),
            length(_expected_extension_readme),
            string_diff(_generated_extension_readme, _expected_extension_readme)
        );

    create schema test__pg_readme;
    comment
        on schema test__pg_readme
        is $markdown$
# `test__pg_readme` – THE schema of schemas

This schema is amazing!

<?pg-readme-reference context-division-depth="2"?>

<?pg-readme-colophon context-division-depth="2"?>
$markdown$;

    create table test__pg_readme.table1 (id int);
    comment
        on table test__pg_readme.table1
        is $markdown$
This table has a `COMMENT` that describes it.
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

#### Tables

There are 1 tables within the `test__pg_readme` schema.

##### Table: `table1`

This table has a `COMMENT` that describes it.

The `table1` table has 1 attributes:

1. `table1.id` `integer`

#### Routines

##### Function: `test__pg_readme.func (integer, text)`

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `integer`                                                            |  |
|   `$2` |       `IN` |                                                                   | `text`                                                               |  |

Function return type: `boolean`

##### Function: `test__pg_readme.func (integer, text, boolean[])`

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` |                                                                   | `integer`                                                            |  |
|   `$2` |       `IN` |                                                                   | `text`                                                               |  |
|   `$3` |       `IN` |                                                                   | `boolean[]`                                                          |  |

Function return type: `boolean`

### Colophon

This `README.md` for the `test__pg_readme` schema was automatically generated using the [`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL extension.$markdown$,
        now(),
        pg_installed_extension_version('pg_readme')
    ),
        pg_schema_readme('test__pg_readme');

    raise transaction_rollback;  -- I could have use any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$plpgsql$;

comment on procedure test__pg_readme() is
$md$This routine tests the `pg_readme` extension.

The routine name is compliant with the `pg_tst` extension. An intentional choice has been made to not _depend_ on the `pg_tst` extension its test runner or developer-friendly assertions to keep the number of inter-extension dependencies to a minimum.
$md$;

--------------------------------------------------------------------------------------------------------------
