\pset tuples_only
\pset format unaligned

begin;

-- We install `hstore` explicitly into `ext` to get
-- a nice schema name in the `README.md`
create schema if not exists ext;
create extension if not exists hstore
    with schema ext;

create schema readme;
create extension pg_readme
    with schema readme;

select readme.pg_extension_readme('pg_readme');

rollback;
