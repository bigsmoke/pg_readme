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
    set search_path to 'pg_catalog, pg_temp'
    language plpgsql
    as $plpgsql$
declare
    _text text;
    _regclass regclass;
    _pg_proc pg_catalog.pg_proc;
    _regop regoperator;
    _regtype regtype;
begin
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

        foreach _regclass in array (objects$).table_objects loop
            _text := _text || repeat('#', context_division_depth$ + 2)
                || ' Table: `'
                || _regclass::text || '`'
                || E'\n\n';
            _text := _text || coalesce(obj_description(_regclass, 'pg_rel') || E'\n\n',  '');

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
                || _pg_proc.oid::regprocedure::text || '`'
                || E'\n\n';
            _text := _text || coalesce(obj_description(_pg_proc.oid, 'pg_proc') || E'\n\n',  '');
            if coalesce(
                pg_catalog.current_setting('pg_readme.include_routine_definitions', true)::bool,
                false
            ) then
                _text := _text || E'```\n'
                    || pg_catalog.pg_get_functiondef(_pg_proc.oid)
                    ||  E'\n```\n\n';
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
