begin transaction;

create schema readme;

create extension pg_readme
    with schema readme
    cascade;

call readme.test__pg_readme_pi_pseudo_attrs();
call readme.test__pg_readme();

rollback transaction;
