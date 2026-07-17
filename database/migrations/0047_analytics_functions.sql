-- ============================================================
-- AgriTrial Pro
-- Migration: 0047_analytics_functions.sql
-- Purpose: Analytics and reporting functions
-- ============================================================

BEGIN;

SET search_path = public, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

-- ============================================================
-- DROP PREVIOUS FUNCTIONS
-- ============================================================

DROP FUNCTION IF EXISTS public.fn_analytics_overview(
    date,
    date,
    uuid,
    uuid,
    uuid,
    uuid
);

DROP FUNCTION IF EXISTS public.fn_analytics_trials_by_crop(
    date,
    date,
    uuid
);

DROP FUNCTION IF EXISTS public.fn_analytics_trials_by_region(
    date,
    date,
    uuid,
    uuid
);

DROP FUNCTION IF EXISTS public.fn_analytics_trials_by_status(
    date,
    date,
    uuid,
    uuid
);

DROP FUNCTION IF EXISTS public.fn_analytics_evaluations_by_type(
    date,
    date,
    uuid,
    uuid
);

DROP FUNCTION IF EXISTS public.fn_analytics_variety_performance(
    date,
    date,
    uuid,
    uuid,
    integer
);

DROP FUNCTION IF EXISTS public.fn_analytics_monthly_activity(
    date,
    date,
    uuid,
    uuid
);

DROP FUNCTION IF EXISTS public.fn_analytics_trial_location_distribution(
    date,
    date,
    uuid,
    uuid
);

DROP FUNCTION IF EXISTS public.fn_analytics_user_productivity(
    date,
    date,
    uuid
);

