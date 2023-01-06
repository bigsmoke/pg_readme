-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_readme" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

create table pg_readme_external_objects (
    obj_catalog regclass
    ,obj_id oid
    ,obj_schema name
    ,obj_name name
    ,obj_
    ,documentation_url
);

insert into pg_readme_external_objects values
    ('pg_namespace', 'pg_catalog'::regnamespace, 'https://www.postgresql.org/docs/current/catalogs.html'),
    ('pg_class', 'pg_aggregate'::regclass, 'https://www.postgresql.org/docs/current/catalog-pg-aggregate.html')
    ;

--------------------------------------------------------------------------------------------------------------

create function pg_readme_object_reference_links(text)
    returns text
    stable
    language plpgsql
    as $plpgsql$
begin
    with extension_readme_urls as (
        select
            pg_available_extensions."name" as extension_name
            ,pg_catalog.current_setting(
                pg_available_extensions."name" || '.readme_url',
                true
            ) as extension_readme_url
        from
            pg_catalog.pg_available_extensions
    )
end;
$plpgsql$;
