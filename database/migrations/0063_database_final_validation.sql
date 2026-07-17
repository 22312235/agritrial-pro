-- AgriTrial Pro
-- Migration: 0063_database_final_validation.sql
-- Purpose: Create the final non-destructive database validation report.

BEGIN;

SET search_path = public, auth, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

CREATE OR REPLACE FUNCTION public.fn_database_final_validation()
RETURNS TABLE
(
    validation_group text,
    object_name text,
    object_type text,
    status text,
    details text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_object record;
BEGIN
    FOR v_object IN
        SELECT *
        FROM (
            VALUES
                ('CORE', 'roles', 'TABLE'),
                ('CORE', 'profiles', 'TABLE'),
                ('LOCATION', 'regions', 'TABLE'),
                ('LOCATION', 'provinces', 'TABLE'),
                ('LOCATION', 'growers', 'TABLE'),
                ('LOCATION', 'farms', 'TABLE'),
                ('LOCATION', 'experimental_stations', 'TABLE'),
                ('MASTER_DATA', 'crops', 'TABLE'),
                ('MASTER_DATA', 'crop_types', 'TABLE'),
                ('MASTER_DATA', 'product_types', 'TABLE'),
                ('MASTER_DATA', 'trial_types', 'TABLE'),
                ('TRIALS', 'trials', 'TABLE'),
                ('TRIALS', 'trial_varieties', 'TABLE'),
                ('TRIALS', 'trial_photos', 'TABLE'),
                ('TRIALS', 'trial_status_history', 'TABLE'),
                ('EVALUATIONS', 'evaluations', 'TABLE'),
                ('EVALUATIONS', 'evaluation_details', 'TABLE'),
                ('EVALUATIONS', 'evaluation_detail_options', 'TABLE'),
                ('EVALUATIONS', 'evaluation_photos', 'TABLE'),
                ('REPORTING', 'generated_reports', 'TABLE'),
                ('REPORTING', 'report_templates', 'TABLE'),
                ('NOTIFICATIONS', 'notifications', 'TABLE'),
                ('NOTIFICATIONS', 'user_push_devices', 'TABLE'),
                ('NOTIFICATIONS', 'push_notification_queue', 'TABLE'),
                ('NOTIFICATIONS', 'push_notification_delivery_logs', 'TABLE'),
                ('DASHBOARD', 'mv_dashboard_trial_kpis', 'MATERIALIZED_VIEW'),
                ('DASHBOARD', 'mv_dashboard_evaluation_kpis', 'MATERIALIZED_VIEW'),
                ('REPORTING', 'v_report_trial_register', 'VIEW'),
                ('REPORTING', 'v_report_evaluations', 'VIEW'),
                ('HEALTH', 'v_database_health', 'VIEW')
        ) AS expected(
            validation_group,
            object_name,
            object_type
        )
    LOOP
        RETURN QUERY
        SELECT
            v_object.validation_group::text,
            v_object.object_name::text,
            v_object.object_type::text,
            CASE
                WHEN to_regclass(
                    format(
                        'public.%I',
                        v_object.object_name
                    )
                ) IS NOT NULL
                    THEN 'PASS'
                ELSE 'FAIL'
            END::text,
            CASE
                WHEN to_regclass(
                    format(
                        'public.%I',
                        v_object.object_name
                    )
                ) IS NOT NULL
                    THEN 'Object exists'
                ELSE 'Required object is missing'
            END::text;
    END LOOP;

    RETURN QUERY
    SELECT
        'SECURITY'::text,
        c.relname::text,
        'RLS'::text,
        CASE
            WHEN c.relrowsecurity THEN 'PASS'
            ELSE 'WARN'
        END::text,
        CASE
            WHEN c.relrowsecurity
                THEN 'Row-level security is enabled'
            ELSE 'Row-level security is not enabled'
        END::text
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
          'evaluation_photos',
          'notifications',
          'user_push_devices',
          'push_notification_queue',
          'push_notification_delivery_logs'
      )
    ORDER BY c.relname;

    RETURN QUERY
    SELECT
        'MIGRATIONS'::text,
        'schema_versions'::text,
        'VERSION'::text,
        CASE
            WHEN to_regclass('public.schema_versions') IS NULL
                THEN 'WARN'
            WHEN COALESCE(
                (
                    SELECT max(version_number)
                    FROM public.schema_versions
                ),
                0
            ) >= 63
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

COMMENT ON FUNCTION public.fn_database_final_validation() IS
'Returns the final AgriTrial Pro database validation report without modifying business data.';

CREATE OR REPLACE VIEW public.v_database_final_validation
WITH (security_invoker = true)
AS
SELECT
    validation_group,
    object_name,
    object_type,
    status,
    details,
    now() AS validated_at
FROM public.fn_database_final_validation();

COMMENT ON VIEW public.v_database_final_validation IS
'Final object-by-object validation report for the AgriTrial Pro database.';

CREATE OR REPLACE VIEW public.v_database_final_validation_summary
WITH (security_invoker = true)
AS
SELECT
    count(*)::integer AS total_validations,
    count(*) FILTER (WHERE status = 'PASS')::integer AS passed_validations,
    count(*) FILTER (WHERE status = 'WARN')::integer AS warning_validations,
    count(*) FILTER (WHERE status = 'FAIL')::integer AS failed_validations,
    CASE
        WHEN count(*) FILTER (WHERE status = 'FAIL') > 0
            THEN 'FAIL'
        WHEN count(*) FILTER (WHERE status = 'WARN') > 0
            THEN 'WARN'
        ELSE 'PASS'
    END::text AS overall_status,
    now() AS validated_at
FROM public.fn_database_final_validation();

COMMENT ON VIEW public.v_database_final_validation_summary IS
'Single-row final validation summary.';

REVOKE ALL
ON FUNCTION public.fn_database_final_validation()
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.fn_database_final_validation()
TO authenticated, service_role;

REVOKE ALL
ON TABLE public.v_database_final_validation
FROM PUBLIC, anon;

REVOKE ALL
ON TABLE public.v_database_final_validation_summary
FROM PUBLIC, anon;

GRANT SELECT
ON TABLE public.v_database_final_validation
TO authenticated, service_role;

GRANT SELECT
ON TABLE public.v_database_final_validation_summary
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
            63,
            '0063_database_final_validation.sql'
        )
        ON CONFLICT (version_number)
        DO UPDATE SET
            migration_name = EXCLUDED.migration_name,
            applied_at = now();
    END IF;
END;
$$;

DO $$
DECLARE
    v_failed integer;
BEGIN
    IF to_regprocedure('public.fn_database_final_validation()') IS NULL THEN
        RAISE EXCEPTION 'Final validation function was not created.';
    END IF;

    IF to_regclass('public.v_database_final_validation') IS NULL THEN
        RAISE EXCEPTION 'Final validation view was not created.';
    END IF;

    IF to_regclass('public.v_database_final_validation_summary') IS NULL THEN
        RAISE EXCEPTION 'Final validation summary view was not created.';
    END IF;

    SELECT count(*)
    INTO v_failed
    FROM public.fn_database_final_validation()
    WHERE status = 'FAIL';

    RAISE NOTICE
        '0063_database_final_validation.sql completed. Failed validation items: %.',
        v_failed;
END;
$$;

COMMIT;
