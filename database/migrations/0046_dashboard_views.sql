-- ============================================================
-- AgriTrial Pro
-- Migration: 0046_dashboard_views.sql
-- Purpose: Dashboard and analytics database views
-- ============================================================

BEGIN;

SET search_path = public, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

-- ============================================================
-- DROP PREVIOUS OBJECTS
-- ============================================================

DROP MATERIALIZED VIEW IF EXISTS public.mv_dashboard_monthly_activity CASCADE;

DROP VIEW IF EXISTS public.vw_dashboard_user_activity CASCADE;
DROP VIEW IF EXISTS public.vw_dashboard_crop_performance CASCADE;
DROP VIEW IF EXISTS public.vw_dashboard_pending_reports CASCADE;
DROP VIEW IF EXISTS public.vw_dashboard_recent_evaluations CASCADE;
DROP VIEW IF EXISTS public.vw_dashboard_recent_trials CASCADE;
DROP VIEW IF EXISTS public.vw_dashboard_report_status_counts CASCADE;
DROP VIEW IF EXISTS public.vw_dashboard_evaluation_status_counts CASCADE;
DROP VIEW IF EXISTS public.vw_dashboard_trial_status_counts CASCADE;
DROP VIEW IF EXISTS public.vw_dashboard_summary CASCADE;

DROP FUNCTION IF EXISTS public.fn_refresh_dashboard_materialized_views();

-- ============================================================
-- 1. DASHBOARD SUMMARY
-- ============================================================

CREATE VIEW public.vw_dashboard_summary AS
SELECT
    (
        SELECT COUNT(*)
        FROM public.trials t
        WHERE t.deleted_at IS NULL
    )::bigint AS total_trials,

    (
        SELECT COUNT(*)
        FROM public.trials t
        JOIN public.trial_statuses ts
          ON ts.id = t.status_id
        WHERE t.deleted_at IS NULL
          AND ts.deleted_at IS NULL
          AND ts.is_active = true
          AND ts.is_approval_pending = true
    )::bigint AS pending_approval_trials,

    (
        SELECT COUNT(*)
        FROM public.trials t
        JOIN public.trial_statuses ts
          ON ts.id = t.status_id
        WHERE t.deleted_at IS NULL
          AND ts.deleted_at IS NULL
          AND ts.is_active = true
          AND ts.is_approved = true
    )::bigint AS approved_trials,

    (
        SELECT COUNT(*)
        FROM public.trials t
        JOIN public.trial_statuses ts
          ON ts.id = t.status_id
        WHERE t.deleted_at IS NULL
          AND ts.deleted_at IS NULL
          AND ts.is_active = true
          AND ts.is_rejected = true
    )::bigint AS rejected_trials,

    (
        SELECT COUNT(*)
        FROM public.trials t
        JOIN public.trial_statuses ts
          ON ts.id = t.status_id
        WHERE t.deleted_at IS NULL
          AND ts.deleted_at IS NULL
          AND ts.is_active = true
          AND ts.is_corrections_requested = true
    )::bigint AS corrections_requested_trials,

    (
        SELECT COUNT(*)
        FROM public.trials t
        WHERE t.deleted_at IS NULL
          AND t.completed_at IS NOT NULL
    )::bigint AS completed_trials,

    (
        SELECT COUNT(*)
        FROM public.evaluations e
        WHERE e.deleted_at IS NULL
          AND e.is_active = true
    )::bigint AS total_evaluations,

    (
        SELECT COUNT(*)
        FROM public.evaluations e
        WHERE e.deleted_at IS NULL
          AND e.is_active = true
          AND e.completed_at IS NOT NULL
    )::bigint AS completed_evaluations,

    (
        SELECT COUNT(*)
        FROM public.generated_reports gr
        WHERE gr.deleted_at IS NULL
          AND gr.is_active = true
    )::bigint AS total_reports,

    (
        SELECT COUNT(*)
        FROM public.generated_reports gr
        WHERE gr.deleted_at IS NULL
          AND gr.is_active = true
          AND upper(gr.report_status) IN
              ('PENDING', 'QUEUED', 'PROCESSING', 'GENERATING')
    )::bigint AS pending_reports,

    (
        SELECT COUNT(*)
        FROM public.profiles p
        WHERE p.deleted_at IS NULL
          AND p.is_active = true
    )::bigint AS active_users,

    (
        SELECT COUNT(*)
        FROM public.crops c
        WHERE c.deleted_at IS NULL
          AND c.is_active = true
    )::bigint AS active_crops;

