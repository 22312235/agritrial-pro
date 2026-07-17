-- AgriTrial Pro
-- Migration: 0058_dashboard_refresh_functions.sql
-- Purpose: Create secure refresh functions and monitoring views for dashboard materialized views.

BEGIN;

SET search_path = public, auth, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

DO $$
BEGIN
    IF to_regclass('public.mv_dashboard_trial_kpis') IS NULL THEN
        RAISE EXCEPTION 'Required materialized view public.mv_dashboard_trial_kpis does not exist. Run migration 0057 first.';
    END IF;

    IF to_regclass('public.mv_dashboard_trials_by_status') IS NULL THEN
        RAISE EXCEPTION 'Required materialized view public.mv_dashboard_trials_by_status does not exist. Run migration 0057 first.';
    END IF;

    IF to_regclass('public.mv_dashboard_trials_by_crop') IS NULL THEN
        RAISE EXCEPTION 'Required materialized view public.mv_dashboard_trials_by_crop does not exist. Run migration 0057 first.';
    END IF;

    IF to_regclass('public.mv_dashboard_trials_by_trial_type') IS NULL THEN
        RAISE EXCEPTION 'Required materialized view public.mv_dashboard_trials_by_trial_type does not exist. Run migration 0057 first.';
    END IF;

    IF to_regclass('public.mv_dashboard_trials_by_region') IS NULL THEN
        RAISE EXCEPTION 'Required materialized view public.mv_dashboard_trials_by_region does not exist. Run migration 0057 first.';
    END IF;

    IF to_regclass('public.mv_dashboard_evaluation_kpis') IS NULL THEN
        RAISE EXCEPTION 'Required materialized view public.mv_dashboard_evaluation_kpis does not exist. Run migration 0057 first.';
    END IF;

    IF to_regclass('public.mv_dashboard_evaluations_by_type') IS NULL THEN
        RAISE EXCEPTION 'Required materialized view public.mv_dashboard_evaluations_by_type does not exist. Run migration 0057 first.';
    END IF;

    IF to_regclass('public.mv_dashboard_recent_activity') IS NULL THEN
        RAISE EXCEPTION 'Required materialized view public.mv_dashboard_recent_activity does not exist. Run migration 0057 first.';
    END IF;
END;
$$;

CREATE TABLE IF NOT EXISTS public.dashboard_refresh_history
(
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    refresh_scope varchar(50) NOT NULL,
    requested_by uuid NULL REFERENCES auth.users(id) ON UPDATE CASCADE ON DELETE SET NULL,
    started_at timestamptz NOT NULL DEFAULT now(),
    completed_at timestamptz NULL,
    duration_ms integer NULL,
    status varchar(20) NOT NULL DEFAULT 'RUNNING',
    refreshed_views text[] NOT NULL DEFAULT ARRAY[]::text[],
    error_message text NULL,
    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT chk_dashboard_refresh_scope
        CHECK (
            refresh_scope IN (
                'ALL',
                'TRIALS',
                'EVALUATIONS',
                'RECENT_ACTIVITY'
            )
        ),

    CONSTRAINT chk_dashboard_refresh_status
        CHECK (
            status IN (
                'RUNNING',
                'SUCCESS',
                'FAILED'
            )
        ),

    CONSTRAINT chk_dashboard_refresh_duration
        CHECK (
            duration_ms IS NULL
            OR duration_ms >= 0
        ),

    CONSTRAINT chk_dashboard_refresh_completed_at
        CHECK (
            completed_at IS NULL
            OR completed_at >= started_at
        )
);

COMMENT ON TABLE public.dashboard_refresh_history IS
'Audit history of dashboard materialized-view refresh operations.';

CREATE INDEX IF NOT EXISTS idx_dashboard_refresh_history_started_at
ON public.dashboard_refresh_history(started_at DESC);

CREATE INDEX IF NOT EXISTS idx_dashboard_refresh_history_status
ON public.dashboard_refresh_history(status, started_at DESC);

CREATE INDEX IF NOT EXISTS idx_dashboard_refresh_history_scope
ON public.dashboard_refresh_history(refresh_scope, started_at DESC);

