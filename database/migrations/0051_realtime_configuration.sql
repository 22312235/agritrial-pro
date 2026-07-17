-- ============================================================
-- AgriTrial Pro
-- Migration: 0051_realtime_configuration.sql
-- Purpose: Configure Supabase Realtime publication and
--          replica identity for operational tables
-- ============================================================

BEGIN;

SET search_path = public, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

-- ============================================================
-- 1. VALIDATE SUPABASE REALTIME PUBLICATION
-- ============================================================

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_publication
        WHERE pubname = 'supabase_realtime'
    ) THEN
        EXECUTE 'CREATE PUBLICATION supabase_realtime';
    END IF;
END;
$$;

-- ============================================================
-- 2. CONFIGURE REPLICA IDENTITY
-- ============================================================

DO $$
DECLARE
    v_table_name text;
    v_realtime_tables constant text[] := ARRAY[
        'profiles',
        'trials',
        'trial_varieties',
        'trial_photos',
        'trial_status_history',
        'evaluations',
        'evaluation_details',
        'evaluation_detail_options',
        'evaluation_photos',
        'generated_reports'
    ];
BEGIN
    FOREACH v_table_name IN ARRAY v_realtime_tables
    LOOP
        IF to_regclass(
            format(
                'public.%I',
                v_table_name
            )
        ) IS NOT NULL THEN
            EXECUTE format(
                'ALTER TABLE public.%I REPLICA IDENTITY FULL',
                v_table_name
            );
        END IF;
    END LOOP;
END;
$$;

-- ============================================================
-- 3. ADD OPERATIONAL TABLES TO REALTIME
-- ============================================================

DO $$
DECLARE
    v_table_name text;
    v_realtime_tables constant text[] := ARRAY[
        'profiles',
        'trials',
        'trial_varieties',
        'trial_photos',
        'trial_status_history',
        'evaluations',
        'evaluation_details',
        'evaluation_detail_options',
        'evaluation_photos',
        'generated_reports'
    ];
BEGIN
    FOREACH v_table_name IN ARRAY v_realtime_tables
    LOOP
        IF to_regclass(
            format(
                'public.%I',
                v_table_name
            )
        ) IS NOT NULL
        AND NOT EXISTS (
            SELECT 1
            FROM pg_catalog.pg_publication_tables pt
            WHERE pt.pubname = 'supabase_realtime'
              AND pt.schemaname = 'public'
              AND pt.tablename = v_table_name
        ) THEN
            EXECUTE format(
                'ALTER PUBLICATION supabase_realtime
                 ADD TABLE public.%I',
                v_table_name
            );
        END IF;
    END LOOP;
END;
$$;

-- ============================================================
-- 4. REMOVE MASTER DATA TABLES FROM REALTIME
-- ============================================================

DO $$
DECLARE
    v_table_name text;
    v_non_realtime_tables constant text[] := ARRAY[
        'roles',
        'regions',
        'provinces',
        'growers',
        'farms',
        'experimental_stations',
        'seasons',
        'crops',
        'crop_types',
        'product_types',
        'trial_types',
        'witness_varieties',
        'growth_stages',
        'fruit_shapes',
        'fruit_colors',
        'fruit_defects',
        'recommendation_types',
        'decision_types',
        'weather_conditions',
        'trial_statuses',
        'evaluation_types',
        'criterion_data_types',
        'evaluation_criteria',
        'criterion_options',
        'criterion_assignments',
        'report_templates'
    ];
BEGIN
    FOREACH v_table_name IN ARRAY v_non_realtime_tables
    LOOP
        IF EXISTS (
            SELECT 1
            FROM pg_catalog.pg_publication_tables pt
            WHERE pt.pubname = 'supabase_realtime'
              AND pt.schemaname = 'public'
              AND pt.tablename = v_table_name
        ) THEN
            EXECUTE format(
                'ALTER PUBLICATION supabase_realtime
                 DROP TABLE public.%I',
                v_table_name
            );
        END IF;
    END LOOP;
END;
$$;

