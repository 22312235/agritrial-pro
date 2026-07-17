
-- AgriTrial Pro
-- Migration: 0057_dashboard_materialized_views.sql
-- Purpose: Create dashboard materialized views for trials, approvals, evaluations, and recent activity.

BEGIN;

SET search_path = public, auth, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

DO $$
BEGIN
    IF to_regclass('public.trials') IS NULL THEN
        RAISE EXCEPTION 'Required table public.trials does not exist.';
    END IF;

    IF to_regclass('public.evaluations') IS NULL THEN
        RAISE EXCEPTION 'Required table public.evaluations does not exist.';
    END IF;
END;
$$;

DROP MATERIALIZED VIEW IF EXISTS public.mv_dashboard_recent_activity;
DROP MATERIALIZED VIEW IF EXISTS public.mv_dashboard_evaluations_by_type;
DROP MATERIALIZED VIEW IF EXISTS public.mv_dashboard_evaluation_kpis;
DROP MATERIALIZED VIEW IF EXISTS public.mv_dashboard_trials_by_region;
DROP MATERIALIZED VIEW IF EXISTS public.mv_dashboard_trials_by_trial_type;
DROP MATERIALIZED VIEW IF EXISTS public.mv_dashboard_trials_by_crop;
DROP MATERIALIZED VIEW IF EXISTS public.mv_dashboard_trials_by_status;
DROP MATERIALIZED VIEW IF EXISTS public.mv_dashboard_trial_kpis;

DO $$
DECLARE
    v_trial_deleted_filter text;
    v_trial_active_filter text;
    v_eval_deleted_filter text;
    v_eval_active_filter text;
    v_trial_status_expr text;
    v_trial_status_join text;
    v_trial_crop_expr text;
    v_trial_crop_join text;
    v_trial_type_expr text;
    v_trial_type_join text;
    v_trial_region_expr text;
    v_trial_region_join text;
    v_trial_created_expr text;
    v_trial_updated_expr text;
    v_trial_approved_expr text;
    v_trial_rejected_expr text;
    v_trial_pending_expr text;
    v_trial_corrections_expr text;
    v_eval_type_expr text;
    v_eval_type_join text;
    v_eval_date_expr text;
    v_eval_created_expr text;
    v_eval_completed_expr text;
