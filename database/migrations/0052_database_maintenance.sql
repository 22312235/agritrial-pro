-- ============================================================
-- AgriTrial Pro
-- Migration: 0052_database_maintenance.sql
-- Purpose: Maintenance, statistics, integrity validation,
--          and database health helper functions
-- ============================================================

BEGIN;

SET search_path = public, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

-- ============================================================
-- 1. DATABASE VERSION
-- ============================================================

CREATE TABLE IF NOT EXISTS public.schema_versions
(
    version_number      integer PRIMARY KEY,
    migration_name      text        NOT NULL,
    applied_at          timestamptz NOT NULL DEFAULT now(),
    applied_by          uuid NULL REFERENCES auth.users(id),
    checksum            text NULL
);

COMMENT ON TABLE public.schema_versions
IS 'Tracks applied AgriTrial Pro database migrations.';

INSERT INTO public.schema_versions
(
    version_number,
    migration_name
)
VALUES
(
    52,
    '0052_database_maintenance.sql'
)
ON CONFLICT (version_number)
DO NOTHING;

-- ============================================================
-- 2. VACUUM / ANALYZE HELPER
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_database_analyze()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN

    ANALYZE public.profiles;
    ANALYZE public.trials;
    ANALYZE public.trial_varieties;
    ANALYZE public.trial_photos;
    ANALYZE public.trial_status_history;

    ANALYZE public.evaluations;
    ANALYZE public.evaluation_details;
    ANALYZE public.evaluation_detail_options;
    ANALYZE public.evaluation_photos;

    ANALYZE public.generated_reports;

END;
$$;

COMMENT ON FUNCTION public.fn_database_analyze()
IS 'Updates PostgreSQL statistics for operational tables.';

-- ============================================================
-- 3. DATABASE HEALTH SUMMARY
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_database_health()
RETURNS TABLE
(
    table_name text,
    row_count bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN

RETURN QUERY

SELECT
'profiles',
COUNT(*)
FROM profiles

UNION ALL

SELECT
'trials',
COUNT(*)
FROM trials

UNION ALL

SELECT
'trial_varieties',
COUNT(*)
FROM trial_varieties

UNION ALL

SELECT
'evaluations',
COUNT(*)
FROM evaluations

UNION ALL

SELECT
'evaluation_details',
COUNT(*)
FROM evaluation_details

UNION ALL

SELECT
'evaluation_photos',
COUNT(*)
FROM evaluation_photos

UNION ALL

SELECT
'generated_reports',
COUNT(*)
FROM generated_reports;

END;
$$;

COMMENT ON FUNCTION public.fn_database_health()
IS 'Returns row counts for operational tables.';

-- ============================================================
-- 4. DATABASE SIZE
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_database_size()
RETURNS TABLE
(
    database_name text,
    database_size text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS
$$

SELECT
current_database(),
pg_size_pretty(
pg_database_size(
current_database()
));

$$;

COMMENT ON FUNCTION public.fn_database_size()
IS 'Returns current database size.';

-- ============================================================
-- 5. TABLE SIZE REPORT
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_table_sizes()
RETURNS TABLE
(
    table_name text,
    total_size text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS
$$

SELECT
schemaname||'.'||tablename,
pg_size_pretty(
pg_total_relation_size(
quote_ident(schemaname)||'.'||quote_ident(tablename)
))
FROM pg_tables
WHERE schemaname='public'
ORDER BY
pg_total_relation_size(
quote_ident(schemaname)||'.'||quote_ident(tablename)
)
DESC;

$$;

COMMENT ON FUNCTION public.fn_table_sizes()
IS 'Returns table sizes ordered from largest to smallest.';

-- ============================================================
-- 6. FUNCTION SECURITY
-- ============================================================

REVOKE ALL
ON FUNCTION public.fn_database_analyze()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_database_health()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_database_size()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_table_sizes()
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.fn_database_analyze()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_database_health()
TO authenticated,
service_role;

GRANT EXECUTE
ON FUNCTION public.fn_database_size()
TO authenticated,
service_role;

GRANT EXECUTE
ON FUNCTION public.fn_table_sizes()
TO authenticated,
service_role;

-- ============================================================
-- 7. VALIDATION
-- ============================================================

DO
$$
BEGIN

IF NOT EXISTS
(
SELECT 1
FROM public.schema_versions
WHERE version_number=52
)
THEN
RAISE EXCEPTION
'Schema version registration failed.';
END IF;

PERFORM public.fn_database_size();

PERFORM *
FROM public.fn_database_health();

RAISE NOTICE
'0052_database_maintenance.sql completed successfully.';

END;
$$;

COMMIT;
