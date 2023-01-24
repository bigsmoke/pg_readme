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

## Extension-specific settings

| Setting                                  | Default  |
| ---------------------------------------- | -------- |
| `pg_readme.include_routine_definitions`  | `false`  |
| `pg_readme.include_view_definitions`     | `true`   |

## Missing features

* `pg_schema_readme(regnamespace)` is not actually implemented yet.
* Table synopsis is not generated yet.
* (Composite) type and domain descriptions are not implemented.

<?pg-readme-reference?>

<?pg-readme-colophon?>
$markdown$;

--------------------------------------------------------------------------------------------------------------

create type pg_readme_objects_for_reference as (
    table_objects regclass[]
    ,view_objects regclass[]
    ,procedure_objects regprocedure[]
    ,operator_objects regoperator[]
    ,type_objects regtype[]
);

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
            _text := _text || repeat('#', context_division_depth$ + 1)
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
            _text := _text || E'TODO: automatic type synopsis in `pg_readme_object_reference()`.\n\n';
        end loop;
    end if;
    assert _text is not null;

    return _text;
end;
$plpgsql$;

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
            $markdown$
This `README.md` for the `%s` `%s` was automatically generated using the
[`pg_readme`](https://github.com/bigsmoke/pg_readme) PostgreSQL
extension.

$markdown$,
            collection_name$,
            collection_type$
        );

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
        create or replace function pg_installed_extension_version(pg_catalog.name)
            returns text
            stable
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

--------------------------------------------------------------------------------------------------------------

create or replace procedure test__pg_readme_pi_pseudo_attrs()
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

--------------------------------------------------------------------------------------------------------------

create function pg_readme_pis_process(
        unprocessed$ text
        ,collection_type$ pg_readme_collection_type
        ,collection_name$ name
        ,objects$ pg_readme_objects_for_reference
    )
    returns text
    immutable
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

--------------------------------------------------------------------------------------------------------------

create function pg_extension_readme(pg_catalog.name)
    returns text
    stable
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
    _text := regexp_replace(_text, '\n{3,}', E'\n\n', 'g');
    return _text;
end;
$plpgsql$;

--------------------------------------------------------------------------------------------------------------

create function pg_schema_readme(pg_catalog.regnamespace)
    returns text
    stable
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

%s
---
$markdown$,
        $1::text,
        now(),
        pg_installed_extension_version('pg_readme'::name),
        obj_description($1, 'pg_catalog.pg_namespace')
    );

    return _text;
end;
$plpgsql$;

--------------------------------------------------------------------------------------------------------------

create procedure test__pg_readme()
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
pg_extension_version: 0.1.0
pg_readme_generated_at: %s
pg_readme_version: 0.1.0
---

# `my_ext`

Simplified ext. description.

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
extension.$markdown$,
        now()
    ),
        pg_extension_readme('pg_readme');

    create schema test__pg_readme;
    comment on schema test__pg_readme is $markdown$
This schema is amazing!

<?pg-readme-reference context-division-depth="2"?>
$markdown$;
    create function test__pg_readme.func(int, text, bool[])
        returns bool language sql return true;
    create function test__pg_readme.func(int, text)
        returns bool language sql return true;

    raise transaction_rollback;  -- I could have use any error code, but this one seemed to fit best.
exception
    when transaction_rollback then
end;
$plpgsql$;

--------------------------------------------------------------------------------------------------------------