BEGIN
    v_trial_deleted_filter :=
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'trials'
                  AND column_name = 'deleted_at'
            )
            THEN 't.deleted_at IS NULL'
            ELSE 'TRUE'
        END;

    v_trial_active_filter :=
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'trials'
                  AND column_name = 'is_active'
            )
            THEN 'COALESCE(t.is_active, TRUE) = TRUE'
            ELSE 'TRUE'
        END;

    v_eval_deleted_filter :=
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'evaluations'
                  AND column_name = 'deleted_at'
            )
            THEN 'e.deleted_at IS NULL'
            ELSE 'TRUE'
        END;

    v_eval_active_filter :=
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'evaluations'
                  AND column_name = 'is_active'
            )
            THEN 'COALESCE(e.is_active, TRUE) = TRUE'
            ELSE 'TRUE'
        END;

    v_trial_created_expr :=
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'trials'
                  AND column_name = 'created_at'
            )
            THEN 't.created_at'
            ELSE 'NULL::timestamptz'
        END;

    v_trial_updated_expr :=
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'trials'
                  AND column_name = 'updated_at'
            )
            THEN 't.updated_at'
            ELSE v_trial_created_expr
        END;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'trials'
          AND column_name = 'status_id'
    ) AND to_regclass('public.trial_statuses') IS NOT NULL THEN
        v_trial_status_join := 'LEFT JOIN public.trial_statuses ts ON ts.id = t.status_id';
        v_trial_status_expr := 'COALESCE(ts.code::text, ts.name::text, t.status_id::text, ''UNKNOWN'')';
    ELSIF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'trials'
          AND column_name = 'status'
    ) THEN
        v_trial_status_join := '';
        v_trial_status_expr := 'COALESCE(t.status::text, ''UNKNOWN'')';
    ELSE
        v_trial_status_join := '';
        v_trial_status_expr := '''UNKNOWN''::text';
    END IF;

    v_trial_pending_expr :=
        format(
            'upper(%s) IN (''PENDING_APPROVAL'', ''PENDING'', ''SUBMITTED'')',
            v_trial_status_expr
        );

    v_trial_approved_expr :=
        format(
            'upper(%s) = ''APPROVED''',
            v_trial_status_expr
        );

    v_trial_rejected_expr :=
        format(
            'upper(%s) = ''REJECTED''',
            v_trial_status_expr
        );

    v_trial_corrections_expr :=
        format(
            'upper(%s) IN (''CORRECTIONS_REQUESTED'', ''CORRECTION_REQUESTED'', ''NEEDS_CORRECTION'')',
            v_trial_status_expr
        );

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'trials'
          AND column_name = 'crop_id'
    ) AND to_regclass('public.crops') IS NOT NULL THEN
        v_trial_crop_join := 'LEFT JOIN public.crops c ON c.id = t.crop_id';
        v_trial_crop_expr := 'COALESCE(c.name::text, c.code::text, t.crop_id::text, ''UNKNOWN'')';
    ELSE
        v_trial_crop_join := '';
        v_trial_crop_expr := '''UNKNOWN''::text';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'trials'
          AND column_name = 'trial_type_id'
    ) AND to_regclass('public.trial_types') IS NOT NULL THEN
        v_trial_type_join := 'LEFT JOIN public.trial_types tt ON tt.id = t.trial_type_id';
        v_trial_type_expr := 'COALESCE(tt.name::text, tt.code::text, t.trial_type_id::text, ''UNKNOWN'')';
    ELSE
        v_trial_type_join := '';
        v_trial_type_expr := '''UNKNOWN''::text';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'trials'
          AND column_name = 'region_id'
    ) AND to_regclass('public.regions') IS NOT NULL THEN
        v_trial_region_join := 'LEFT JOIN public.regions r ON r.id = t.region_id';
        v_trial_region_expr := 'COALESCE(r.name::text, r.code::text, t.region_id::text, ''UNKNOWN'')';
    ELSIF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'trials'
          AND column_name = 'province_id'
    ) AND to_regclass('public.provinces') IS NOT NULL
       AND to_regclass('public.regions') IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM information_schema.columns
            WHERE table_schema = 'public'
              AND table_name = 'provinces'
              AND column_name = 'region_id'
       ) THEN
        v_trial_region_join :=
            'LEFT JOIN public.provinces p ON p.id = t.province_id
             LEFT JOIN public.regions r ON r.id = p.region_id';
        v_trial_region_expr := 'COALESCE(r.name::text, r.code::text, p.region_id::text, ''UNKNOWN'')';
    ELSE
        v_trial_region_join := '';
        v_trial_region_expr := '''UNKNOWN''::text';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'evaluations'
          AND column_name = 'evaluation_type_id'
    ) AND to_regclass('public.evaluation_types') IS NOT NULL THEN
        v_eval_type_join := 'LEFT JOIN public.evaluation_types et ON et.id = e.evaluation_type_id';
        v_eval_type_expr := 'COALESCE(et.code::text, et.name::text, e.evaluation_type_id::text, ''UNKNOWN'')';
    ELSIF EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'evaluations'
          AND column_name = 'evaluation_type'
    ) THEN
        v_eval_type_join := '';
        v_eval_type_expr := 'COALESCE(e.evaluation_type::text, ''UNKNOWN'')';
    ELSE
        v_eval_type_join := '';
        v_eval_type_expr := '''UNKNOWN''::text';
    END IF;

    v_eval_date_expr :=
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'evaluations'
                  AND column_name = 'evaluation_date'
            )
            THEN 'e.evaluation_date::date'
            WHEN EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'evaluations'
                  AND column_name = 'created_at'
            )
            THEN 'e.created_at::date'
            ELSE 'NULL::date'
        END;

    v_eval_created_expr :=
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'evaluations'
                  AND column_name = 'created_at'
            )
            THEN 'e.created_at'
            ELSE 'NULL::timestamptz'
        END;

    v_eval_completed_expr :=
        CASE
            WHEN EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'evaluations'
                  AND column_name = 'completed_at'
            )
            THEN 'e.completed_at IS NOT NULL'
            WHEN EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_schema = 'public'
                  AND table_name = 'evaluations'
                  AND column_name = 'status'
            )
            THEN 'upper(e.status::text) IN (''COMPLETED'', ''FINALIZED'', ''SUBMITTED'')'
            ELSE 'TRUE'
        END;

    EXECUTE format(
        $sql$
        CREATE MATERIALIZED VIEW public.mv_dashboard_trial_kpis AS
        SELECT
            1::smallint AS row_id,
            count(*)::bigint AS total_trials,
            count(*) FILTER (WHERE %1$s)::bigint AS pending_approval_trials,
            count(*) FILTER (WHERE %2$s)::bigint AS approved_trials,
            count(*) FILTER (WHERE %3$s)::bigint AS rejected_trials,
            count(*) FILTER (WHERE %4$s)::bigint AS corrections_requested_trials,
            count(*) FILTER (
                WHERE %5$s >= date_trunc('month', now())
            )::bigint AS trials_created_this_month,
            count(*) FILTER (
                WHERE %5$s >= date_trunc('year', now())
            )::bigint AS trials_created_this_year,
            max(%5$s) AS latest_trial_created_at,
            now() AS refreshed_at
        FROM public.trials t
        %6$s
        WHERE %7$s
          AND %8$s
        WITH NO DATA
        $sql$,
        v_trial_pending_expr,
        v_trial_approved_expr,
        v_trial_rejected_expr,
        v_trial_corrections_expr,
        v_trial_created_expr,
        v_trial_status_join,
        v_trial_deleted_filter,
        v_trial_active_filter
    );

    EXECUTE format(
        $sql$
        CREATE MATERIALIZED VIEW public.mv_dashboard_trials_by_status AS
        SELECT
            md5(%1$s)::text AS row_id,
            %1$s AS status_key,
            count(*)::bigint AS trial_count,
            round(
                count(*)::numeric * 100.0
                / NULLIF(sum(count(*)) OVER (), 0),
                2
            ) AS percentage_of_trials,
            max(%2$s) AS latest_trial_created_at,
            now() AS refreshed_at
        FROM public.trials t
        %3$s
        WHERE %4$s
          AND %5$s
        GROUP BY %1$s
        WITH NO DATA
        $sql$,
        v_trial_status_expr,
        v_trial_created_expr,
        v_trial_status_join,
        v_trial_deleted_filter,
        v_trial_active_filter
    );

    EXECUTE format(
        $sql$
        CREATE MATERIALIZED VIEW public.mv_dashboard_trials_by_crop AS
        SELECT
            md5(%1$s)::text AS row_id,
            %1$s AS crop_key,
            count(*)::bigint AS trial_count,
            count(*) FILTER (WHERE %2$s)::bigint AS approved_trials,
            count(*) FILTER (WHERE %3$s)::bigint AS pending_approval_trials,
            max(%4$s) AS latest_trial_created_at,
            now() AS refreshed_at
        FROM public.trials t
        %5$s
        %6$s
        WHERE %7$s
          AND %8$s
        GROUP BY %1$s
        WITH NO DATA
        $sql$,
        v_trial_crop_expr,
        v_trial_approved_expr,
        v_trial_pending_expr,
        v_trial_created_expr,
        v_trial_crop_join,
        v_trial_status_join,
        v_trial_deleted_filter,
        v_trial_active_filter
    );

    EXECUTE format(
        $sql$
        CREATE MATERIALIZED VIEW public.mv_dashboard_trials_by_trial_type AS
        SELECT
            md5(%1$s)::text AS row_id,
            %1$s AS trial_type_key,
            count(*)::bigint AS trial_count,
            count(*) FILTER (WHERE %2$s)::bigint AS approved_trials,
            count(*) FILTER (WHERE %3$s)::bigint AS pending_approval_trials,
            max(%4$s) AS latest_trial_created_at,
            now() AS refreshed_at
        FROM public.trials t
        %5$s
        %6$s
        WHERE %7$s
          AND %8$s
        GROUP BY %1$s
        WITH NO DATA
        $sql$,
        v_trial_type_expr,
        v_trial_approved_expr,
        v_trial_pending_expr,
        v_trial_created_expr,
        v_trial_type_join,
        v_trial_status_join,
        v_trial_deleted_filter,
        v_trial_active_filter
    );

    EXECUTE format(
        $sql$
        CREATE MATERIALIZED VIEW public.mv_dashboard_trials_by_region AS
        SELECT
            md5(%1$s)::text AS row_id,
            %1$s AS region_key,
            count(*)::bigint AS trial_count,
            count(*) FILTER (WHERE %2$s)::bigint AS approved_trials,
            count(*) FILTER (WHERE %3$s)::bigint AS pending_approval_trials,
            max(%4$s) AS latest_trial_created_at,
            now() AS refreshed_at
        FROM public.trials t
        %5$s
        %6$s
        WHERE %7$s
          AND %8$s
        GROUP BY %1$s
        WITH NO DATA
        $sql$,
        v_trial_region_expr,
        v_trial_approved_expr,
        v_trial_pending_expr,
        v_trial_created_expr,
        v_trial_region_join,
        v_trial_status_join,
        v_trial_deleted_filter,
        v_trial_active_filter
    );

    EXECUTE format(
        $sql$
        CREATE MATERIALIZED VIEW public.mv_dashboard_evaluation_kpis AS
        SELECT
            1::smallint AS row_id,
            count(*)::bigint AS total_evaluations,
            count(*) FILTER (WHERE %1$s)::bigint AS completed_evaluations,
            count(*) FILTER (
                WHERE %2$s >= date_trunc('month', now())::date
            )::bigint AS evaluations_this_month,
            count(*) FILTER (
                WHERE %2$s >= date_trunc('year', now())::date
            )::bigint AS evaluations_this_year,
            count(DISTINCT e.trial_id)::bigint AS evaluated_trials,
            max(%3$s) AS latest_evaluation_created_at,
            now() AS refreshed_at
        FROM public.evaluations e
        WHERE %4$s
          AND %5$s
        WITH NO DATA
        $sql$,
        v_eval_completed_expr,
        v_eval_date_expr,
        v_eval_created_expr,
        v_eval_deleted_filter,
        v_eval_active_filter
    );

    EXECUTE format(
        $sql$
        CREATE MATERIALIZED VIEW public.mv_dashboard_evaluations_by_type AS
        SELECT
            md5(%1$s)::text AS row_id,
            %1$s AS evaluation_type_key,
            count(*)::bigint AS evaluation_count,
            count(*) FILTER (WHERE %2$s)::bigint AS completed_evaluations,
            count(DISTINCT e.trial_id)::bigint AS evaluated_trials,
            max(%3$s) AS latest_evaluation_created_at,
            now() AS refreshed_at
        FROM public.evaluations e
        %4$s
        WHERE %5$s
          AND %6$s
        GROUP BY %1$s
        WITH NO DATA
        $sql$,
        v_eval_type_expr,
        v_eval_completed_expr,
        v_eval_created_expr,
        v_eval_type_join,
        v_eval_deleted_filter,
        v_eval_active_filter
    );

    EXECUTE format(
        $sql$
        CREATE MATERIALIZED VIEW public.mv_dashboard_recent_activity AS
        SELECT
            activity_id,
            activity_type,
            entity_id,
            title,
            activity_at
        FROM (
            SELECT
                'TRIAL:' || t.id::text AS activity_id,
                'TRIAL'::text AS activity_type,
                t.id AS entity_id,
                'Trial created'::text AS title,
                %1$s AS activity_at
            FROM public.trials t
            WHERE %2$s
              AND %3$s

            UNION ALL

            SELECT
                'EVALUATION:' || e.id::text AS activity_id,
                'EVALUATION'::text AS activity_type,
                e.id AS entity_id,
                'Evaluation created'::text AS title,
                %4$s AS activity_at
            FROM public.evaluations e
            WHERE %5$s
              AND %6$s
        ) activity
        WHERE activity_at IS NOT NULL
        ORDER BY activity_at DESC
        LIMIT 250
        WITH NO DATA
        $sql$,
        v_trial_updated_expr,
        v_trial_deleted_filter,
        v_trial_active_filter,
        v_eval_created_expr,
        v_eval_deleted_filter,
        v_eval_active_filter
    );