-- ============================================================
-- 1. ANALYTICS OVERVIEW
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_analytics_overview(
    p_date_from date DEFAULT NULL,
    p_date_to date DEFAULT NULL,
    p_crop_id uuid DEFAULT NULL,
    p_season_id uuid DEFAULT NULL,
    p_region_id uuid DEFAULT NULL,
    p_province_id uuid DEFAULT NULL
)
RETURNS TABLE (
    total_trials bigint,
    pending_approval_trials bigint,
    approved_trials bigint,
    rejected_trials bigint,
    corrections_requested_trials bigint,
    completed_trials bigint,
    total_evaluations bigint,
    completed_evaluations bigint,
    total_trial_varieties bigint,
    leader_varieties bigint,
    total_trial_photos bigint,
    total_evaluation_photos bigint,
    total_reports bigint,
    completed_reports bigint,
    failed_reports bigint,
    average_evaluations_per_trial numeric,
    average_varieties_per_trial numeric,
    approval_rate numeric,
    completion_rate numeric
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
WITH filtered_trials AS (
    SELECT
        t.id,
        t.status_id,
        t.completed_at
    FROM public.trials t
    WHERE t.deleted_at IS NULL
      AND (
            p_date_from IS NULL
            OR t.created_at::date >= p_date_from
          )
      AND (
            p_date_to IS NULL
            OR t.created_at::date <= p_date_to
          )
      AND (
            p_crop_id IS NULL
            OR t.crop_id = p_crop_id
          )
      AND (
            p_season_id IS NULL
            OR t.season_id = p_season_id
          )
      AND (
            p_region_id IS NULL
            OR t.region_id = p_region_id
          )
      AND (
            p_province_id IS NULL
            OR t.province_id = p_province_id
          )
),

trial_metrics AS (
    SELECT
        COUNT(ft.id)::bigint AS total_trials,

        COUNT(ft.id) FILTER (
            WHERE ts.is_approval_pending = true
        )::bigint AS pending_approval_trials,

        COUNT(ft.id) FILTER (
            WHERE ts.is_approved = true
        )::bigint AS approved_trials,

        COUNT(ft.id) FILTER (
            WHERE ts.is_rejected = true
        )::bigint AS rejected_trials,

        COUNT(ft.id) FILTER (
            WHERE ts.is_corrections_requested = true
        )::bigint AS corrections_requested_trials,

        COUNT(ft.id) FILTER (
            WHERE ft.completed_at IS NOT NULL
        )::bigint AS completed_trials

    FROM filtered_trials ft

    LEFT JOIN public.trial_statuses ts
           ON ts.id = ft.status_id
          AND ts.deleted_at IS NULL
          AND ts.is_active = true
),

evaluation_metrics AS (
    SELECT
        COUNT(e.id)::bigint AS total_evaluations,

        COUNT(e.id) FILTER (
            WHERE e.completed_at IS NOT NULL
        )::bigint AS completed_evaluations

    FROM public.evaluations e

    JOIN filtered_trials ft
      ON ft.id = e.trial_id

    WHERE e.deleted_at IS NULL
      AND e.is_active = true
),

variety_metrics AS (
    SELECT
        COUNT(tv.id)::bigint AS total_trial_varieties,

        COUNT(tv.id) FILTER (
            WHERE tv.is_leader = true
        )::bigint AS leader_varieties

    FROM public.trial_varieties tv

    JOIN filtered_trials ft
      ON ft.id = tv.trial_id

    WHERE tv.deleted_at IS NULL
      AND tv.is_active = true
),

trial_photo_metrics AS (
    SELECT
        COUNT(tp.id)::bigint AS total_trial_photos

    FROM public.trial_photos tp

    JOIN filtered_trials ft
      ON ft.id = tp.trial_id

    WHERE tp.deleted_at IS NULL
      AND tp.is_active = true
),

evaluation_photo_metrics AS (
    SELECT
        COUNT(ep.id)::bigint AS total_evaluation_photos

    FROM public.evaluation_photos ep

    JOIN public.evaluations e
      ON e.id = ep.evaluation_id
     AND e.deleted_at IS NULL
     AND e.is_active = true

    JOIN filtered_trials ft
      ON ft.id = e.trial_id

    WHERE ep.deleted_at IS NULL
      AND ep.is_active = true
),

report_metrics AS (
    SELECT
        COUNT(gr.id)::bigint AS total_reports,

        COUNT(gr.id) FILTER (
            WHERE upper(gr.report_status::text) IN (
                'COMPLETED',
                'GENERATED',
                'SUCCESS'
            )
            OR (
                gr.completed_at IS NOT NULL
                AND gr.error_message IS NULL
            )
        )::bigint AS completed_reports,

        COUNT(gr.id) FILTER (
            WHERE upper(gr.report_status::text) IN (
                'FAILED',
                'ERROR'
            )
            OR gr.error_message IS NOT NULL
        )::bigint AS failed_reports

    FROM public.generated_reports gr

    WHERE gr.deleted_at IS NULL
      AND gr.is_active = true
      AND (
            p_date_from IS NULL
            OR gr.requested_at::date >= p_date_from
          )
      AND (
            p_date_to IS NULL
            OR gr.requested_at::date <= p_date_to
          )
      AND (
            p_crop_id IS NULL
            OR gr.crop_id = p_crop_id
            OR EXISTS (
                SELECT 1
                FROM filtered_trials ft
                WHERE ft.id = gr.trial_id
            )
          )
      AND (
            p_season_id IS NULL
            OR gr.season_id = p_season_id
            OR EXISTS (
                SELECT 1
                FROM public.trials t
                WHERE t.id = gr.trial_id
                  AND t.season_id = p_season_id
                  AND t.deleted_at IS NULL
            )
          )
)

SELECT
    tm.total_trials,
    tm.pending_approval_trials,
    tm.approved_trials,
    tm.rejected_trials,
    tm.corrections_requested_trials,
    tm.completed_trials,
    em.total_evaluations,
    em.completed_evaluations,
    vm.total_trial_varieties,
    vm.leader_varieties,
    tpm.total_trial_photos,
    epm.total_evaluation_photos,
    rm.total_reports,
    rm.completed_reports,
    rm.failed_reports,

    CASE
        WHEN tm.total_trials = 0 THEN 0::numeric
        ELSE round(
            em.total_evaluations::numeric
            / tm.total_trials::numeric,
            2
        )
    END AS average_evaluations_per_trial,

    CASE
        WHEN tm.total_trials = 0 THEN 0::numeric
        ELSE round(
            vm.total_trial_varieties::numeric
            / tm.total_trials::numeric,
            2
        )
    END AS average_varieties_per_trial,

    CASE
        WHEN tm.total_trials = 0 THEN 0::numeric
        ELSE round(
            tm.approved_trials::numeric
            * 100
            / tm.total_trials::numeric,
            2
        )
    END AS approval_rate,

    CASE
        WHEN tm.total_trials = 0 THEN 0::numeric
        ELSE round(
            tm.completed_trials::numeric
            * 100
            / tm.total_trials::numeric,
            2
        )
    END AS completion_rate

FROM trial_metrics tm
CROSS JOIN evaluation_metrics em
CROSS JOIN variety_metrics vm
CROSS JOIN trial_photo_metrics tpm
CROSS JOIN evaluation_photo_metrics epm
CROSS JOIN report_metrics rm;
$$;

COMMENT ON FUNCTION public.fn_analytics_overview(
    date,
    date,
    uuid,
    uuid,
    uuid,
    uuid
) IS
'Returns principal analytics metrics with optional date, crop, season, region, and province filters.';

-- ============================================================
-- 2. TRIALS BY CROP
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_analytics_trials_by_crop(
    p_date_from date DEFAULT NULL,
    p_date_to date DEFAULT NULL,
    p_season_id uuid DEFAULT NULL
)
RETURNS TABLE (
    crop_id uuid,
    crop_code text,
    crop_name text,
    crop_emoji text,
    total_trials bigint,
    pending_approval_trials bigint,
    approved_trials bigint,
    rejected_trials bigint,
    corrections_requested_trials bigint,
    completed_trials bigint,
    total_evaluations bigint,
    total_varieties bigint,
    leader_varieties bigint,
    approval_rate numeric,
    completion_rate numeric
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
WITH filtered_trials AS (
    SELECT
        t.id,
        t.crop_id,
        t.status_id,
        t.completed_at
    FROM public.trials t
    WHERE t.deleted_at IS NULL
      AND (
            p_date_from IS NULL
            OR t.created_at::date >= p_date_from
          )
      AND (
            p_date_to IS NULL
            OR t.created_at::date <= p_date_to
          )
      AND (
            p_season_id IS NULL
            OR t.season_id = p_season_id
          )
),

trial_counts AS (
    SELECT
        ft.crop_id,

        COUNT(ft.id)::bigint AS total_trials,

        COUNT(ft.id) FILTER (
            WHERE ts.is_approval_pending = true
        )::bigint AS pending_approval_trials,

        COUNT(ft.id) FILTER (
            WHERE ts.is_approved = true
        )::bigint AS approved_trials,

        COUNT(ft.id) FILTER (
            WHERE ts.is_rejected = true
        )::bigint AS rejected_trials,

        COUNT(ft.id) FILTER (
            WHERE ts.is_corrections_requested = true
        )::bigint AS corrections_requested_trials,

        COUNT(ft.id) FILTER (
            WHERE ft.completed_at IS NOT NULL
        )::bigint AS completed_trials

    FROM filtered_trials ft

    LEFT JOIN public.trial_statuses ts
           ON ts.id = ft.status_id
          AND ts.deleted_at IS NULL
          AND ts.is_active = true

    GROUP BY ft.crop_id
),

evaluation_counts AS (
    SELECT
        ft.crop_id,
        COUNT(e.id)::bigint AS total_evaluations
    FROM filtered_trials ft
    JOIN public.evaluations e
      ON e.trial_id = ft.id
     AND e.deleted_at IS NULL
     AND e.is_active = true
    GROUP BY ft.crop_id
),

variety_counts AS (
    SELECT
        ft.crop_id,
        COUNT(tv.id)::bigint AS total_varieties,

        COUNT(tv.id) FILTER (
            WHERE tv.is_leader = true
        )::bigint AS leader_varieties

    FROM filtered_trials ft

    JOIN public.trial_varieties tv
      ON tv.trial_id = ft.id
     AND tv.deleted_at IS NULL
     AND tv.is_active = true

    GROUP BY ft.crop_id
)

SELECT
    c.id AS crop_id,
    c.code::text AS crop_code,
    c.name::text AS crop_name,
    c.emoji::text AS crop_emoji,

    COALESCE(tc.total_trials, 0)::bigint,
    COALESCE(tc.pending_approval_trials, 0)::bigint,
    COALESCE(tc.approved_trials, 0)::bigint,
    COALESCE(tc.rejected_trials, 0)::bigint,
    COALESCE(tc.corrections_requested_trials, 0)::bigint,
    COALESCE(tc.completed_trials, 0)::bigint,
    COALESCE(ec.total_evaluations, 0)::bigint,
    COALESCE(vc.total_varieties, 0)::bigint,
    COALESCE(vc.leader_varieties, 0)::bigint,

    CASE
        WHEN COALESCE(tc.total_trials, 0) = 0 THEN 0::numeric
        ELSE round(
            tc.approved_trials::numeric
            * 100
            / tc.total_trials::numeric,
            2
        )
    END AS approval_rate,

    CASE
        WHEN COALESCE(tc.total_trials, 0) = 0 THEN 0::numeric
        ELSE round(
            tc.completed_trials::numeric
            * 100
            / tc.total_trials::numeric,
            2
        )
    END AS completion_rate

FROM public.crops c

LEFT JOIN trial_counts tc
       ON tc.crop_id = c.id

LEFT JOIN evaluation_counts ec
       ON ec.crop_id = c.id

LEFT JOIN variety_counts vc
       ON vc.crop_id = c.id

WHERE c.deleted_at IS NULL
  AND c.is_active = true

ORDER BY
    COALESCE(tc.total_trials, 0) DESC,
    c.display_order,
    c.name;
$$;

COMMENT ON FUNCTION public.fn_analytics_trials_by_crop(
    date,
    date,
    uuid
) IS
'Returns trial, evaluation, and variety analytics grouped by crop.';

-- ============================================================
-- 3. TRIALS BY REGION
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_analytics_trials_by_region(
    p_date_from date DEFAULT NULL,
    p_date_to date DEFAULT NULL,
    p_crop_id uuid DEFAULT NULL,
    p_season_id uuid DEFAULT NULL
)
RETURNS TABLE (
    region_id uuid,
    region_code text,
    region_name text,
    total_provinces bigint,
    total_trials bigint,
    grower_farm_trials bigint,
    experimental_station_trials bigint,
    pending_approval_trials bigint,
    approved_trials bigint,
    completed_trials bigint,
    total_evaluations bigint
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
WITH filtered_trials AS (
    SELECT
        t.id,
        t.region_id,
        t.status_id,
        t.farm_id,
        t.experimental_station_id,
        t.completed_at
    FROM public.trials t
    WHERE t.deleted_at IS NULL
      AND (
            p_date_from IS NULL
            OR t.created_at::date >= p_date_from
          )
      AND (
            p_date_to IS NULL
            OR t.created_at::date <= p_date_to
          )
      AND (
            p_crop_id IS NULL
            OR t.crop_id = p_crop_id
          )
      AND (
            p_season_id IS NULL
            OR t.season_id = p_season_id
          )
),

province_counts AS (
    SELECT
        p.region_id,
        COUNT(p.id)::bigint AS total_provinces
    FROM public.provinces p
    WHERE p.deleted_at IS NULL
      AND p.is_active = true
    GROUP BY p.region_id
),

trial_counts AS (
    SELECT
        ft.region_id,

        COUNT(ft.id)::bigint AS total_trials,

        COUNT(ft.id) FILTER (
            WHERE ft.farm_id IS NOT NULL
        )::bigint AS grower_farm_trials,

        COUNT(ft.id) FILTER (
            WHERE ft.experimental_station_id IS NOT NULL
        )::bigint AS experimental_station_trials,

        COUNT(ft.id) FILTER (
            WHERE ts.is_approval_pending = true
        )::bigint AS pending_approval_trials,

        COUNT(ft.id) FILTER (
            WHERE ts.is_approved = true
        )::bigint AS approved_trials,

        COUNT(ft.id) FILTER (
            WHERE ft.completed_at IS NOT NULL
        )::bigint AS completed_trials

    FROM filtered_trials ft

    LEFT JOIN public.trial_statuses ts
           ON ts.id = ft.status_id
          AND ts.deleted_at IS NULL
          AND ts.is_active = true

    GROUP BY ft.region_id
),

evaluation_counts AS (
    SELECT
        ft.region_id,
        COUNT(e.id)::bigint AS total_evaluations
    FROM filtered_trials ft
    JOIN public.evaluations e
      ON e.trial_id = ft.id
     AND e.deleted_at IS NULL
     AND e.is_active = true
    GROUP BY ft.region_id
)

SELECT
    r.id AS region_id,
    r.code::text AS region_code,
    r.name::text AS region_name,
    COALESCE(pc.total_provinces, 0)::bigint,
    COALESCE(tc.total_trials, 0)::bigint,
    COALESCE(tc.grower_farm_trials, 0)::bigint,
    COALESCE(tc.experimental_station_trials, 0)::bigint,
    COALESCE(tc.pending_approval_trials, 0)::bigint,
    COALESCE(tc.approved_trials, 0)::bigint,
    COALESCE(tc.completed_trials, 0)::bigint,
    COALESCE(ec.total_evaluations, 0)::bigint

FROM public.regions r

LEFT JOIN province_counts pc
       ON pc.region_id = r.id

LEFT JOIN trial_counts tc
       ON tc.region_id = r.id

LEFT JOIN evaluation_counts ec
       ON ec.region_id = r.id

WHERE r.deleted_at IS NULL
  AND r.is_active = true

ORDER BY
    COALESCE(tc.total_trials, 0) DESC,
    r.display_order,
    r.name;
$$;

COMMENT ON FUNCTION public.fn_analytics_trials_by_region(
    date,
    date,
    uuid,
    uuid
) IS
'Returns trial and evaluation analytics grouped by region.';

-- ============================================================
-- 4. TRIALS BY STATUS
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_analytics_trials_by_status(
    p_date_from date DEFAULT NULL,
    p_date_to date DEFAULT NULL,
    p_crop_id uuid DEFAULT NULL,
    p_season_id uuid DEFAULT NULL
)
RETURNS TABLE (
    status_id uuid,
    status_code text,
    status_name text,
    workflow_order smallint,
    is_initial boolean,
    is_approval_pending boolean,
    is_approved boolean,
    is_phase_two boolean,
    is_terminal boolean,
    is_rejected boolean,
    is_corrections_requested boolean,
    trial_count bigint,
    percentage_of_trials numeric
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
WITH filtered_trials AS (
    SELECT
        t.id,
        t.status_id
    FROM public.trials t
    WHERE t.deleted_at IS NULL
      AND (
            p_date_from IS NULL
            OR t.created_at::date >= p_date_from
          )
      AND (
            p_date_to IS NULL
            OR t.created_at::date <= p_date_to
          )
      AND (
            p_crop_id IS NULL
            OR t.crop_id = p_crop_id
          )
      AND (
            p_season_id IS NULL
            OR t.season_id = p_season_id
          )
),

total_count AS (
    SELECT COUNT(*)::numeric AS total_trials
    FROM filtered_trials
),

status_counts AS (
    SELECT
        ft.status_id,
        COUNT(ft.id)::bigint AS trial_count
    FROM filtered_trials ft
    GROUP BY ft.status_id
)

SELECT
    ts.id AS status_id,
    ts.code::text AS status_code,
    ts.name::text AS status_name,
    ts.workflow_order,
    ts.is_initial,
    ts.is_approval_pending,
    ts.is_approved,
    ts.is_phase_two,
    ts.is_terminal,
    ts.is_rejected,
    ts.is_corrections_requested,
    COALESCE(sc.trial_count, 0)::bigint,

    CASE
        WHEN tc.total_trials = 0 THEN 0::numeric
        ELSE round(
            COALESCE(sc.trial_count, 0)::numeric
            * 100
            / tc.total_trials,
            2
        )
    END AS percentage_of_trials

FROM public.trial_statuses ts

CROSS JOIN total_count tc

LEFT JOIN status_counts sc
       ON sc.status_id = ts.id

WHERE ts.deleted_at IS NULL
  AND ts.is_active = true

ORDER BY
    ts.workflow_order,
    ts.display_order,
    ts.name;
$$;

COMMENT ON FUNCTION public.fn_analytics_trials_by_status(
    date,
    date,
    uuid,
    uuid
) IS
'Returns filtered trial distribution by workflow status.';

-- ============================================================
-- 5. EVALUATIONS BY TYPE
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_analytics_evaluations_by_type(
    p_date_from date DEFAULT NULL,
    p_date_to date DEFAULT NULL,
    p_crop_id uuid DEFAULT NULL,
    p_season_id uuid DEFAULT NULL
)
RETURNS TABLE (
    evaluation_type_id uuid,
    evaluation_type_code text,
    evaluation_type_name text,
    total_evaluations bigint,
    completed_evaluations bigint,
    incomplete_evaluations bigint,
    distinct_trials bigint,
    average_brix numeric,
    average_fruit_weight_grams numeric,
    average_temperature_celsius numeric,
    average_humidity_percentage numeric,
    completion_rate numeric
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
WITH filtered_evaluations AS (
    SELECT
        e.id,
        e.trial_id,
        e.evaluation_type_id,
        e.completed_at,
        e.brix_value,
        e.average_fruit_weight_grams,
        e.temperature_celsius,
        e.humidity_percentage
    FROM public.evaluations e

    JOIN public.trials t
      ON t.id = e.trial_id
     AND t.deleted_at IS NULL

    WHERE e.deleted_at IS NULL
      AND e.is_active = true
      AND (
            p_date_from IS NULL
            OR e.evaluation_date >= p_date_from
          )
      AND (
            p_date_to IS NULL
            OR e.evaluation_date <= p_date_to
          )
      AND (
            p_crop_id IS NULL
            OR t.crop_id = p_crop_id
          )
      AND (
            p_season_id IS NULL
            OR t.season_id = p_season_id
          )
),

evaluation_counts AS (
    SELECT
        fe.evaluation_type_id,

        COUNT(fe.id)::bigint AS total_evaluations,

        COUNT(fe.id) FILTER (
            WHERE fe.completed_at IS NOT NULL
        )::bigint AS completed_evaluations,

        COUNT(fe.id) FILTER (
            WHERE fe.completed_at IS NULL
        )::bigint AS incomplete_evaluations,

        COUNT(DISTINCT fe.trial_id)::bigint AS distinct_trials,

        round(
            AVG(fe.brix_value),
            2
        ) AS average_brix,

        round(
            AVG(fe.average_fruit_weight_grams),
            2
        ) AS average_fruit_weight_grams,

        round(
            AVG(fe.temperature_celsius),
            2
        ) AS average_temperature_celsius,

        round(
            AVG(fe.humidity_percentage),
            2
        ) AS average_humidity_percentage

    FROM filtered_evaluations fe
    GROUP BY fe.evaluation_type_id
)

SELECT
    et.id AS evaluation_type_id,
    et.code::text AS evaluation_type_code,
    et.name::text AS evaluation_type_name,
    COALESCE(ec.total_evaluations, 0)::bigint,
    COALESCE(ec.completed_evaluations, 0)::bigint,
    COALESCE(ec.incomplete_evaluations, 0)::bigint,
    COALESCE(ec.distinct_trials, 0)::bigint,
    ec.average_brix,
    ec.average_fruit_weight_grams,
    ec.average_temperature_celsius,
    ec.average_humidity_percentage,

    CASE
        WHEN COALESCE(ec.total_evaluations, 0) = 0 THEN 0::numeric
        ELSE round(
            ec.completed_evaluations::numeric
            * 100
            / ec.total_evaluations::numeric,
            2
        )
    END AS completion_rate

FROM public.evaluation_types et

LEFT JOIN evaluation_counts ec
       ON ec.evaluation_type_id = et.id

WHERE et.deleted_at IS NULL
  AND et.is_active = true

ORDER BY
    COALESCE(ec.total_evaluations, 0) DESC,
    et.display_order,
    et.name;
$$;

COMMENT ON FUNCTION public.fn_analytics_evaluations_by_type(
    date,
    date,
    uuid,
    uuid
) IS
'Returns evaluation volume, completion, and technical measurement analytics grouped by evaluation type.';

-- ============================================================
-- 6. VARIETY PERFORMANCE
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_analytics_variety_performance(
    p_date_from date DEFAULT NULL,
    p_date_to date DEFAULT NULL,
    p_crop_id uuid DEFAULT NULL,
    p_season_id uuid DEFAULT NULL,
    p_limit integer DEFAULT 100
)
RETURNS TABLE (
    trial_variety_id uuid,
    trial_id uuid,
    business_id text,
    crop_id uuid,
    crop_code text,
    crop_name text,
    variety_name text,
    variety_role text,
    is_primary boolean,
    is_leader boolean,
    total_evaluations bigint,
    completed_evaluations bigint,
    total_evaluation_details bigint,
    total_photos bigint,
    average_brix numeric,
    average_fruit_weight_grams numeric,
    first_evaluation_date date,
    latest_evaluation_date date
)
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
DECLARE
    v_limit integer;
BEGIN
    v_limit := LEAST(
        GREATEST(
            COALESCE(p_limit, 100),
            1
        ),
        1000
    );

    RETURN QUERY
    WITH filtered_varieties AS (
        SELECT
            tv.id,
            tv.trial_id,
            tv.variety_name,
            tv.variety_role,
            tv.is_primary,
            tv.is_leader,
            t.business_id,
            t.crop_id,
            c.code AS crop_code,
            c.name AS crop_name

        FROM public.trial_varieties tv

        JOIN public.trials t
          ON t.id = tv.trial_id
         AND t.deleted_at IS NULL

        JOIN public.crops c
          ON c.id = t.crop_id
         AND c.deleted_at IS NULL
         AND c.is_active = true

        WHERE tv.deleted_at IS NULL
          AND tv.is_active = true
          AND (
                p_date_from IS NULL
                OR t.created_at::date >= p_date_from
              )
          AND (
                p_date_to IS NULL
                OR t.created_at::date <= p_date_to
              )
          AND (
                p_crop_id IS NULL
                OR t.crop_id = p_crop_id
              )
          AND (
                p_season_id IS NULL
                OR t.season_id = p_season_id
              )
    ),

    evaluation_metrics AS (
        SELECT
            fv.id AS trial_variety_id,

            COUNT(e.id)::bigint AS total_evaluations,

            COUNT(e.id) FILTER (
                WHERE e.completed_at IS NOT NULL
            )::bigint AS completed_evaluations,

            round(
                AVG(e.brix_value),
                2
            ) AS average_brix,

            round(
                AVG(e.average_fruit_weight_grams),
                2
            ) AS average_fruit_weight_grams,

            MIN(e.evaluation_date) AS first_evaluation_date,
            MAX(e.evaluation_date) AS latest_evaluation_date

        FROM filtered_varieties fv

        LEFT JOIN public.evaluations e
               ON e.trial_variety_id = fv.id
              AND e.deleted_at IS NULL
              AND e.is_active = true
              AND (
                    p_date_from IS NULL
                    OR e.evaluation_date >= p_date_from
                  )
              AND (
                    p_date_to IS NULL
                    OR e.evaluation_date <= p_date_to
                  )

        GROUP BY fv.id
    ),

    detail_metrics AS (
        SELECT
            fv.id AS trial_variety_id,
            COUNT(ed.id)::bigint AS total_evaluation_details

        FROM filtered_varieties fv

        LEFT JOIN public.evaluation_details ed
               ON ed.trial_variety_id = fv.id
              AND ed.deleted_at IS NULL
              AND ed.is_active = true

        GROUP BY fv.id
    ),

    evaluation_photo_metrics AS (
        SELECT
            fv.id AS trial_variety_id,
            COUNT(ep.id)::bigint AS evaluation_photo_count

        FROM filtered_varieties fv

        LEFT JOIN public.evaluation_photos ep
               ON ep.trial_variety_id = fv.id
              AND ep.deleted_at IS NULL
              AND ep.is_active = true

        GROUP BY fv.id
    ),

    trial_photo_metrics AS (
        SELECT
            fv.id AS trial_variety_id,
            COUNT(tp.id)::bigint AS trial_photo_count

        FROM filtered_varieties fv

        LEFT JOIN public.trial_photos tp
               ON tp.trial_id = fv.trial_id
              AND tp.deleted_at IS NULL
              AND tp.is_active = true

        GROUP BY fv.id
    )

    SELECT
        fv.id AS trial_variety_id,
        fv.trial_id,
        fv.business_id::text AS business_id,
        fv.crop_id,
        fv.crop_code::text AS crop_code,
        fv.crop_name::text AS crop_name,
        fv.variety_name::text AS variety_name,
        fv.variety_role::text AS variety_role,
        fv.is_primary,
        fv.is_leader,
        COALESCE(em.total_evaluations, 0)::bigint,
        COALESCE(em.completed_evaluations, 0)::bigint,
        COALESCE(dm.total_evaluation_details, 0)::bigint,

        (
            COALESCE(epm.evaluation_photo_count, 0)
            + COALESCE(tpm.trial_photo_count, 0)
        )::bigint AS total_photos,

        em.average_brix,
        em.average_fruit_weight_grams,
        em.first_evaluation_date,
        em.latest_evaluation_date

    FROM filtered_varieties fv

    LEFT JOIN evaluation_metrics em
           ON em.trial_variety_id = fv.id

    LEFT JOIN detail_metrics dm
           ON dm.trial_variety_id = fv.id

    LEFT JOIN evaluation_photo_metrics epm
           ON epm.trial_variety_id = fv.id

    LEFT JOIN trial_photo_metrics tpm
           ON tpm.trial_variety_id = fv.id

    ORDER BY
        fv.is_leader DESC,
        COALESCE(em.completed_evaluations, 0) DESC,
        COALESCE(em.total_evaluations, 0) DESC,
        fv.variety_name

    LIMIT v_limit;
END;
$$;

COMMENT ON FUNCTION public.fn_analytics_variety_performance(
    date,
    date,
    uuid,
    uuid,
    integer
) IS
'Returns trial variety analytics including evaluations, measurements, details, and photos.';

-- ============================================================
-- 7. MONTHLY ACTIVITY
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_analytics_monthly_activity(
    p_date_from date DEFAULT NULL,
    p_date_to date DEFAULT NULL,
    p_crop_id uuid DEFAULT NULL,
    p_season_id uuid DEFAULT NULL
)
RETURNS TABLE (
    month_start date,
    month_code text,
    month_label text,
    trials_created bigint,
    trials_submitted bigint,
    trials_approved bigint,
    trials_completed bigint,
    evaluations_created bigint,
    evaluations_completed bigint,
    reports_requested bigint,
    reports_completed bigint,
    total_activity bigint
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
WITH parameters AS (
    SELECT
        COALESCE(
            p_date_from,
            date_trunc(
                'month',
                CURRENT_DATE - INTERVAL '11 months'
            )::date
        ) AS date_from,

        COALESCE(
            p_date_to,
            CURRENT_DATE
        ) AS date_to
),

months AS (
    SELECT
        generate_series(
            date_trunc('month', prm.date_from),
            date_trunc('month', prm.date_to),
            INTERVAL '1 month'
        )::date AS month_start
    FROM parameters prm
),

filtered_trials AS (
    SELECT
        t.id,
        t.created_at,
        t.submitted_at,
        t.approved_at,
        t.completed_at
    FROM public.trials t
    CROSS JOIN parameters prm
    WHERE t.deleted_at IS NULL
      AND t.created_at::date <= prm.date_to
      AND (
            p_crop_id IS NULL
            OR t.crop_id = p_crop_id
          )
      AND (
            p_season_id IS NULL
            OR t.season_id = p_season_id
          )
),

trial_activity AS (
    SELECT
        m.month_start,

        COUNT(ft.id) FILTER (
            WHERE date_trunc(
                'month',
                ft.created_at
            )::date = m.month_start
        )::bigint AS trials_created,

        COUNT(ft.id) FILTER (
            WHERE ft.submitted_at IS NOT NULL
              AND date_trunc(
                    'month',
                    ft.submitted_at
                  )::date = m.month_start
        )::bigint AS trials_submitted,

        COUNT(ft.id) FILTER (
            WHERE ft.approved_at IS NOT NULL
              AND date_trunc(
                    'month',
                    ft.approved_at
                  )::date = m.month_start
        )::bigint AS trials_approved,

        COUNT(ft.id) FILTER (
            WHERE ft.completed_at IS NOT NULL
              AND date_trunc(
                    'month',
                    ft.completed_at
                  )::date = m.month_start
        )::bigint AS trials_completed

    FROM months m

    LEFT JOIN filtered_trials ft
           ON true

    GROUP BY m.month_start
),

evaluation_activity AS (
    SELECT
        m.month_start,

        COUNT(e.id) FILTER (
            WHERE date_trunc(
                'month',
                e.created_at
            )::date = m.month_start
        )::bigint AS evaluations_created,

        COUNT(e.id) FILTER (
            WHERE e.completed_at IS NOT NULL
              AND date_trunc(
                    'month',
                    e.completed_at
                  )::date = m.month_start
        )::bigint AS evaluations_completed

    FROM months m

    LEFT JOIN public.evaluations e
           ON e.deleted_at IS NULL
          AND e.is_active = true
          AND EXISTS (
                SELECT 1
                FROM public.trials t
                WHERE t.id = e.trial_id
                  AND t.deleted_at IS NULL
                  AND (
                        p_crop_id IS NULL
                        OR t.crop_id = p_crop_id
                      )
                  AND (
                        p_season_id IS NULL
                        OR t.season_id = p_season_id
                      )
          )

    GROUP BY m.month_start
),

report_activity AS (
    SELECT
        m.month_start,

        COUNT(gr.id) FILTER (
            WHERE date_trunc(
                'month',
                gr.requested_at
            )::date = m.month_start
        )::bigint AS reports_requested,

        COUNT(gr.id) FILTER (
            WHERE gr.completed_at IS NOT NULL
              AND date_trunc(
                    'month',
                    gr.completed_at
                  )::date = m.month_start
        )::bigint AS reports_completed

    FROM months m

    LEFT JOIN public.generated_reports gr
           ON gr.deleted_at IS NULL
          AND gr.is_active = true
          AND (
                p_crop_id IS NULL
                OR gr.crop_id = p_crop_id
                OR EXISTS (
                    SELECT 1
                    FROM public.trials t
                    WHERE t.id = gr.trial_id
                      AND t.crop_id = p_crop_id
                      AND t.deleted_at IS NULL
                )
              )
          AND (
                p_season_id IS NULL
                OR gr.season_id = p_season_id
                OR EXISTS (
                    SELECT 1
                    FROM public.trials t
                    WHERE t.id = gr.trial_id
                      AND t.season_id = p_season_id
                      AND t.deleted_at IS NULL
                )
              )

    GROUP BY m.month_start
)

SELECT
    m.month_start,
    to_char(m.month_start, 'YYYY-MM')::text AS month_code,
    to_char(m.month_start, 'Mon YYYY')::text AS month_label,
    COALESCE(ta.trials_created, 0)::bigint,
    COALESCE(ta.trials_submitted, 0)::bigint,
    COALESCE(ta.trials_approved, 0)::bigint,
    COALESCE(ta.trials_completed, 0)::bigint,
    COALESCE(ea.evaluations_created, 0)::bigint,
    COALESCE(ea.evaluations_completed, 0)::bigint,
    COALESCE(ra.reports_requested, 0)::bigint,
    COALESCE(ra.reports_completed, 0)::bigint,

    (
        COALESCE(ta.trials_created, 0)
        + COALESCE(ea.evaluations_created, 0)
        + COALESCE(ra.reports_requested, 0)
    )::bigint AS total_activity

FROM months m

LEFT JOIN trial_activity ta
       ON ta.month_start = m.month_start

LEFT JOIN evaluation_activity ea
       ON ea.month_start = m.month_start

LEFT JOIN report_activity ra
       ON ra.month_start = m.month_start

ORDER BY m.month_start;
$$;

COMMENT ON FUNCTION public.fn_analytics_monthly_activity(
    date,
    date,
    uuid,
    uuid
) IS
'Returns monthly trial, evaluation, and report activity.';

-- ============================================================
-- 8. TRIAL LOCATION DISTRIBUTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_analytics_trial_location_distribution(
    p_date_from date DEFAULT NULL,
    p_date_to date DEFAULT NULL,
    p_crop_id uuid DEFAULT NULL,
    p_season_id uuid DEFAULT NULL
)
RETURNS TABLE (
    location_type text,
    location_id uuid,
    location_name text,
    region_id uuid,
    region_name text,
    province_id uuid,
    province_name text,
    total_trials bigint,
    approved_trials bigint,
    completed_trials bigint,
    total_evaluations bigint
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
WITH filtered_trials AS (
    SELECT
        t.id,
        t.status_id,
        t.completed_at,
        t.region_id,
        t.province_id,
        t.grower_id,
        t.farm_id,
        t.experimental_station_id
    FROM public.trials t
    WHERE t.deleted_at IS NULL
      AND (
            p_date_from IS NULL
            OR t.created_at::date >= p_date_from
          )
      AND (
            p_date_to IS NULL
            OR t.created_at::date <= p_date_to
          )
      AND (
            p_crop_id IS NULL
            OR t.crop_id = p_crop_id
          )
      AND (
            p_season_id IS NULL
            OR t.season_id = p_season_id
          )
),

location_rows AS (
    SELECT
        ft.id AS trial_id,
        ft.status_id,
        ft.completed_at,
        ft.region_id,
        ft.province_id,

        CASE
            WHEN ft.farm_id IS NOT NULL
                THEN 'GROWER_FARM'::text
            WHEN ft.experimental_station_id IS NOT NULL
                THEN 'EXPERIMENTAL_STATION'::text
            ELSE 'UNDEFINED'::text
        END AS location_type,

        COALESCE(
            ft.farm_id,
            ft.experimental_station_id
        ) AS location_id,

        CASE
            WHEN ft.farm_id IS NOT NULL THEN
                concat_ws(
                    ' - ',
                    g.name::text,
                    f.name::text
                )
            WHEN ft.experimental_station_id IS NOT NULL THEN
                es.name::text
            ELSE
                'Undefined location'::text
        END AS location_name

    FROM filtered_trials ft

    LEFT JOIN public.growers g
           ON g.id = ft.grower_id
          AND g.deleted_at IS NULL

    LEFT JOIN public.farms f
           ON f.id = ft.farm_id
          AND f.deleted_at IS NULL

    LEFT JOIN public.experimental_stations es
           ON es.id = ft.experimental_station_id
          AND es.deleted_at IS NULL
),

evaluation_counts AS (
    SELECT
        lr.location_type,
        lr.location_id,
        COUNT(e.id)::bigint AS total_evaluations

    FROM location_rows lr

    LEFT JOIN public.evaluations e
           ON e.trial_id = lr.trial_id
          AND e.deleted_at IS NULL
          AND e.is_active = true

    GROUP BY
        lr.location_type,
        lr.location_id
)

SELECT
    lr.location_type::text,
    lr.location_id,
    lr.location_name::text,
    r.id AS region_id,
    r.name::text AS region_name,
    p.id AS province_id,
    p.name::text AS province_name,
    COUNT(lr.trial_id)::bigint AS total_trials,

    COUNT(lr.trial_id) FILTER (
        WHERE ts.is_approved = true
    )::bigint AS approved_trials,

    COUNT(lr.trial_id) FILTER (
        WHERE lr.completed_at IS NOT NULL
    )::bigint AS completed_trials,

    COALESCE(ec.total_evaluations, 0)::bigint

FROM location_rows lr

JOIN public.regions r
  ON r.id = lr.region_id

JOIN public.provinces p
  ON p.id = lr.province_id

LEFT JOIN public.trial_statuses ts
       ON ts.id = lr.status_id
      AND ts.deleted_at IS NULL
      AND ts.is_active = true

LEFT JOIN evaluation_counts ec
       ON ec.location_type = lr.location_type
      AND ec.location_id IS NOT DISTINCT FROM lr.location_id

GROUP BY
    lr.location_type,
    lr.location_id,
    lr.location_name,
    r.id,
    r.name,
    p.id,
    p.name,
    ec.total_evaluations

ORDER BY
    COUNT(lr.trial_id) DESC,
    lr.location_name;
$$;

COMMENT ON FUNCTION public.fn_analytics_trial_location_distribution(
    date,
    date,
    uuid,
    uuid
) IS
'Returns trial and evaluation distribution grouped by farm or experimental station.';

-- ============================================================
-- 9. USER PRODUCTIVITY
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_analytics_user_productivity(
    p_date_from date DEFAULT NULL,
    p_date_to date DEFAULT NULL,
    p_role_id uuid DEFAULT NULL
)
RETURNS TABLE (
    profile_id uuid,
    user_id uuid,
    employee_code text,
    first_name text,
    last_name text,
    full_name text,
    role_id uuid,
    role_code text,
    role_name text,
    trials_created bigint,
    trials_submitted bigint,
    evaluations_created bigint,
    evaluations_completed bigint,
    reports_requested bigint,
    reports_completed bigint,
    total_actions bigint,
    last_activity_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
WITH trial_activity AS (
    SELECT
        t.created_by AS user_id,

        COUNT(t.id)::bigint AS trials_created,

        COUNT(t.id) FILTER (
            WHERE t.submitted_at IS NOT NULL
        )::bigint AS trials_submitted,

        MAX(t.created_at) AS last_trial_at

    FROM public.trials t

    WHERE t.deleted_at IS NULL
      AND t.created_by IS NOT NULL
      AND (
            p_date_from IS NULL
            OR t.created_at::date >= p_date_from
          )
      AND (
            p_date_to IS NULL
            OR t.created_at::date <= p_date_to
          )

    GROUP BY t.created_by
),

evaluation_activity AS (
    SELECT
        e.created_by AS user_id,

        COUNT(e.id)::bigint AS evaluations_created,

        COUNT(e.id) FILTER (
            WHERE e.completed_at IS NOT NULL
        )::bigint AS evaluations_completed,

        MAX(e.created_at) AS last_evaluation_at

    FROM public.evaluations e

    WHERE e.deleted_at IS NULL
      AND e.is_active = true
      AND e.created_by IS NOT NULL
      AND (
            p_date_from IS NULL
            OR e.created_at::date >= p_date_from
          )
      AND (
            p_date_to IS NULL
            OR e.created_at::date <= p_date_to
          )

    GROUP BY e.created_by
),

report_activity AS (
    SELECT
        gr.requested_by AS user_id,

        COUNT(gr.id)::bigint AS reports_requested,

        COUNT(gr.id) FILTER (
            WHERE gr.completed_at IS NOT NULL
              AND gr.error_message IS NULL
        )::bigint AS reports_completed,

        MAX(gr.requested_at) AS last_report_at

    FROM public.generated_reports gr

    WHERE gr.deleted_at IS NULL
      AND gr.is_active = true
      AND gr.requested_by IS NOT NULL
      AND (
            p_date_from IS NULL
            OR gr.requested_at::date >= p_date_from
          )
      AND (
            p_date_to IS NULL
            OR gr.requested_at::date <= p_date_to
          )

    GROUP BY gr.requested_by
)

SELECT
    p.id AS profile_id,
    p.user_id,
    p.employee_code::text AS employee_code,
    p.first_name::text AS first_name,
    p.last_name::text AS last_name,

    concat_ws(
        ' ',
        p.first_name::text,
        p.last_name::text
    )::text AS full_name,

    r.id AS role_id,
    r.code::text AS role_code,
    r.name::text AS role_name,
    COALESCE(ta.trials_created, 0)::bigint,
    COALESCE(ta.trials_submitted, 0)::bigint,
    COALESCE(ea.evaluations_created, 0)::bigint,
    COALESCE(ea.evaluations_completed, 0)::bigint,
    COALESCE(ra.reports_requested, 0)::bigint,
    COALESCE(ra.reports_completed, 0)::bigint,

    (
        COALESCE(ta.trials_created, 0)
        + COALESCE(ea.evaluations_created, 0)
        + COALESCE(ra.reports_requested, 0)
    )::bigint AS total_actions,

    GREATEST(
        ta.last_trial_at,
        ea.last_evaluation_at,
        ra.last_report_at,
        p.last_login_at
    ) AS last_activity_at

FROM public.profiles p

JOIN public.roles r
  ON r.id = p.role_id
 AND r.deleted_at IS NULL
 AND r.is_active = true

LEFT JOIN trial_activity ta
       ON ta.user_id = p.user_id

LEFT JOIN evaluation_activity ea
       ON ea.user_id = p.user_id

LEFT JOIN report_activity ra
       ON ra.user_id = p.user_id

WHERE p.deleted_at IS NULL
  AND p.is_active = true
  AND (
        p_role_id IS NULL
        OR p.role_id = p_role_id
      )

ORDER BY
    (
        COALESCE(ta.trials_created, 0)
        + COALESCE(ea.evaluations_created, 0)
        + COALESCE(ra.reports_requested, 0)
    ) DESC,
    p.first_name,
    p.last_name;
$$;

COMMENT ON FUNCTION public.fn_analytics_user_productivity(
    date,
    date,
    uuid
) IS
'Returns productivity analytics for active users.';

-- ============================================================
-- 10. PERMISSIONS
-- ============================================================

GRANT EXECUTE
ON FUNCTION public.fn_analytics_overview(
    date,
    date,
    uuid,
    uuid,
    uuid,
    uuid
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_analytics_trials_by_crop(
    date,
    date,
    uuid
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_analytics_trials_by_region(
    date,
    date,
    uuid,
    uuid
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_analytics_trials_by_status(
    date,
    date,
    uuid,
    uuid
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_analytics_evaluations_by_type(
    date,
    date,
    uuid,
    uuid
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_analytics_variety_performance(
    date,
    date,
    uuid,
    uuid,
    integer
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_analytics_monthly_activity(
    date,
    date,
    uuid,
    uuid
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_analytics_trial_location_distribution(
    date,
    date,
    uuid,
    uuid
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_analytics_user_productivity(
    date,
    date,
    uuid
)
TO authenticated, service_role;

-- ============================================================
-- 11. MIGRATION VALIDATION
-- ============================================================

DO $$
DECLARE
    v_missing_functions text[];
BEGIN
    SELECT array_agg(required_function)
    INTO v_missing_functions
    FROM (
        VALUES
            ('fn_analytics_overview'),
            ('fn_analytics_trials_by_crop'),
            ('fn_analytics_trials_by_region'),
            ('fn_analytics_trials_by_status'),
            ('fn_analytics_evaluations_by_type'),
            ('fn_analytics_variety_performance'),
            ('fn_analytics_monthly_activity'),
            ('fn_analytics_trial_location_distribution'),
            ('fn_analytics_user_productivity')
    ) AS required(required_function)
    WHERE NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc p
        JOIN pg_catalog.pg_namespace n
          ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname = required.required_function
    );

    IF v_missing_functions IS NOT NULL THEN
        RAISE EXCEPTION
            'Analytics migration validation failed. Missing functions: %',
            array_to_string(
                v_missing_functions,
                ', '
            );
    END IF;

    PERFORM *
    FROM public.fn_analytics_overview(
        NULL,
        NULL,
        NULL,
        NULL,
        NULL,
        NULL
    );

    PERFORM *
    FROM public.fn_analytics_trials_by_crop(
        NULL,
        NULL,
        NULL
    )
    LIMIT 1;

    PERFORM *
    FROM public.fn_analytics_trials_by_region(
        NULL,
        NULL,
        NULL,
        NULL
    )
    LIMIT 1;

    PERFORM *
    FROM public.fn_analytics_trials_by_status(
        NULL,
        NULL,
        NULL,
        NULL
    )
    LIMIT 1;

    PERFORM *
    FROM public.fn_analytics_evaluations_by_type(
        NULL,
        NULL,
        NULL,
        NULL
    )
    LIMIT 1;

    PERFORM *
    FROM public.fn_analytics_variety_performance(
        NULL,
        NULL,
        NULL,
        NULL,
        1
    )
    LIMIT 1;

    PERFORM *
    FROM public.fn_analytics_monthly_activity(
        (CURRENT_DATE - INTERVAL '1 month')::date,
        CURRENT_DATE,
        NULL,
        NULL
    )
    LIMIT 1;

    PERFORM *
    FROM public.fn_analytics_trial_location_distribution(
        NULL,
        NULL,
        NULL,
        NULL
    )
    LIMIT 1;

    PERFORM *
    FROM public.fn_analytics_user_productivity(
        NULL,
        NULL,
        NULL
    )
    LIMIT 1;

    RAISE NOTICE
        '0047_analytics_functions.sql completed successfully.';
END;
$$;

COMMIT;
