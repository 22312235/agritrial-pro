-- AgriTrial Pro
-- Migration: 0061_database_documentation.sql
-- Purpose: Add database-level documentation and expose schema documentation views.

BEGIN;

SET search_path = public, auth, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

COMMENT ON SCHEMA public IS
'AgriTrial Pro application schema for field-trial installation, approval, evaluation, reporting, notifications, and audit data.';

CREATE OR REPLACE VIEW public.v_database_table_documentation
WITH (security_invoker = true)
AS
SELECT
    n.nspname::text AS schema_name,
    c.relname::text AS object_name,
    CASE c.relkind
        WHEN 'r' THEN 'TABLE'
        WHEN 'p' THEN 'PARTITIONED_TABLE'
        WHEN 'v' THEN 'VIEW'
        WHEN 'm' THEN 'MATERIALIZED_VIEW'
        WHEN 'f' THEN 'FOREIGN_TABLE'
        ELSE c.relkind::text
    END::text AS object_type,
    obj_description(c.oid, 'pg_class') AS description,
    c.reltuples::bigint AS estimated_rows,
    c.relrowsecurity AS row_level_security_enabled,
    c.relforcerowsecurity AS row_level_security_forced
FROM pg_class c
JOIN pg_namespace n
    ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
ORDER BY
    object_type,
    object_name;

COMMENT ON VIEW public.v_database_table_documentation IS
'Catalog view describing public tables, views, materialized views, estimated rows, and RLS status.';

CREATE OR REPLACE VIEW public.v_database_column_documentation
WITH (security_invoker = true)
AS
SELECT
    n.nspname::text AS schema_name,
    c.relname::text AS table_name,
    a.attnum::integer AS ordinal_position,
    a.attname::text AS column_name,
    format_type(a.atttypid, a.atttypmod)::text AS data_type,
    NOT a.attnotnull AS is_nullable,
    pg_get_expr(d.adbin, d.adrelid)::text AS default_expression,
    col_description(c.oid, a.attnum) AS description
FROM pg_attribute a
JOIN pg_class c
    ON c.oid = a.attrelid
JOIN pg_namespace n
    ON n.oid = c.relnamespace
LEFT JOIN pg_attrdef d
    ON d.adrelid = a.attrelid
   AND d.adnum = a.attnum
WHERE n.nspname = 'public'
  AND c.relkind IN ('r', 'p', 'v', 'm', 'f')
  AND a.attnum > 0
  AND NOT a.attisdropped
ORDER BY
    table_name,
    ordinal_position;

COMMENT ON VIEW public.v_database_column_documentation IS
'Catalog view describing columns, data types, nullability, defaults, and comments for public objects.';

CREATE OR REPLACE VIEW public.v_database_function_documentation
WITH (security_invoker = true)
AS
SELECT
    n.nspname::text AS schema_name,
    p.proname::text AS function_name,
    pg_get_function_identity_arguments(p.oid)::text AS identity_arguments,
    pg_get_function_result(p.oid)::text AS return_type,
    l.lanname::text AS language,
    p.prosecdef AS security_definer,
    obj_description(p.oid, 'pg_proc') AS description
FROM pg_proc p
JOIN pg_namespace n
    ON n.oid = p.pronamespace
JOIN pg_language l
    ON l.oid = p.prolang
WHERE n.nspname = 'public'
ORDER BY
    function_name,
    identity_arguments;

COMMENT ON VIEW public.v_database_function_documentation IS
'Catalog view describing public functions, signatures, return types, languages, security mode, and comments.';

CREATE OR REPLACE VIEW public.v_database_policy_documentation
WITH (security_invoker = true)
AS
SELECT
    schemaname::text AS schema_name,
    tablename::text AS table_name,
    policyname::text AS policy_name,
    permissive::text AS policy_mode,
    roles::text[] AS roles,
    cmd::text AS command,
    qual::text AS using_expression,
    with_check::text AS check_expression
FROM pg_policies
WHERE schemaname = 'public'
ORDER BY
    table_name,
    policy_name;

COMMENT ON VIEW public.v_database_policy_documentation IS
'Catalog view describing all public row-level security policies.';

REVOKE ALL
ON TABLE public.v_database_table_documentation
FROM PUBLIC, anon;

REVOKE ALL
ON TABLE public.v_database_column_documentation
FROM PUBLIC, anon;

REVOKE ALL
ON TABLE public.v_database_function_documentation
FROM PUBLIC, anon;

REVOKE ALL
ON TABLE public.v_database_policy_documentation
FROM PUBLIC, anon;

GRANT SELECT
ON TABLE public.v_database_table_documentation
TO authenticated, service_role;

GRANT SELECT
ON TABLE public.v_database_column_documentation
TO authenticated, service_role;

GRANT SELECT
ON TABLE public.v_database_function_documentation
TO authenticated, service_role;

GRANT SELECT
ON TABLE public.v_database_policy_documentation
TO authenticated, service_role;

DO $$
BEGIN
    IF to_regclass('public.schema_versions') IS NOT NULL THEN
        INSERT INTO public.schema_versions
        (
            version_number,
            migration_name
        )
        VALUES
        (
            61,
            '0061_database_documentation.sql'
        )
        ON CONFLICT (version_number)
        DO UPDATE SET
            migration_name = EXCLUDED.migration_name,
            applied_at = now();
    END IF;
END;
$$;

DO $$
BEGIN
    IF to_regclass('public.v_database_table_documentation') IS NULL THEN
        RAISE EXCEPTION 'Database table documentation view was not created.';
    END IF;

    IF to_regclass('public.v_database_column_documentation') IS NULL THEN
        RAISE EXCEPTION 'Database column documentation view was not created.';
    END IF;

    IF to_regclass('public.v_database_function_documentation') IS NULL THEN
        RAISE EXCEPTION 'Database function documentation view was not created.';
    END IF;

    IF to_regclass('public.v_database_policy_documentation') IS NULL THEN
        RAISE EXCEPTION 'Database policy documentation view was not created.';
    END IF;

    RAISE NOTICE '0061_database_documentation.sql completed successfully.';
END;
$$;

COMMIT;
