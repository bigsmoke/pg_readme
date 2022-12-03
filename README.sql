\pset tuples_only
\pset format unaligned

begin;

create schema readme;

create extension pg_readme
    with schema readme
    cascade;

select readme.pg_extension_readme('pg_readme');

rollback;
