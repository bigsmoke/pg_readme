\pset tuples_only
\pset format unaligned

begin;

create extension pg_readme cascade;

select pg_extension_readme('pg_readme');

rollback;
