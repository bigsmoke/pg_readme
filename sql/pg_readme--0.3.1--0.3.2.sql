-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_readme" to load this file. \quit

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
        ,'gpl_3'
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
                "file": "pg_readme--0.1.0.sql",
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

--------------------------------------------------------------------------------------------------------------

create or replace function pg_readme_object_reference(
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
    _regop regoperator;
    _regtype regtype;
begin
    perform set_config(
        'pg_readme.include_routine_definitions_like',
        coalesce(
            current_setting('pg_readme.include_routine_definitions_like', true),
            case
                when current_setting('pg_readme.include_routine_definitions', true) is null
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
        loop
            _text := _text || repeat('#', context_division_depth$ + 2)
                || ' Table: `'
                || _pg_class.relname || '`'
                || E'\n\n';

            _text := _text || coalesce(obj_description(_pg_class.oid, 'pg_rel') || E'\n\n',  '');

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
            _text := _text || coalesce(obj_description(_regclass, 'pg_rel') || E'\n\n',  '');
            if coalesce(
                pg_catalog.current_setting('pg_readme.include_view_definitions', true)::bool,
                true
            ) then
                _text := _text || E'```\n'
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
                    regexp_replace(_pg_proc.oid::regprocedure::text, '(\()', ' ('),
                    ',',
                    ', ',
                    'g'
                ) || '`'
                || E'\n\n';
            _text := _text || coalesce(obj_description(_pg_proc.oid, 'pg_proc') || E'\n\n',  '');
            if length(pg_get_function_arguments(_pg_proc.oid)) > 0 then
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
                            coalesce(_pg_proc.proargmodes::char[], array_fill('i'::char, array[_pg_proc.pronargs]))
                        ) with ordinality as arg_modes(arg_mode, arg_pos)
                            on arg_types.arg_pos = arg_modes.arg_pos
                        inner join unnest(
                            coalesce(_pg_proc.proargnames::text[], array_fill(null::text, array[_pg_proc.pronargs]))
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
                _text := _text || E'```\n'
                    || pg_catalog.pg_get_functiondef(_pg_proc.oid)
                    ||  E'```\n\n';
            end if;
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

        foreach _regtype in array (objects$).type_objects loop
            _text := _text || repeat('#', context_division_depth$ + 2)
                || ' Type: `'
                || _regtype::text || '`'
                || E'\n\n';
            _text := _text || coalesce(obj_description(_regclass, 'pg_type') || E'\n\n',  '');
            _text := _text || E'Upgrade `pg_readme` for automatic type synopsis.\n\n';
        end loop;
    end if;
    assert _text is not null;

    return _text;
end;
$plpgsql$;

--------------------------------------------------------------------------------------------------------------

create or replace procedure test__pg_readme()
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

#### Table: `my_table`

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

### Views

#### View: `my_view`

```
 SELECT my_table.a, my_table.b, my_2nd_table.*::my_2nd_table AS my_2nd_table,
    my_2nd_table.c, my_table.z
   FROM my_table
     LEFT JOIN my_2nd_table ON my_2nd_table.a = my_table.a;
```

### Routines

#### Function: `my_variadic_func (integer, integer[])`

Function arguments:

| Arg. # | Arg. mode  | Argument name                                                     | Argument type                                                        | Default expression  |
| ------ | ---------- | ----------------------------------------------------------------- | -------------------------------------------------------------------- | ------------------- |
|   `$1` |       `IN` | `boe$`                                                            | `integer`                                                            |  |
|   `$2` | `VARIADIC` | `bla$`                                                            | `integer[]`                                                          |  |

Function return type: `void`

#### Function: `my_view__upsert ()`

Function return type: `trigger`

#### Procedure: `test__my_view ()`

Procedure-local settings:

  *  `SET search_path TO readme, pg_temp`

```
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

#### Procedure: `test__something_very_verbose ()`

Procedure-local settings:

  *  `SET search_path TO readme, pg_temp`
  *  `SET pg_readme.include_this_routine_definition TO false`

### Types

The following extra types have been defined _besides_ the implicit composite types of the [tables](#tables) and [views](#views) in this extension.

#### Type: `my_upper`

Upgrade `pg_readme` for automatic type synopsis.

#### Type: `my_composite_type`

Upgrade `pg_readme` for automatic type synopsis.

## Appendices

### Appendix A. Colophon

This `README.md` for the `pg_readme_test_extension` `extension` was automatically generated using the [`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL extension.$markdown$,
        pg_installed_extension_version('pg_readme_test_extension'),
        now(),
        pg_installed_extension_version('pg_readme')
    );
    _generated_extension_readme := pg_extension_readme('pg_readme_test_extension');
    assert _generated_extension_readme = _expected_extension_readme,
        format(
            E'Generated extension is not what expected (%s vs %s chars):\n\n%s',
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

This `README.md` for the `test__pg_readme` `schema` was automatically generated using the [`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL extension.$markdown$,
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
