/**
 * CHANGELOG.md:
 *
 * - Some Postgres 18+ compatibility fixes were needed in
 *   `pg_extension_readme(name)` due to changes in the system catalogs:
 *
 *   + Non-array types are now excluded, because otherwise, in Postgres 18,
 *     every type was also included in the object reference as its array type
 *     (with its name prefixed by an underscore.
 *
 *   + Composite types that belong to table or views are now explicitly
 *     excluded, because otherwise every table or view would be included
 *     twice in the object reference.
 */
create or replace function pg_extension_readme(pg_catalog.name)
    returns text
    stable
    set search_path from current
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
                        filter (
                            where pg_depend.classid = 'pg_catalog.pg_type'::regclass
                            and pg_type.typelem = 0  -- Skip auto-generated array types.
                            and (pg_type.typrelid = 0 or pg_class__for_type.relkind = 'c')
                        )
                )::pg_readme_objects_for_reference
            from
                pg_catalog.pg_depend
            left outer join
                pg_catalog.pg_class
                on pg_depend.classid = 'pg_catalog.pg_class'::regclass
                and pg_class.oid = pg_depend.objid
            left outer join
                pg_catalog.pg_type
                on pg_depend.classid = 'pg_catalog.pg_type'::regclass
                and pg_type.oid = pg_depend.objid
            left outer join
                pg_catalog.pg_class as pg_class__for_type
                on pg_class__for_type.oid = pg_type.typrelid
            where
                pg_depend.refclassid = 'pg_catalog.pg_extension'::regclass
                and pg_depend.refobjid = _ext_oid
        )
    );

    _text := trim(both E'\n' from _text);
    _text := regexp_replace(_text, '(?:^ *\n){2,}', E'\n', 'ng');
    _text := regexp_replace(_text, '^ +$', '', 'gn');
    return _text;
end;
$plpgsql$;

/**
 * CHANGELOG.md:
 *
 * - In the `pg_readme_object_reference__rel_attr_list()` helper function, keep
 *   `NOT NULL` constraint from being listed twice in PostgreSQL 18.
 */
create or replace function pg_readme_object_reference__rel_attr_list(pg_class)
    returns text
    stable
    language plpgsql
    as $plpgsql$
declare
    _text text;
    _attr record;
    _constraint_text text;
begin
    _text = '';

    if ($1).relnatts > 0 then
        _text := _text || 'The `'
            || ($1).relname || '` '
            || case
                when ($1).relkind = 'r' then 'table'
                when ($1).relkind = 'v' then 'view'
                when ($1).relkind = 'm' then 'materialized view'
                when ($1).relkind = 'c' then 'composite type'
                when ($1).relkind = 'f' then 'foreign table'
                when ($1).relkind = 'p' then 'partitioned table'
                else '[missing `pg_class.relkind` = ''' || (($1).relkind)::text || ''' support]'
            end || E' has ' || ($1).relnatts::text || E' attributes:\n\n';

        for _attr in
            select
                pg_attribute.*
                ,pg_attrdef.*
                ,constraint_agg.constraint_arr
            from
                pg_catalog.pg_attribute
            left outer join
                pg_catalog.pg_attrdef
                on pg_attrdef.adrelid = pg_attribute.attrelid
                and pg_attrdef.adnum = pg_attribute.attnum
            cross join lateral (
                select
                    array_agg(pg_get_constraintdef(pg_constraint.oid, true)) as constraint_arr
                from
                    pg_catalog.pg_constraint
                where
                    pg_constraint.conrelid = pg_attribute.attrelid
                    and array_length(pg_constraint.conkey, 1) = 1
                    and pg_constraint.conkey[1] = pg_attribute.attnum
                    and pg_constraint.contype != 'n'  -- The `NOT NULL`ness of fields is checked seperately.
            ) as constraint_agg
            where
                pg_attribute.attrelid = ($1).oid
                and pg_attribute.attnum >= 1
        loop
            _text := _text || E'\n' || _attr.attnum::text || '. '
                || '`' || ($1).relname || '.' || _attr.attname || '` `' || _attr.atttypid::regtype::text
                || '`' || E'\n\n';
            _text := _text
                || coalesce(
                    regexp_replace(
                        col_description(($1).oid, _attr.attnum),
                        '^',
                        '   ',
                        'ng'
                    ) || E'\n\n',
                    ''
                );
            if _attr.attnotnull then
                _text := _text || E'   - `NOT NULL`\n';
            end if;
            if _attr.attidentity != '' then
                _text := _text || '   - `GENERATED '
                    || case
                        when _attr.attidentity = 'a'
                        then 'ALWAYS'
                        else 'BY DEFAULT'
                    end || ' AS IDENTITY'
                    -- TODO: sequence_options
                    || E'`\n'
                end;
            elsif _attr.atthasdef then
                _text := _text || '   - ' || case
                    when _attr.attgenerated = 's'
                    then '`GENERATED ALWAYS AS ('
                        || pg_get_expr(_attr.adbin, _attr.attrelid, true)
                        || ') STORED`' || E'\n'
                    else '`DEFAULT ' || pg_get_expr(_attr.adbin, _attr.attrelid, true) || E'`\n'
                end;
            end if;
            if _attr.constraint_arr is not null then
                foreach _constraint_text in array _attr.constraint_arr loop
                    _text := _text || '   - `' || _constraint_text || E'`\n';
                end loop;
            end if;
            _text := _text || E'\n' ;
        end loop;
    end if;

    return _text;
end;
$plpgsql$;
