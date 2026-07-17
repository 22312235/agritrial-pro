-- AgriTrial Pro
-- Migration: 0062_health_checks.sql
-- Purpose: Create database health-check functions and views.

BEGIN;

SET search_path = public, auth, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

CREATE OR REPLACE FUNCTION public.fn_database_health_checks()
RETURNS TABLE
(
    check_name text,
    status text,
    details text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
    RETURN QUERY
    SELECT
        'CORE_TABLES'::text,
        CASE
            WHEN to_regclass('public.profiles') IS NOT NULL
             AND to_regclass('public.trials') IS NOT NULL
             AND to_regclass('public.evaluations') IS NOT NULL
             AND to_regclass('public.evaluation_details') IS NOT NULL
                THEN 'PASS'
            ELSE 'FAIL'
        END::text,
        concat_ws(
            ', ',
            CASE WHEN to_regclass('public.profiles') IS NULL THEN 'profiles missing' END,
            CASE WHEN to_regclass('public.trials') IS NULL THEN 'trials missing' END,
            CASE WHEN to_regclass('public.evaluations') IS NULL THEN 'evaluations missing' END,
            CASE WHEN to_regclass('public.evaluation_details') IS NULL THEN 'evaluation_details missing' END
        )::text;

    RETURN QUERY
    SELECT
        'REFERENCE_TABLES'::text,
        CASE
            WHEN to_regclass('public.roles') IS NOT NULL
             AND to_regclass('public.crops') IS NOT NULL
             AND to_regclass('public.trial_statuses') IS NOT NULL
             AND to_regclass('public.evaluation_types') IS NOT NULL
                THEN 'PASS'
            ELSE 'FAIL'
        END::text,
        concat_ws(
            ', ',
            CASE WHEN to_regclass('public.roles') IS NULL THEN 'roles missing' END,
            CASE WHEN to_regclass('public.crops') IS NULL THEN 'crops missing' END,
            CASE WHEN to_regclass('public.trial_statuses') IS NULL THEN 'trial_statuses missing' END,
            CASE WHEN to_regclass('public.evaluation_types') IS NULL THEN 'evaluation_types missing' END
        )::text;

    RETURN QUERY
    SELECT
        'RLS_CONFIGURATION'::text,
        CASE
            WHEN NOT EXISTS (
                SELECT 1
                FROM pg_class c
                JOIN pg_namespace n
                    ON n.oid = c.relnamespace
                WHERE n.nspname = 'public'
                  AND c.relkind IN ('r', 'p')
                  AND c.relname IN (
                      'profiles',
                      'trials',
                      'trial_varieties',
                      'trial_photos',
                      'evaluations',
                      'evaluation_details',
                      'evaluation_photos'
                  )
                  AND NOT c.relrowsecurity
            )
                THEN 'PASS'
            ELSE 'WARN'
        END::text,
        COALESCE(
            (
                SELECT string_agg(c.relname, ', ' ORDER BY c.relname)
                FROM pg_class c
                JOIN pg_namespace n
                    ON n.oid = c.relnamespace
                WHERE n.nspname = 'public'
                  AND c.relkind IN ('r', 'p')
                  AND c.relname IN (
                      'profiles',
                      'trials',
                      'trial_varieties',
                      'trial_photos',
                      'evaluations',
                      'evaluation_details',
                      'evaluation_photos'
                  )
                  AND NOT c.relrowsecurity
            ),
            'RLS enabled on checked core tables'
        )::text;

    RETURN QUERY
    SELECT
        'INVALID_INDEXES'::text,
        CASE
            WHEN NOT EXISTS (
                SELECT 1
                FROM pg_index i
                JOIN pg_class c
                    ON c.oid = i.indexrelid
                JOIN pg_namespace n
                    ON n.oid = c.relnamespace
                WHERE n.nspname = 'public'
                  AND NOT i.indisvalid
            )
                THEN 'PASS'
            ELSE 'FAIL'
        END::text,
        COALESCE(
            (
                SELECT string_agg(c.relname, ', ' ORDER BY c.relname)
                FROM pg_index i
                JOIN pg_class c
                    ON c.oid = i.indexrelid
                JOIN pg_namespace n
                    ON n.oid = c.relnamespace
                WHERE n.nspname = 'public'
                  AND NOT i.indisvalid
            ),
            'No invalid public indexes'
        )::text;

    RETURN QUERY
    SELECT
        'UNVALIDATED_CONSTRAINTS'::text,
        CASE
            WHEN NOT EXISTS (
                SELECT 1
                FROM pg_constraint con
                JOIN pg_class c
                    ON c.oid = con.conrelid
                JOIN pg_namespace n
                    ON n.oid = c.relnamespace
                WHERE n.nspname = 'public'
                  AND NOT con.convalidated
            )
                THEN 'PASS'
            ELSE 'WARN'
        END::text,
        COALESCE(
            (
                SELECT string_agg(con.conname, ', ' ORDER BY con.conname)
                FROM pg_constraint con
                JOIN pg_class c
                    ON c.oid = con.conrelid
                JOIN pg_namespace n
                    ON n.oid = c.relnamespace
                WHERE n.nspname = 'public'
                  AND NOT con.convalidated
            ),
            'All public constraints are validated'
        )::text;

    RETURN QUERY
    SELECT
        'SCHEMA_VERSION'::text,
        CASE
            WHEN to_regclass('public.schema_versions') IS NULL
                THEN 'WARN'
            WHEN COALESCE(
                (
                    SELECT max(version_number)
                    FROM public.schema_versions
                ),
                0
            ) >= 62
                THEN 'PASS'
            ELSE 'WARN'
        END::text,
        CASE
            WHEN to_regclass('public.schema_versions') IS NULL
                THEN 'schema_versions table is not available'
            ELSE format(
                'Latest registered migration: %s',
                COALESCE(
                    (
                        SELECT max(version_number)
                        FROM public.schema_versions
                    ),
                    0
                )
            )
        END::text;
END;
$$;

COMMENT ON FUNCTION public.fn_database_health_checks() IS
'Returns non-destructive health checks for core objects, RLS, indexes, constraints, and migration version.';

CREATE OR REPLACE VIEW public.v_database_health
WITH (security_invoker = true)
AS
SELECT
    check_name,
    status,
    NULLIF(details, '') AS details,
    now() AS checked_at
FROM public.fn_database_health_checks();

COMMENT ON VIEW public.v_database_health IS
'Current database health-check results.';

CREATE OR REPLACE VIEW public.v_database_health_summary
WITH (security_invoker = true)
AS
SELECT
    count(*)::integer AS total_checks,
    count(*) FILTER (WHERE status = 'PASS')::integer AS passed_checks,
    count(*) FILTER (WHERE status = 'WARN')::integer AS warning_checks,
    count(*) FILTER (WHERE status = 'FAIL')::integer AS failed_checks,
    CASE
        WHEN count(*) FILTER (WHERE status = 'FAIL') > 0
            THEN 'FAIL'
        WHEN count(*) FILTER (WHERE status = 'WARN') > 0
            THEN 'WARN'
        ELSE 'PASS'
    END::text AS overall_status,
    now() AS checked_at
FROM public.fn_database_health_checks();

COMMENT ON VIEW public.v_database_health_summary IS
'Single-row summary of all database health checks.';

REVOKE ALL
ON FUNCTION public.fn_database_health_checks()
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.fn_database_health_checks()
TO authenticated, service_role;

REVOKE ALL
ON TABLE public.v_database_health
FROM PUBLIC, anon;

REVOKE ALL
ON TABLE public.v_database_health_summary
FROM PUBLIC, anon;

GRANT SELECT
ON TABLE public.v_database_health
TO authenticated, service_role;

GRANT SELECT
ON TABLE public.v_database_health_summary
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
            62,
            '0062_health_checks.sql'
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
    IF to_regprocedure('public.fn_database_health_checks()') IS NULL THEN
        RAISE EXCEPTION 'Database health-check function was not created.';
    END IF;

    IF to_regclass('public.v_database_health') IS NULL THEN
        RAISE EXCEPTION 'Database health view was not created.';
    END IF;

    IF to_regclass('public.v_database_health_summary') IS NULL THEN
        RAISE EXCEPTION 'Database health summary view was not created.';
    END IF;

    RAISE NOTICE '0062_health_checks.sql completed successfully.';
END;
$$;

COMMIT;