COMMENT ON VIEW public.vw_dashboard_summary IS
'Provides the principal summary counters displayed on the AgriTrial Pro dashboard.';

-- ============================================================
-- 2. TRIAL STATUS COUNTS
-- ============================================================

CREATE VIEW public.vw_dashboard_trial_status_counts AS
SELECT
    ts.id AS status_id,
    ts.code AS status_code,
    ts.name AS status_name,
    ts.workflow_order,
    ts.is_initial,
    ts.is_approval_pending,
    ts.is_approved,
    ts.is_phase_two,
    ts.is_terminal,
    ts.is_rejected,
    ts.is_corrections_requested,
    COUNT(t.id)::bigint AS trial_count
FROM public.trial_statuses ts
LEFT JOIN public.trials t
       ON t.status_id = ts.id
      AND t.deleted_at IS NULL
WHERE ts.deleted_at IS NULL
  AND ts.is_active = true
GROUP BY
    ts.id,
    ts.code,
    ts.name,
    ts.workflow_order,
    ts.is_initial,
    ts.is_approval_pending,
    ts.is_approved,
    ts.is_phase_two,
    ts.is_terminal,
    ts.is_rejected,
    ts.is_corrections_requested;

COMMENT ON VIEW public.vw_dashboard_trial_status_counts IS
'Returns the number of non-deleted trials grouped by workflow status.';

-- ============================================================
-- 3. EVALUATION STATUS COUNTS
-- ============================================================

CREATE VIEW public.vw_dashboard_evaluation_status_counts AS
SELECT
    e.evaluation_status,
    COUNT(*)::bigint AS evaluation_count,
    COUNT(*) FILTER (
        WHERE e.completed_at IS NOT NULL
    )::bigint AS completed_count,
    COUNT(*) FILTER (
        WHERE e.completed_at IS NULL
    )::bigint AS incomplete_count
FROM public.evaluations e
WHERE e.deleted_at IS NULL
  AND e.is_active = true
GROUP BY e.evaluation_status;

COMMENT ON VIEW public.vw_dashboard_evaluation_status_counts IS
'Returns active evaluation totals grouped by evaluation status.';

-- ============================================================
-- 4. REPORT STATUS COUNTS
-- ============================================================

CREATE VIEW public.vw_dashboard_report_status_counts AS
SELECT
    gr.report_status,
    gr.report_format,
    COUNT(*)::bigint AS report_count,
    COUNT(*) FILTER (
        WHERE gr.completed_at IS NOT NULL
    )::bigint AS completed_count,
    COUNT(*) FILTER (
        WHERE gr.error_message IS NOT NULL
    )::bigint AS failed_count
FROM public.generated_reports gr
WHERE gr.deleted_at IS NULL
  AND gr.is_active = true
GROUP BY
    gr.report_status,
    gr.report_format;

COMMENT ON VIEW public.vw_dashboard_report_status_counts IS
'Returns generated report totals grouped by status and output format.';

-- ============================================================
-- 5. RECENT TRIALS
-- ============================================================