END;
$$;

CREATE UNIQUE INDEX uq_mv_dashboard_trial_kpis
ON public.mv_dashboard_trial_kpis(row_id);

CREATE UNIQUE INDEX uq_mv_dashboard_trials_by_status
ON public.mv_dashboard_trials_by_status(row_id);

CREATE UNIQUE INDEX uq_mv_dashboard_trials_by_crop
ON public.mv_dashboard_trials_by_crop(row_id);

CREATE UNIQUE INDEX uq_mv_dashboard_trials_by_trial_type
ON public.mv_dashboard_trials_by_trial_type(row_id);

CREATE UNIQUE INDEX uq_mv_dashboard_trials_by_region
ON public.mv_dashboard_trials_by_region(row_id);

CREATE UNIQUE INDEX uq_mv_dashboard_evaluation_kpis
ON public.mv_dashboard_evaluation_kpis(row_id);

CREATE UNIQUE INDEX uq_mv_dashboard_evaluations_by_type
ON public.mv_dashboard_evaluations_by_type(row_id);

CREATE UNIQUE INDEX uq_mv_dashboard_recent_activity
ON public.mv_dashboard_recent_activity(activity_id);

CREATE INDEX idx_mv_dashboard_recent_activity_at
ON public.mv_dashboard_recent_activity(activity_at DESC);

