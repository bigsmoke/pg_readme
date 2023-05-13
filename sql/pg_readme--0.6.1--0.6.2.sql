-- Complain if script is sourced in `psql`, rather than via `CREATE EXTENSION`
\echo Use "CREATE EXTENSION pg_readme" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

-- There was a crash if `pg_readme.include_routine_definitions_like` was `''`.
-- There was a crash if `pg_readme.include_view_definitions` was `''`.
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
    _pg_type pg_catalog.pg_type;
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
                _text := _text || E'```sql\n'
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

--------------------------------------------------------------------------------------------------------------