CREATE VIEW public.vw_dashboard_recent_trials AS
SELECT
    t.id AS trial_id,
    t.business_id,
    t.variety_name,
    t.installation_method,
    t.planting_date,
    t.sowing_date,
    t.number_of_varieties,
    t.density_per_hectare,
    t.submitted_at,
    t.approved_at,
    t.rejected_at,
    t.corrections_requested_at,
    t.completed_at,
    t.created_at,
    t.updated_at,

    c.id AS crop_id,
    c.code AS crop_code,
    c.name AS crop_name,
    c.emoji AS crop_emoji,

    tt.id AS trial_type_id,
    tt.code AS trial_type_code,
    tt.name AS trial_type_name,
    tt.year_level,

    ts.id AS status_id,
    ts.code AS status_code,
    ts.name AS status_name,
    ts.workflow_order,
    ts.is_approval_pending,
    ts.is_approved,
    ts.is_terminal,

    s.id AS season_id,
    s.code AS season_code,
    s.name AS season_name,

    r.id AS region_id,
    r.name AS region_name,

    pr.id AS province_id,
    pr.name AS province_name,

    g.id AS grower_id,
    g.name AS grower_name,
    g.phone AS grower_phone,

    f.id AS farm_id,
    f.name AS farm_name,

    es.id AS experimental_station_id,
    es.name AS experimental_station_name,

    CASE
        WHEN t.farm_id IS NOT NULL THEN
            concat_ws(
                ' - ',
                g.name,
                f.name
            )
        WHEN t.experimental_station_id IS NOT NULL THEN
            es.name
        ELSE
            NULL
    END AS location_name,

    CASE
        WHEN t.farm_id IS NOT NULL THEN 'GROWER_FARM'
        WHEN t.experimental_station_id IS NOT NULL THEN 'EXPERIMENTAL_STATION'
        ELSE 'UNDEFINED'
    END AS location_type,

    concat_ws(
        ' ',
        creator.first_name,
        creator.last_name
    ) AS created_by_name

FROM public.trials t

JOIN public.crops c
  ON c.id = t.crop_id

JOIN public.trial_types tt
  ON tt.id = t.trial_type_id

JOIN public.trial_statuses ts
  ON ts.id = t.status_id

JOIN public.seasons s
  ON s.id = t.season_id

JOIN public.regions r
  ON r.id = t.region_id

JOIN public.provinces pr
  ON pr.id = t.province_id

LEFT JOIN public.growers g
       ON g.id = t.grower_id

LEFT JOIN public.farms f
       ON f.id = t.farm_id

LEFT JOIN public.experimental_stations es
       ON es.id = t.experimental_station_id

LEFT JOIN public.profiles creator
       ON creator.user_id = t.created_by
      AND creator.deleted_at IS NULL

WHERE t.deleted_at IS NULL;

COMMENT ON VIEW public.vw_dashboard_recent_trials IS
'Provides dashboard-ready trial information including crop, workflow, season, location, and creator details.';

-- ============================================================
-- 6. RECENT EVALUATIONS
-- ============================================================

CREATE VIEW public.vw_dashboard_recent_evaluations AS
SELECT
    e.id AS evaluation_id,
    e.trial_id,
    e.trial_variety_id,
    e.evaluation_number,
    e.evaluation_date,
    e.title AS evaluation_title,
    e.evaluation_status,
    e.completed_at,
    e.created_at,
    e.updated_at,

    et.id AS evaluation_type_id,
    et.code AS evaluation_type_code,
    et.name AS evaluation_type_name,

    t.business_id,
    t.variety_name AS trial_variety_name,

    c.id AS crop_id,
    c.code AS crop_code,
    c.name AS crop_name,
    c.emoji AS crop_emoji,

    tv.variety_name AS evaluated_variety_name,
    tv.variety_role,
    tv.is_primary AS is_primary_variety,
    tv.is_leader AS is_leader_variety,

    e.evaluator_id,

    concat_ws(
        ' ',
        evaluator.first_name,
        evaluator.last_name
    ) AS evaluator_name,

    evaluator.employee_code AS evaluator_employee_code,

    (
        SELECT COUNT(*)
        FROM public.evaluation_details ed
        WHERE ed.evaluation_id = e.id
          AND ed.deleted_at IS NULL
          AND ed.is_active = true
    )::bigint AS detail_count,

    (
        SELECT COUNT(*)
        FROM public.evaluation_photos ep
        WHERE ep.evaluation_id = e.id
          AND ep.deleted_at IS NULL
          AND ep.is_active = true
    )::bigint AS photo_count

FROM public.evaluations e

JOIN public.trials t
  ON t.id = e.trial_id
 AND t.deleted_at IS NULL

JOIN public.crops c
  ON c.id = t.crop_id

JOIN public.evaluation_types et
  ON et.id = e.evaluation_type_id

