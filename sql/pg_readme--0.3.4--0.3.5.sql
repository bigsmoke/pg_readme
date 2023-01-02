-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_readme" to load this file. \quit

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
    _extension_schema name;
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
            _text := _text || E'TODO: automatic type synopsis in `pg_readme_object_reference()`.\n\n';
        end loop;
    end if;
    assert _text is not null;

    return _text;
end;
$plpgsql$;

--------------------------------------------------------------------------------------------------------------

-- Add missing `::text` cast on `($1).relkind`.
create or replace function pg_readme_object_reference__rel_attr_list(pg_class)
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