ALTER TABLE public.dashboard_refresh_history
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.dashboard_refresh_history
FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS dashboard_refresh_history_management_select
ON public.dashboard_refresh_history;

DROP POLICY IF EXISTS dashboard_refresh_history_service_role_all
ON public.dashboard_refresh_history;

CREATE POLICY dashboard_refresh_history_management_select
ON public.dashboard_refresh_history
FOR SELECT
TO authenticated
USING (
    public.fn_is_management()
);

CREATE POLICY dashboard_refresh_history_service_role_all
ON public.dashboard_refresh_history
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

CREATE OR REPLACE FUNCTION public.fn_refresh_dashboard_view(
    p_view_name text,
    p_concurrently boolean DEFAULT false
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_allowed boolean;
    v_sql text;
BEGIN
    v_allowed :=
        p_view_name IN (
            'mv_dashboard_trial_kpis',
            'mv_dashboard_trials_by_status',
            'mv_dashboard_trials_by_crop',
            'mv_dashboard_trials_by_trial_type',
            'mv_dashboard_trials_by_region',
            'mv_dashboard_evaluation_kpis',
            'mv_dashboard_evaluations_by_type',
            'mv_dashboard_recent_activity'
        );

    IF NOT v_allowed THEN
        RAISE EXCEPTION 'Dashboard materialized view is not allowed: %', p_view_name;
    END IF;

    IF to_regclass(format('public.%I', p_view_name)) IS NULL THEN
        RAISE EXCEPTION 'Dashboard materialized view does not exist: public.%', p_view_name;
    END IF;

    v_sql :=
        CASE
            WHEN p_concurrently THEN
                format('REFRESH MATERIALIZED VIEW CONCURRENTLY public.%I', p_view_name)
            ELSE
                format('REFRESH MATERIALIZED VIEW public.%I', p_view_name)
        END;

    EXECUTE v_sql;
END;
$$;

COMMENT ON FUNCTION public.fn_refresh_dashboard_view(text, boolean) IS
'Refreshes one approved dashboard materialized view by name.';

CREATE OR REPLACE FUNCTION public.fn_refresh_dashboard(
    p_scope varchar DEFAULT 'ALL',
    p_concurrently boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_scope varchar;
    v_refresh_id uuid;
    v_started_at timestamptz;
    v_views text[];
    v_view_name text;
BEGIN
    v_scope := upper(btrim(COALESCE(p_scope, 'ALL')));

    IF v_scope NOT IN (
        'ALL',
        'TRIALS',
        'EVALUATIONS',
        'RECENT_ACTIVITY'
    ) THEN
        RAISE EXCEPTION 'Invalid dashboard refresh scope: %', p_scope;
    END IF;

    v_views :=
        CASE v_scope
            WHEN 'TRIALS' THEN ARRAY[
                'mv_dashboard_trial_kpis',
                'mv_dashboard_trials_by_status',
                'mv_dashboard_trials_by_crop',
                'mv_dashboard_trials_by_trial_type',
                'mv_dashboard_trials_by_region'
            ]::text[]

            WHEN 'EVALUATIONS' THEN ARRAY[
                'mv_dashboard_evaluation_kpis',
                'mv_dashboard_evaluations_by_type'
            ]::text[]

            WHEN 'RECENT_ACTIVITY' THEN ARRAY[
                'mv_dashboard_recent_activity'
            ]::text[]

            ELSE ARRAY[
                'mv_dashboard_trial_kpis',
                'mv_dashboard_trials_by_status',
                'mv_dashboard_trials_by_crop',
                'mv_dashboard_trials_by_trial_type',
                'mv_dashboard_trials_by_region',
                'mv_dashboard_evaluation_kpis',
                'mv_dashboard_evaluations_by_type',
                'mv_dashboard_recent_activity'
            ]::text[]
        END;

    v_started_at := clock_timestamp();

    INSERT INTO public.dashboard_refresh_history
    (
        refresh_scope,
        requested_by,
        started_at,
        status,
        refreshed_views
    )
    VALUES
    (
        v_scope,
        auth.uid(),
        v_started_at,
        'RUNNING',
        ARRAY[]::text[]
    )
    RETURNING id
    INTO v_refresh_id;

    BEGIN
        FOREACH v_view_name IN ARRAY v_views
        LOOP
            PERFORM public.fn_refresh_dashboard_view(
                v_view_name,
                p_concurrently
            );

            UPDATE public.dashboard_refresh_history
            SET refreshed_views =
                array_append(
                    refreshed_views,
                    v_view_name
                )
            WHERE id = v_refresh_id;
        END LOOP;

        UPDATE public.dashboard_refresh_history
        SET
            completed_at = clock_timestamp(),
            duration_ms = GREATEST(
                0,
                floor(
                    extract(
                        epoch
                        FROM (
                            clock_timestamp() - v_started_at
                        )
                    ) * 1000
                )::integer
            ),
            status = 'SUCCESS',
            error_message = NULL
        WHERE id = v_refresh_id;

    EXCEPTION
        WHEN OTHERS THEN
            UPDATE public.dashboard_refresh_history
            SET
                completed_at = clock_timestamp(),
                duration_ms = GREATEST(
                    0,
                    floor(
                        extract(
                            epoch
                            FROM (
                                clock_timestamp() - v_started_at
                            )
                        ) * 1000
                    )::integer
                ),
                status = 'FAILED',
                error_message = SQLERRM
            WHERE id = v_refresh_id;

            RAISE;
    END;

    RETURN v_refresh_id;
END;
$$;

COMMENT ON FUNCTION public.fn_refresh_dashboard(varchar, boolean) IS
'Refreshes dashboard materialized views by scope and records the operation.';

CREATE OR REPLACE FUNCTION public.fn_refresh_dashboard_trials(
    p_concurrently boolean DEFAULT false
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT public.fn_refresh_dashboard(
        'TRIALS',
        p_concurrently
    );
$$;

COMMENT ON FUNCTION public.fn_refresh_dashboard_trials(boolean) IS
'Refreshes all trial-related dashboard materialized views.';

CREATE OR REPLACE FUNCTION public.fn_refresh_dashboard_evaluations(
    p_concurrently boolean DEFAULT false
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT public.fn_refresh_dashboard(
        'EVALUATIONS',
        p_concurrently
    );
$$;

COMMENT ON FUNCTION public.fn_refresh_dashboard_evaluations(boolean) IS
'Refreshes all evaluation-related dashboard materialized views.';

CREATE OR REPLACE FUNCTION public.fn_refresh_dashboard_recent_activity(
    p_concurrently boolean DEFAULT false
)
RETURNS uuid
LANGUAGE sql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT public.fn_refresh_dashboard(
        'RECENT_ACTIVITY',
        p_concurrently
    );
$$;

COMMENT ON FUNCTION public.fn_refresh_dashboard_recent_activity(boolean) IS
'Refreshes the recent-activity dashboard materialized view.';

CREATE OR REPLACE FUNCTION public.fn_get_dashboard_refresh_status()
RETURNS TABLE
(
    refresh_id uuid,
    refresh_scope varchar,
    requested_by uuid,
    started_at timestamptz,
    completed_at timestamptz,
    duration_ms integer,
    status varchar,
    refreshed_views text[],
    error_message text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT
        h.id,
        h.refresh_scope,
        h.requested_by,
        h.started_at,
        h.completed_at,
        h.duration_ms,
        h.status,
        h.refreshed_views,
        h.error_message
    FROM public.dashboard_refresh_history h
    ORDER BY h.started_at DESC
    LIMIT 100;
$$;

COMMENT ON FUNCTION public.fn_get_dashboard_refresh_status() IS
'Returns the 100 most recent dashboard refresh operations.';

CREATE OR REPLACE VIEW public.v_dashboard_refresh_health
WITH (security_invoker = true)
AS
SELECT
    h.id AS latest_refresh_id,
    h.refresh_scope,
    h.started_at,
    h.completed_at,
    h.duration_ms,
    h.status,
    h.refreshed_views,
    h.error_message,
    CASE
        WHEN h.status = 'SUCCESS'
             AND h.completed_at >= now() - interval '30 minutes'
            THEN 'HEALTHY'
        WHEN h.status = 'SUCCESS'
            THEN 'STALE'
        WHEN h.status = 'RUNNING'
            THEN 'RUNNING'
        ELSE 'FAILED'
    END::varchar AS health_status
FROM public.dashboard_refresh_history h
WHERE h.id = (
    SELECT h2.id
    FROM public.dashboard_refresh_history h2
    ORDER BY h2.started_at DESC
    LIMIT 1
);

COMMENT ON VIEW public.v_dashboard_refresh_health IS
'Health summary based on the most recent dashboard refresh operation.';

REVOKE ALL
ON TABLE public.dashboard_refresh_history
FROM PUBLIC, anon, authenticated;

GRANT SELECT
ON TABLE public.dashboard_refresh_history
TO authenticated;

GRANT ALL
ON TABLE public.dashboard_refresh_history
TO service_role;

REVOKE ALL
ON TABLE public.v_dashboard_refresh_health
FROM PUBLIC, anon;

GRANT SELECT
ON TABLE public.v_dashboard_refresh_health
TO authenticated, service_role;

REVOKE ALL
ON FUNCTION public.fn_refresh_dashboard_view(text, boolean)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.fn_refresh_dashboard(varchar, boolean)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.fn_refresh_dashboard_trials(boolean)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.fn_refresh_dashboard_evaluations(boolean)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.fn_refresh_dashboard_recent_activity(boolean)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.fn_get_dashboard_refresh_status()
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.fn_refresh_dashboard_view(text, boolean)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_refresh_dashboard(varchar, boolean)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_refresh_dashboard_trials(boolean)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_refresh_dashboard_evaluations(boolean)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_refresh_dashboard_recent_activity(boolean)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_get_dashboard_refresh_status()
TO authenticated, service_role;

SELECT public.fn_refresh_dashboard(
    'ALL',
    false
);

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
            58,
            '0058_dashboard_refresh_functions.sql'
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
    IF to_regclass('public.dashboard_refresh_history') IS NULL THEN
        RAISE EXCEPTION 'Table public.dashboard_refresh_history was not created.';
    END IF;

    IF to_regclass('public.v_dashboard_refresh_health') IS NULL THEN
        RAISE EXCEPTION 'View public.v_dashboard_refresh_health was not created.';
    END IF;

    IF to_regprocedure('public.fn_refresh_dashboard_view(text,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Function public.fn_refresh_dashboard_view was not created.';
    END IF;

    IF to_regprocedure('public.fn_refresh_dashboard(character varying,boolean)') IS NULL THEN
        RAISE EXCEPTION 'Function public.fn_refresh_dashboard was not created.';
    END IF;

    IF to_regprocedure('public.fn_refresh_dashboard_trials(boolean)') IS NULL THEN
        RAISE EXCEPTION 'Function public.fn_refresh_dashboard_trials was not created.';
    END IF;

    IF to_regprocedure('public.fn_refresh_dashboard_evaluations(boolean)') IS NULL THEN
        RAISE EXCEPTION 'Function public.fn_refresh_dashboard_evaluations was not created.';
    END IF;

    IF to_regprocedure('public.fn_refresh_dashboard_recent_activity(boolean)') IS NULL THEN
        RAISE EXCEPTION 'Function public.fn_refresh_dashboard_recent_activity was not created.';
    END IF;

    IF to_regprocedure('public.fn_get_dashboard_refresh_status()') IS NULL THEN
        RAISE EXCEPTION 'Function public.fn_get_dashboard_refresh_status was not created.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.dashboard_refresh_history
        WHERE status = 'SUCCESS'
    ) THEN
        RAISE EXCEPTION 'Initial dashboard refresh did not complete successfully.';
    END IF;

    RAISE NOTICE '0058_dashboard_refresh_functions.sql completed successfully.';
END;
$$;

COMMIT;