COMMENT ON MATERIALIZED VIEW public.mv_dashboard_trial_kpis IS
'Single-row summary of trial dashboard indicators.';

COMMENT ON MATERIALIZED VIEW public.mv_dashboard_trials_by_status IS
'Trial counts and percentages grouped by workflow status.';

COMMENT ON MATERIALIZED VIEW public.mv_dashboard_trials_by_crop IS
'Trial counts grouped by crop.';

COMMENT ON MATERIALIZED VIEW public.mv_dashboard_trials_by_trial_type IS
'Trial counts grouped by trial type.';

COMMENT ON MATERIALIZED VIEW public.mv_dashboard_trials_by_region IS
'Trial counts grouped by region.';

COMMENT ON MATERIALIZED VIEW public.mv_dashboard_evaluation_kpis IS
'Single-row summary of evaluation dashboard indicators.';

COMMENT ON MATERIALIZED VIEW public.mv_dashboard_evaluations_by_type IS
'Evaluation counts grouped by evaluation type.';

COMMENT ON MATERIALIZED VIEW public.mv_dashboard_recent_activity IS
'Most recent trial and evaluation activity for dashboard display.';

REVOKE ALL ON TABLE public.mv_dashboard_trial_kpis FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.mv_dashboard_trials_by_status FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.mv_dashboard_trials_by_crop FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.mv_dashboard_trials_by_trial_type FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.mv_dashboard_trials_by_region FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.mv_dashboard_evaluation_kpis FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.mv_dashboard_evaluations_by_type FROM PUBLIC, anon;
REVOKE ALL ON TABLE public.mv_dashboard_recent_activity FROM PUBLIC, anon;

