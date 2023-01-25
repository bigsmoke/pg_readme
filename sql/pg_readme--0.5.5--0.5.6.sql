-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION pg_readme" to load this file. \quit

--------------------------------------------------------------------------------------------------------------

create or replace function pg_readme_meta_pgxn()
    returns jsonb
    stable
    language sql
    return jsonb_build_object(
        'name'
        ,'pg_readme'
        ,'abstract'
        ,'Generates a Markdown README from COMMENT objects found in the pg_description system catalog.'
        ,'description'
        ,'The pg_readme PostgreSQL extension provides functions to generate a README.md document for a'
            ' database extension or schema, based on COMMENT objects found in the pg_description system'
            ' catalog.'
        ,'version'
        ,pg_installed_extension_version('pg_readme')
        ,'maintainer'
        ,array[
            'Rowan Rodrik van der Molen <rowan@bigsmoke.us>'
        ]
        ,'license'
        ,'postgresql'
        ,'prereqs'
        ,'{
            "runtime": {
                "requires": {
                    "hstore": 0
                }
            },
            "test": {
                "requires": {
                    "pgtap": 0
                }
            }
        }'::jsonb
        ,'provides'
        ,('{
            "pg_readme": {
                "file": "pg_readme--0.1.0.sql",
                "version": "' || pg_installed_extension_version('pg_readme') || '",
                "docfile": "README.md"
            }
        }')::jsonb
        ,'resources'
        ,'{
            "homepage": "https://blog.bigsmoke.us/tag/pg_readme",
            "bugtracker": {
                "web": "https://github.com/bigsmoke/pg_readme/issues"
            },
            "repository": {
                "url": "https://github.com/bigsmoke/pg_readme.git",
                "web": "https://github.com/bigsmoke/pg_readme",
                "type": "git"
            }
        }'::jsonb
        ,'meta-spec'
        ,'{
            "version": "1.0.0",
            "url": "https://pgxn.org/spec/"
        }'::jsonb
        ,'generated_by'
        ,'`select pg_readme_meta_pgxn()`'
        ,'tags'
        ,array[
            'documentation',
            'markdown',
            'meta',
            'plpgsql',
            'function',
            'functions'
        ]
    );

--------------------------------------------------------------------------------------------------------------