LEFT JOIN public.trial_varieties tv
       ON tv.id = e.trial_variety_id
      AND tv.deleted_at IS NULL
      AND tv.is_active = true

LEFT JOIN public.profiles evaluator
       ON evaluator.user_id = e.evaluator_id
      AND evaluator.deleted_at IS NULL

WHERE e.deleted_at IS NULL
  AND e.is_active = true;

COMMENT ON VIEW public.vw_dashboard_recent_evaluations IS
'Provides dashboard-ready evaluation information with trial, crop, evaluator, detail, and photo statistics.';

-- ============================================================
-- 7. PENDING REPORTS
-- ============================================================

CREATE VIEW public.vw_dashboard_pending_reports AS
SELECT
    gr.id AS report_id,
    gr.report_number,
    gr.report_name,
    gr.report_scope,
    gr.report_format,
    gr.report_status,
    gr.language_code,
    gr.include_photos,
    gr.requested_at,
    gr.processing_started_at,
    gr.completed_at,
    gr.expires_at,
    gr.error_message,
    gr.trial_id,
    gr.evaluation_id,
    gr.season_id,
    gr.crop_id,
    gr.requested_by,

    concat_ws(
        ' ',
        requester.first_name,
        requester.last_name
    ) AS requested_by_name,

    requester.employee_code AS requested_by_employee_code,

    CASE
        WHEN gr.processing_started_at IS NOT NULL THEN
            EXTRACT(
                EPOCH FROM (
                    CURRENT_TIMESTAMP - gr.processing_started_at
                )
            )::bigint
        ELSE
            EXTRACT(
                EPOCH FROM (
                    CURRENT_TIMESTAMP - gr.requested_at
                )
            )::bigint
    END AS waiting_seconds

FROM public.generated_reports gr

LEFT JOIN public.profiles requester
       ON requester.user_id = gr.requested_by
      AND requester.deleted_at IS NULL

WHERE gr.deleted_at IS NULL
  AND gr.is_active = true
  AND upper(gr.report_status) IN
      ('PENDING', 'QUEUED', 'PROCESSING', 'GENERATING');

COMMENT ON VIEW public.vw_dashboard_pending_reports IS
'Lists reports currently waiting for generation or being processed.';

-- ============================================================
-- 8. CROP PERFORMANCE
-- ============================================================

CREATE VIEW public.vw_dashboard_crop_performance AS
SELECT
    c.id AS crop_id,
    c.code AS crop_code,
    c.name AS crop_name,
    c.emoji AS crop_emoji,

    COUNT(DISTINCT t.id)::bigint AS total_trials,

    COUNT(DISTINCT t.id) FILTER (
        WHERE ts.is_approval_pending = true
    )::bigint AS pending_approval_trials,

    COUNT(DISTINCT t.id) FILTER (
        WHERE ts.is_approved = true
    )::bigint AS approved_trials,

    COUNT(DISTINCT t.id) FILTER (
        WHERE ts.is_rejected = true
    )::bigint AS rejected_trials,

    COUNT(DISTINCT t.id) FILTER (
        WHERE t.completed_at IS NOT NULL
    )::bigint AS completed_trials,

    COUNT(DISTINCT e.id)::bigint AS total_evaluations,

    COUNT(DISTINCT e.id) FILTER (
        WHERE e.completed_at IS NOT NULL
    )::bigint AS completed_evaluations,

    COUNT(DISTINCT tv.id)::bigint AS total_trial_varieties,

    COUNT(DISTINCT tv.id) FILTER (
        WHERE tv.is_leader = true
    )::bigint AS leader_varieties,

    MAX(t.created_at) AS latest_trial_created_at,
    MAX(e.evaluation_date) AS latest_evaluation_date

FROM public.crops c

LEFT JOIN public.trials t
       ON t.crop_id = c.id
      AND t.deleted_at IS NULL

LEFT JOIN public.trial_statuses ts
       ON ts.id = t.status_id
      AND ts.deleted_at IS NULL
      AND ts.is_active = true

LEFT JOIN public.evaluations e
       ON e.trial_id = t.id
      AND e.deleted_at IS NULL
      AND e.is_active = true