GRANT SELECT ON TABLE public.mv_dashboard_trial_kpis TO authenticated, service_role;
GRANT SELECT ON TABLE public.mv_dashboard_trials_by_status TO authenticated, service_role;
GRANT SELECT ON TABLE public.mv_dashboard_trials_by_crop TO authenticated, service_role;
GRANT SELECT ON TABLE public.mv_dashboard_trials_by_trial_type TO authenticated, service_role;
GRANT SELECT ON TABLE public.mv_dashboard_trials_by_region TO authenticated, service_role;
GRANT SELECT ON TABLE public.mv_dashboard_evaluation_kpis TO authenticated, service_role;
GRANT SELECT ON TABLE public.mv_dashboard_evaluations_by_type TO authenticated, service_role;
GRANT SELECT ON TABLE public.mv_dashboard_recent_activity TO authenticated, service_role;

REFRESH MATERIALIZED VIEW public.mv_dashboard_trial_kpis;
REFRESH MATERIALIZED VIEW public.mv_dashboard_trials_by_status;
REFRESH MATERIALIZED VIEW public.mv_dashboard_trials_by_crop;
REFRESH MATERIALIZED VIEW public.mv_dashboard_trials_by_trial_type;
REFRESH MATERIALIZED VIEW public.mv_dashboard_trials_by_region;
REFRESH MATERIALIZED VIEW public.mv_dashboard_evaluation_kpis;
REFRESH MATERIALIZED VIEW public.mv_dashboard_evaluations_by_type;
REFRESH MATERIALIZED VIEW public.mv_dashboard_recent_activity;

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
            57,
            '0057_dashboard_materialized_views.sql'
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
    IF to_regclass('public.mv_dashboard_trial_kpis') IS NULL THEN
        RAISE EXCEPTION 'Materialized view mv_dashboard_trial_kpis was not created.';
    END IF;

    IF to_regclass('public.mv_dashboard_trials_by_status') IS NULL THEN
        RAISE EXCEPTION 'Materialized view mv_dashboard_trials_by_status was not created.';
    END IF;

    IF to_regclass('public.mv_dashboard_trials_by_crop') IS NULL THEN
        RAISE EXCEPTION 'Materialized view mv_dashboard_trials_by_crop was not created.';
    END IF;

    IF to_regclass('public.mv_dashboard_trials_by_trial_type') IS NULL THEN
        RAISE EXCEPTION 'Materialized view mv_dashboard_trials_by_trial_type was not created.';
    END IF;

    IF to_regclass('public.mv_dashboard_trials_by_region') IS NULL THEN
        RAISE EXCEPTION 'Materialized view mv_dashboard_trials_by_region was not created.';
    END IF;

    IF to_regclass('public.mv_dashboard_evaluation_kpis') IS NULL THEN
        RAISE EXCEPTION 'Materialized view mv_dashboard_evaluation_kpis was not created.';
    END IF;

    IF to_regclass('public.mv_dashboard_evaluations_by_type') IS NULL THEN
        RAISE EXCEPTION 'Materialized view mv_dashboard_evaluations_by_type was not created.';
    END IF;

    IF to_regclass('public.mv_dashboard_recent_activity') IS NULL THEN
        RAISE EXCEPTION 'Materialized view mv_dashboard_recent_activity was not created.';
    END IF;

    RAISE NOTICE '0057_dashboard_materialized_views.sql completed successfully.';
END;
$$;

COMMIT;
