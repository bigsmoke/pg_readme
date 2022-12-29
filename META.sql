\pset tuples_only
\pset format unaligned

begin;

create schema readme;
create extension pg_readme
    with schema readme
    cascade;

select jsonb_pretty(readme.pg_readme_meta_pgxn());

rollback;