LEFT JOIN public.trial_varieties tv
       ON tv.trial_id = t.id
      AND tv.deleted_at IS NULL
      AND tv.is_active = true

WHERE c.deleted_at IS NULL
  AND c.is_active = true

GROUP BY
    c.id,
    c.code,
    c.name,
    c.emoji;

COMMENT ON VIEW public.vw_dashboard_crop_performance IS
'Provides trial, evaluation, and variety activity statistics grouped by crop.';

-- ============================================================
-- 9. USER ACTIVITY
-- ============================================================

CREATE VIEW public.vw_dashboard_user_activity AS
SELECT
    p.id AS profile_id,
    p.user_id,
    p.employee_code,
    p.first_name,
    p.last_name,
    concat_ws(' ', p.first_name, p.last_name) AS full_name,
    p.is_active,

    r.id AS role_id,
    r.code AS role_code,
    r.name AS role_name,

    COUNT(DISTINCT t.id)::bigint AS trials_created,
    COUNT(DISTINCT e.id)::bigint AS evaluations_created,
    COUNT(DISTINCT gr.id)::bigint AS reports_requested,

    GREATEST(
        MAX(t.created_at),
        MAX(e.created_at),
        MAX(gr.requested_at),
        p.last_login_at
    ) AS last_activity_at

FROM public.profiles p

JOIN public.roles r
  ON r.id = p.role_id

LEFT JOIN public.trials t
       ON t.created_by = p.user_id
      AND t.deleted_at IS NULL

LEFT JOIN public.evaluations e
       ON e.created_by = p.user_id
      AND e.deleted_at IS NULL
      AND e.is_active = true

LEFT JOIN public.generated_reports gr
       ON gr.requested_by = p.user_id
      AND gr.deleted_at IS NULL
      AND gr.is_active = true

WHERE p.deleted_at IS NULL
  AND r.deleted_at IS NULL

GROUP BY
    p.id,
    p.user_id,
    p.employee_code,
    p.first_name,
    p.last_name,
    p.is_active,
    p.last_login_at,
    r.id,
    r.code,
    r.name;

COMMENT ON VIEW public.vw_dashboard_user_activity IS
'Provides activity statistics for each AgriTrial Pro user.';

-- ============================================================
-- 10. MONTHLY ACTIVITY MATERIALIZED VIEW
-- ============================================================

CREATE MATERIALIZED VIEW public.mv_dashboard_monthly_activity AS
WITH months AS (
    SELECT
        generate_series(
            date_trunc(
                'month',
                CURRENT_DATE - INTERVAL '11 months'
            ),
            date_trunc(
                'month',
                CURRENT_DATE
            ),
            INTERVAL '1 month'
        )::date AS month_start
),

trial_activity AS (
    SELECT
        date_trunc('month', t.created_at)::date AS month_start,
        COUNT(*)::bigint AS activity_count
    FROM public.trials t
    WHERE t.deleted_at IS NULL
      AND t.created_at >= date_trunc(
          'month',
          CURRENT_DATE - INTERVAL '11 months'
      )
    GROUP BY date_trunc('month', t.created_at)::date
),

evaluation_activity AS (
    SELECT
        date_trunc('month', e.created_at)::date AS month_start,
        COUNT(*)::bigint AS activity_count
    FROM public.evaluations e
    WHERE e.deleted_at IS NULL
      AND e.is_active = true
      AND e.created_at >= date_trunc(
          'month',
          CURRENT_DATE - INTERVAL '11 months'
      )
    GROUP BY date_trunc('month', e.created_at)::date
),

report_activity AS (
    SELECT
        date_trunc('month', gr.requested_at)::date AS month_start,
        COUNT(*)::bigint AS activity_count
    FROM public.generated_reports gr
    WHERE gr.deleted_at IS NULL
      AND gr.is_active = true
      AND gr.requested_at >= date_trunc(
          'month',
          CURRENT_DATE - INTERVAL '11 months'
      )
    GROUP BY date_trunc('month', gr.requested_at)::date
)

