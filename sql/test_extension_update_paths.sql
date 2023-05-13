\set ECHO none
\o /dev/null
\getenv extension_name EXTENSION_NAME
\getenv extension_entry_versions EXTENSION_ENTRY_VERSIONS
select
    not :{?extension_name} as extension_name_missing
    ,not :{?extension_entry_versions} as extension_entry_versions_missing;
\gset
\if :extension_name_missing
    \warn 'Missing `EXTENSION_NAME` environment variable.'
    \quit
\endif
\if :extension_entry_versions_missing
    -- No `EXTENSION_ENTRY_VERSIONS` environment variable given; we will later fall back to
    -- `default_version`.  First then we must make sure that the `:extension_entry_versions`
    -- variable exists (and is empty), or we would get a syntax error in the subsequent
    -- `SELECT`.  (`psql` variables must exist to not constitute a syntax error.)
    \set extension_entry_versions
\endif

\getenv fallback_schema_name FALLBACK_SCHEMA_NAME
\if :{?fallback_schema_name}
    \echo CREATE SCHEMA IF NOT EXISTS :fallback_schema_name;
    CREATE SCHEMA IF NOT EXISTS :fallback_schema_name;
    \echo SET SEARCH_PATH TO :fallback_schema_name;
    SET SEARCH_PATH TO :fallback_schema_name;
\endif
\o

\set SHOW_CONTEXT 'errors'
\set ON_ERROR_STOP

-- We put the `psql` variables into a temporary table, so that we can read them out from within the
-- PL/pgSQL`DO` block, as we cannot access these variables from within PL/pgSQL.
select
    :'extension_name' as extension_name
    ,nullif(
        string_to_array(:'extension_entry_versions', ' ')
        ,array[]::text[]
    ) as extension_entry_versions
into temporary
    ext
;

do $$
declare
    _extension_name text := (select extension_name from ext);
    _default_version text := (
        select
            default_version
        from
            pg_available_extensions
        where
            name = _extension_name
    );
    _source_versions text[] := coalesce(
        (select extension_entry_versions from ext)
        ,array[_default_version]
    );
    _source_version text;
    _create_extension text;
    _alter_extension text;
    _drop_extension text;
    _test_proc text;
begin
    set plpgsql.check_asserts to true;

    foreach _source_version in array _source_versions loop
        begin
            assert _source_version = _default_version or exists (
                    select from
                        pg_extension_update_paths(_extension_name)
                    where
                        source = _source_version
                        and target = _default_version
                        and path is not null
                )
                ,format(
                    'Missing update path from %L to %L.'
                    ,_source_version, _default_version
                );

            _create_extension := format(
                'CREATE EXTENSION %I WITH VERSION %L CASCADE'
                ,_extension_name, _source_version
            );
            _alter_extension := format(
                'ALTER EXTENSION %I UPDATE TO %L'
                ,_extension_name, _default_version
            );
            _drop_extension := format(
                'DROP EXTENSION %I CASCADE'
                ,_extension_name
            );
            raise notice '%', _create_extension;
            execute _create_extension;
            if _source_version != _default_version then
                raise notice '%', _alter_extension;
                execute _alter_extension;
            end if;

            for
                _test_proc
            in
            select
                case
                    when pg_proc.prokind = 'p' then
                        'CALL ' || pg_proc.oid::regprocedure::text
                    else
                        'PERFORM ' || pg_proc.oid::regprocedure::text
                end
            from
                pg_depend
            inner join
                pg_proc
                on pg_proc.oid = pg_depend.objid
                and pg_depend.classid = 'pg_proc'::regclass
            where
                pg_depend.refclassid = 'pg_extension'::regclass
                and pg_depend.refobjid = (select oid from pg_extension where extname = _extension_name)
                and pg_proc.proname like 'test\_\_%'
                and pg_proc.prokind in ('f', 'p')
            loop
                raise notice '%', _test_proc;
                execute _test_proc;
            end loop;

            raise notice '%', _drop_extension;
            execute _drop_extension;
        end;
    end loop;

    raise transaction_rollback;
exception
    when transaction_rollback then
end;
$$;