-- ============================================================
-- 5. TRIAL REALTIME CHANNEL HELPER
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_realtime_trial_channel(
    p_trial_id uuid
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
    SELECT CASE
        WHEN p_trial_id IS NULL THEN NULL
        ELSE concat(
            'trial:',
            p_trial_id::text
        )
    END;
$$;

COMMENT ON FUNCTION public.fn_realtime_trial_channel(uuid)
IS 'Returns the standard Supabase Realtime channel name for a trial.';

-- ============================================================
-- 6. EVALUATION REALTIME CHANNEL HELPER
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_realtime_evaluation_channel(
    p_evaluation_id uuid
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
    SELECT CASE
        WHEN p_evaluation_id IS NULL THEN NULL
        ELSE concat(
            'evaluation:',
            p_evaluation_id::text
        )
    END;
$$;

COMMENT ON FUNCTION public.fn_realtime_evaluation_channel(uuid)
IS 'Returns the standard Supabase Realtime channel name for an evaluation.';

-- ============================================================
-- 7. USER REALTIME CHANNEL HELPER
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_realtime_user_channel(
    p_user_id uuid
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
    SELECT CASE
        WHEN p_user_id IS NULL THEN NULL
        ELSE concat(
            'user:',
            p_user_id::text
        )
    END;
$$;

COMMENT ON FUNCTION public.fn_realtime_user_channel(uuid)
IS 'Returns the standard Supabase Realtime channel name for an application user.';

-- ============================================================
-- 8. MANAGEMENT REALTIME CHANNEL HELPER
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_realtime_management_channel()
RETURNS text
LANGUAGE sql
IMMUTABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
    SELECT 'management'::text;
$$;

COMMENT ON FUNCTION public.fn_realtime_management_channel()
IS 'Returns the standard Supabase Realtime channel name for management events.';

-- ============================================================
-- 9. DASHBOARD REALTIME CHANNEL HELPER
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_realtime_dashboard_channel()
RETURNS text
LANGUAGE sql
IMMUTABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
    SELECT 'dashboard'::text;
$$;

COMMENT ON FUNCTION public.fn_realtime_dashboard_channel()
IS 'Returns the standard Supabase Realtime channel name for dashboard events.';

-- ============================================================
-- 10. FUNCTION SECURITY
-- ============================================================

REVOKE ALL
ON FUNCTION public.fn_realtime_trial_channel(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_realtime_evaluation_channel(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_realtime_user_channel(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_realtime_management_channel()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_realtime_dashboard_channel()
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.fn_realtime_trial_channel(uuid)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_realtime_evaluation_channel(uuid)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_realtime_user_channel(uuid)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_realtime_management_channel()
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_realtime_dashboard_channel()
TO authenticated, service_role;

-- ============================================================
-- 11. VALIDATE REALTIME PUBLICATION TABLES
-- ============================================================

DO $$
DECLARE
    v_missing_tables text[];
BEGIN
    SELECT array_agg(required_table)
    INTO v_missing_tables
    FROM (
        VALUES
            ('profiles'),
            ('trials'),
            ('trial_varieties'),
            ('trial_photos'),
            ('trial_status_history'),
            ('evaluations'),
            ('evaluation_details'),
            ('evaluation_detail_options'),
            ('evaluation_photos'),
            ('generated_reports')
    ) AS required(required_table)
    WHERE to_regclass(
        format(
            'public.%I',
            required.required_table
        )
    ) IS NOT NULL
    AND NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_publication_tables pt
        WHERE pt.pubname = 'supabase_realtime'
          AND pt.schemaname = 'public'
          AND pt.tablename = required.required_table
    );

    IF v_missing_tables IS NOT NULL THEN
        RAISE EXCEPTION
            'Realtime publication validation failed. Missing tables: %',
            array_to_string(
                v_missing_tables,
                ', '
            );
    END IF;
END;
$$;

-- ============================================================
-- 12. VALIDATE REPLICA IDENTITY
-- ============================================================

DO $$
DECLARE
    v_invalid_tables text[];
BEGIN
    SELECT array_agg(c.relname ORDER BY c.relname)
    INTO v_invalid_tables
    FROM pg_catalog.pg_class c
    JOIN pg_catalog.pg_namespace n
      ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = ANY (
            ARRAY[
                'profiles',
                'trials',
                'trial_varieties',
                'trial_photos',
                'trial_status_history',
                'evaluations',
                'evaluation_details',
                'evaluation_detail_options',
                'evaluation_photos',
                'generated_reports'
            ]::text[]
      )
      AND c.relkind = 'r'
      AND c.relreplident <> 'f';

    IF v_invalid_tables IS NOT NULL THEN
        RAISE EXCEPTION
            'Realtime replica identity validation failed for: %',
            array_to_string(
                v_invalid_tables,
                ', '
            );
    END IF;
END;
$$;

-- ============================================================
-- 13. VALIDATE CHANNEL HELPERS
-- ============================================================

DO $$
DECLARE
    v_test_uuid constant uuid :=
        '00000000-0000-0000-0000-000000000000'::uuid;
BEGIN
    IF public.fn_realtime_trial_channel(
        v_test_uuid
    ) IS DISTINCT FROM
       'trial:00000000-0000-0000-0000-000000000000' THEN
        RAISE EXCEPTION
            'Trial Realtime channel helper validation failed.';
    END IF;

    IF public.fn_realtime_evaluation_channel(
        v_test_uuid
    ) IS DISTINCT FROM
       'evaluation:00000000-0000-0000-0000-000000000000' THEN
        RAISE EXCEPTION
            'Evaluation Realtime channel helper validation failed.';
    END IF;

    IF public.fn_realtime_user_channel(
        v_test_uuid
    ) IS DISTINCT FROM
       'user:00000000-0000-0000-0000-000000000000' THEN
        RAISE EXCEPTION
            'User Realtime channel helper validation failed.';
    END IF;

    IF public.fn_realtime_management_channel()
       IS DISTINCT FROM 'management' THEN
        RAISE EXCEPTION
            'Management Realtime channel helper validation failed.';
    END IF;

    IF public.fn_realtime_dashboard_channel()
       IS DISTINCT FROM 'dashboard' THEN
        RAISE EXCEPTION
            'Dashboard Realtime channel helper validation failed.';
    END IF;

    RAISE NOTICE
        '0051_realtime_configuration.sql completed successfully.';
END;
$$;

COMMIT;