SELECT
    m.month_start,
    to_char(m.month_start, 'YYYY-MM') AS month_code,
    to_char(m.month_start, 'Mon YYYY') AS month_label,

    COALESCE(ta.activity_count, 0)::bigint AS trials_created,
    COALESCE(ea.activity_count, 0)::bigint AS evaluations_created,
    COALESCE(ra.activity_count, 0)::bigint AS reports_requested,

    (
        COALESCE(ta.activity_count, 0)
        + COALESCE(ea.activity_count, 0)
        + COALESCE(ra.activity_count, 0)
    )::bigint AS total_activity

FROM months m

LEFT JOIN trial_activity ta
       ON ta.month_start = m.month_start

LEFT JOIN evaluation_activity ea
       ON ea.month_start = m.month_start

LEFT JOIN report_activity ra
       ON ra.month_start = m.month_start

ORDER BY m.month_start

WITH DATA;

COMMENT ON MATERIALIZED VIEW public.mv_dashboard_monthly_activity IS
'Stores the previous twelve months of trial, evaluation, and report activity for dashboard charts.';

CREATE UNIQUE INDEX uq_mv_dashboard_monthly_activity_month
    ON public.mv_dashboard_monthly_activity (month_start);

-- ============================================================
-- 11. MATERIALIZED VIEW REFRESH FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_refresh_dashboard_materialized_views()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, extensions
AS $$
BEGIN
    REFRESH MATERIALIZED VIEW
        public.mv_dashboard_monthly_activity;
END;
$$;

COMMENT ON FUNCTION public.fn_refresh_dashboard_materialized_views() IS
'Refreshes all AgriTrial Pro dashboard materialized views.';

-- ============================================================
-- 12. PERMISSIONS
-- ============================================================

GRANT SELECT
ON
    public.vw_dashboard_summary,
    public.vw_dashboard_trial_status_counts,
    public.vw_dashboard_evaluation_status_counts,
    public.vw_dashboard_report_status_counts,
    public.vw_dashboard_recent_trials,
    public.vw_dashboard_recent_evaluations,
    public.vw_dashboard_pending_reports,
    public.vw_dashboard_crop_performance,
    public.vw_dashboard_user_activity,
    public.mv_dashboard_monthly_activity
TO authenticated;

GRANT SELECT
ON
    public.vw_dashboard_summary,
    public.vw_dashboard_trial_status_counts,
    public.vw_dashboard_evaluation_status_counts,
    public.vw_dashboard_report_status_counts,
    public.vw_dashboard_recent_trials,
    public.vw_dashboard_recent_evaluations,
    public.vw_dashboard_pending_reports,
    public.vw_dashboard_crop_performance,
    public.vw_dashboard_user_activity,
    public.mv_dashboard_monthly_activity
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_refresh_dashboard_materialized_views()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_refresh_dashboard_materialized_views()
TO service_role;

-- ============================================================
-- 13. MIGRATION VALIDATION
-- ============================================================

DO $$
DECLARE
    v_missing_objects text[];
BEGIN
    SELECT array_agg(required_object)
    INTO v_missing_objects
    FROM (
        VALUES
            ('vw_dashboard_summary'),
            ('vw_dashboard_trial_status_counts'),
            ('vw_dashboard_evaluation_status_counts'),
            ('vw_dashboard_report_status_counts'),
            ('vw_dashboard_recent_trials'),
            ('vw_dashboard_recent_evaluations'),
            ('vw_dashboard_pending_reports'),
            ('vw_dashboard_crop_performance'),
            ('vw_dashboard_user_activity'),
            ('mv_dashboard_monthly_activity')
    ) AS required(required_object)
    WHERE NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n
          ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relname = required.required_object
          AND c.relkind IN ('v', 'm')
    );

    IF v_missing_objects IS NOT NULL THEN
        RAISE EXCEPTION
            'Dashboard migration validation failed. Missing objects: %',
            array_to_string(v_missing_objects, ', ');
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n
          ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname =
              'fn_refresh_dashboard_materialized_views'
    ) THEN
        RAISE EXCEPTION
            'Dashboard refresh function was not created.';
    END IF;

    RAISE NOTICE
        '0046_dashboard_views.sql completed successfully.';
END;
$$;

COMMIT;
