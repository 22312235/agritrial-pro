-- AgriTrial Pro
-- Migration: 0059_reporting_views.sql
-- Purpose: Create normalized reporting views for trials, evaluations, results, workflow history, media, and executive reporting.

BEGIN;

SET search_path = public, auth, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

DO $$
DECLARE
    v_missing text[];
BEGIN
    SELECT array_agg(required_table)
    INTO v_missing
    FROM (
        VALUES
            ('trials'),
            ('trial_varieties'),
            ('evaluations'),
            ('evaluation_details'),
            ('evaluation_detail_options'),
            ('evaluation_criteria'),
            ('criterion_options'),
            ('trial_status_history'),
            ('trial_photos'),
            ('evaluation_photos'),
            ('profiles')
    ) AS required(required_table)
    WHERE to_regclass(format('public.%I', required_table)) IS NULL;

    IF v_missing IS NOT NULL THEN
        RAISE EXCEPTION
            'Required reporting source tables are missing: %',
            array_to_string(v_missing, ', ');
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_report_try_uuid(
    p_value text
)
RETURNS uuid
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
BEGIN
    IF p_value IS NULL OR btrim(p_value) = '' THEN
        RETURN NULL;
    END IF;

    RETURN btrim(p_value)::uuid;
EXCEPTION
    WHEN invalid_text_representation THEN
        RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.fn_report_try_uuid(text) IS
'Safely converts a text value to UUID for reporting joins.';

CREATE OR REPLACE FUNCTION public.fn_report_try_date(
    p_value text
)
RETURNS date
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
BEGIN
    IF p_value IS NULL OR btrim(p_value) = '' THEN
        RETURN NULL;
    END IF;

    RETURN btrim(p_value)::date;
EXCEPTION
    WHEN invalid_datetime_format OR datetime_field_overflow THEN
        RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.fn_report_try_date(text) IS
'Safely converts a text value to date for reporting output.';

CREATE OR REPLACE FUNCTION public.fn_report_try_timestamptz(
    p_value text
)
RETURNS timestamptz
LANGUAGE plpgsql
STABLE
PARALLEL SAFE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
BEGIN
    IF p_value IS NULL OR btrim(p_value) = '' THEN
        RETURN NULL;
    END IF;

    RETURN btrim(p_value)::timestamptz;
EXCEPTION
    WHEN invalid_datetime_format OR datetime_field_overflow THEN
        RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.fn_report_try_timestamptz(text) IS
'Safely converts a text value to timestamp with time zone for reporting output.';

CREATE OR REPLACE FUNCTION public.fn_report_try_numeric(
    p_value text
)
RETURNS numeric
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
BEGIN
    IF p_value IS NULL OR btrim(p_value) = '' THEN
        RETURN NULL;
    END IF;

    RETURN btrim(p_value)::numeric;
EXCEPTION
    WHEN invalid_text_representation OR numeric_value_out_of_range THEN
        RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.fn_report_try_numeric(text) IS
'Safely converts a text value to numeric for reporting output.';

CREATE OR REPLACE FUNCTION public.fn_report_try_boolean(
    p_value text
)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
PARALLEL SAFE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
DECLARE
    v_value text;
BEGIN
    IF p_value IS NULL OR btrim(p_value) = '' THEN
        RETURN NULL;
    END IF;

    v_value := lower(btrim(p_value));

    IF v_value IN ('true', 't', '1', 'yes', 'y') THEN
        RETURN true;
    END IF;

    IF v_value IN ('false', 'f', '0', 'no', 'n') THEN
        RETURN false;
    END IF;

    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.fn_report_try_boolean(text) IS
'Safely converts common text representations to boolean for reporting output.';

DROP VIEW IF EXISTS public.v_report_executive_summary;
DROP VIEW IF EXISTS public.v_report_media_inventory;
DROP VIEW IF EXISTS public.v_report_trial_status_history;
DROP VIEW IF EXISTS public.v_report_evaluation_results;
DROP VIEW IF EXISTS public.v_report_evaluations;
DROP VIEW IF EXISTS public.v_report_trial_varieties;
DROP VIEW IF EXISTS public.v_report_trial_register;

CREATE VIEW public.v_report_trial_register
WITH (security_invoker = true)
AS
SELECT
    t.id AS trial_id,

    COALESCE(
        NULLIF(to_jsonb(t) ->> 'business_id', ''),
        NULLIF(to_jsonb(t) ->> 'trial_code', ''),
        NULLIF(to_jsonb(t) ->> 'code', ''),
        t.id::text
    ) AS business_id,

    COALESCE(
        NULLIF(to_jsonb(c) ->> 'name', ''),
        NULLIF(to_jsonb(c) ->> 'code', '')
    ) AS crop_name,

    COALESCE(
        NULLIF(to_jsonb(ct) ->> 'name', ''),
        NULLIF(to_jsonb(ct) ->> 'code', '')
    ) AS crop_type_name,

    COALESCE(
        NULLIF(to_jsonb(pt) ->> 'name', ''),
        NULLIF(to_jsonb(pt) ->> 'code', '')
    ) AS product_type_name,

    COALESCE(
        NULLIF(to_jsonb(tt) ->> 'name', ''),
        NULLIF(to_jsonb(tt) ->> 'code', '')
    ) AS trial_type_name,

    COALESCE(
        NULLIF(to_jsonb(s) ->> 'name', ''),
        NULLIF(to_jsonb(s) ->> 'code', '')
    ) AS season_name,

    COALESCE(
        NULLIF(to_jsonb(ts) ->> 'code', ''),
        NULLIF(to_jsonb(ts) ->> 'name', ''),
        NULLIF(to_jsonb(t) ->> 'status', ''),
        'UNKNOWN'
    ) AS status_key,

    NULLIF(to_jsonb(t) ->> 'variety', '') AS primary_variety,

    variety_data.varieties,

    variety_data.variety_count,

    variety_data.witness_varieties,

    variety_data.leader_varieties,

    upper(
        COALESCE(
            NULLIF(to_jsonb(t) ->> 'installation_method', ''),
            NULLIF(to_jsonb(t) ->> 'method', ''),
            'UNKNOWN'
        )
    ) AS installation_method,

    COALESCE(
        public.fn_report_try_date(to_jsonb(t) ->> 'planting_date'),
        public.fn_report_try_date(to_jsonb(t) ->> 'sowing_date'),
        public.fn_report_try_date(to_jsonb(t) ->> 'installation_date')
    ) AS installation_date,

    public.fn_report_try_date(to_jsonb(t) ->> 'planting_date')
        AS planting_date,

    public.fn_report_try_date(to_jsonb(t) ->> 'sowing_date')
        AS sowing_date,

    COALESCE(
        public.fn_report_try_numeric(to_jsonb(t) ->> 'density_per_hectare'),
        public.fn_report_try_numeric(to_jsonb(t) ->> 'density_ha'),
        public.fn_report_try_numeric(to_jsonb(t) ->> 'density')
    ) AS density_per_hectare,

    COALESCE(
        public.fn_report_try_numeric(to_jsonb(t) ->> 'number_of_varieties'),
        variety_data.variety_count::numeric
    ) AS declared_number_of_varieties,

    COALESCE(
        NULLIF(to_jsonb(r) ->> 'name', ''),
        NULLIF(to_jsonb(r) ->> 'code', '')
    ) AS region_name,

    COALESCE(
        NULLIF(to_jsonb(p) ->> 'name', ''),
        NULLIF(to_jsonb(p) ->> 'code', '')
    ) AS province_name,

    COALESCE(
        NULLIF(to_jsonb(g) ->> 'name', ''),
        NULLIF(to_jsonb(g) ->> 'full_name', '')
    ) AS grower_name,

    COALESCE(
        NULLIF(to_jsonb(g) ->> 'phone', ''),
        NULLIF(to_jsonb(g) ->> 'contact_phone', ''),
        NULLIF(to_jsonb(g) ->> 'contact', '')
    ) AS grower_contact,

    COALESCE(
        NULLIF(to_jsonb(f) ->> 'name', ''),
        NULLIF(to_jsonb(f) ->> 'code', '')
    ) AS farm_name,

    COALESCE(
        NULLIF(to_jsonb(es) ->> 'name', ''),
        NULLIF(to_jsonb(es) ->> 'code', '')
    ) AS experimental_station_name,

    CASE
        WHEN es.id IS NOT NULL THEN 'EXPERIMENTAL_STATION'
        WHEN g.id IS NOT NULL OR f.id IS NOT NULL THEN 'GROWER_FARM'
        ELSE 'UNKNOWN'
    END AS location_type,

    COALESCE(
        NULLIF(to_jsonb(t) ->> 'remarks', ''),
        NULLIF(to_jsonb(t) ->> 'notes', ''),
        NULLIF(to_jsonb(t) ->> 'comments', '')
    ) AS remarks,

    COALESCE(
        NULLIF(to_jsonb(dt) ->> 'name', ''),
        NULLIF(to_jsonb(dt) ->> 'code', ''),
        NULLIF(to_jsonb(t) ->> 'initial_decision', '')
    ) AS initial_decision,

    public.fn_report_try_uuid(to_jsonb(t) ->> 'created_by')
        AS created_by_user_id,

    NULLIF(
        concat_ws(
            ' ',
            NULLIF(to_jsonb(cp) ->> 'first_name', ''),
            NULLIF(to_jsonb(cp) ->> 'last_name', '')
        ),
        ''
    ) AS created_by_name,

    public.fn_report_try_timestamptz(to_jsonb(t) ->> 'created_at')
        AS created_at,

    public.fn_report_try_timestamptz(to_jsonb(t) ->> 'updated_at')
        AS updated_at

FROM public.trials t

LEFT JOIN public.crops c
    ON c.id = public.fn_report_try_uuid(
        to_jsonb(t) ->> 'crop_id'
    )

LEFT JOIN public.crop_types ct
    ON ct.id = public.fn_report_try_uuid(
        to_jsonb(t) ->> 'crop_type_id'
    )

LEFT JOIN public.product_types pt
    ON pt.id = public.fn_report_try_uuid(
        to_jsonb(t) ->> 'product_type_id'
    )

LEFT JOIN public.trial_types tt
    ON tt.id = public.fn_report_try_uuid(
        to_jsonb(t) ->> 'trial_type_id'
    )

LEFT JOIN public.seasons s
    ON s.id = public.fn_report_try_uuid(
        to_jsonb(t) ->> 'season_id'
    )

LEFT JOIN public.trial_statuses ts
    ON ts.id = public.fn_report_try_uuid(
        COALESCE(
            to_jsonb(t) ->> 'status_id',
            to_jsonb(t) ->> 'trial_status_id'
        )
    )

LEFT JOIN public.regions r
    ON r.id = public.fn_report_try_uuid(
        to_jsonb(t) ->> 'region_id'
    )

LEFT JOIN public.provinces p
    ON p.id = public.fn_report_try_uuid(
        to_jsonb(t) ->> 'province_id'
    )

LEFT JOIN public.growers g
    ON g.id = public.fn_report_try_uuid(
        to_jsonb(t) ->> 'grower_id'
    )

LEFT JOIN public.farms f
    ON f.id = public.fn_report_try_uuid(
        to_jsonb(t) ->> 'farm_id'
    )

LEFT JOIN public.experimental_stations es
    ON es.id = public.fn_report_try_uuid(
        COALESCE(
            to_jsonb(t) ->> 'experimental_station_id',
            to_jsonb(t) ->> 'station_id'
        )
    )

LEFT JOIN public.decision_types dt
    ON dt.id = public.fn_report_try_uuid(
        COALESCE(
            to_jsonb(t) ->> 'initial_decision_id',
            to_jsonb(t) ->> 'decision_type_id'
        )
    )

LEFT JOIN public.profiles cp
    ON cp.user_id = public.fn_report_try_uuid(
        to_jsonb(t) ->> 'created_by'
    )

LEFT JOIN LATERAL (
    SELECT
        NULLIF(
            array_to_string(
                array_agg(
                    DISTINCT COALESCE(
                        NULLIF(to_jsonb(tv) ->> 'variety_name', ''),
                        NULLIF(to_jsonb(tv) ->> 'name', ''),
                        NULLIF(to_jsonb(tv) ->> 'variety', '')
                    )
                ) FILTER (
                    WHERE COALESCE(
                        NULLIF(to_jsonb(tv) ->> 'variety_name', ''),
                        NULLIF(to_jsonb(tv) ->> 'name', ''),
                        NULLIF(to_jsonb(tv) ->> 'variety', '')
                    ) IS NOT NULL
                ),
                ', '
            ),
            ''
        ) AS varieties,

        count(*)::integer AS variety_count,

        NULLIF(
            array_to_string(
                array_agg(
                    DISTINCT COALESCE(
                        NULLIF(to_jsonb(tv) ->> 'variety_name', ''),
                        NULLIF(to_jsonb(tv) ->> 'name', ''),
                        NULLIF(to_jsonb(tv) ->> 'variety', '')
                    )
                ) FILTER (
                    WHERE COALESCE(
                        public.fn_report_try_boolean(
                            to_jsonb(tv) ->> 'is_witness'
                        ),
                        public.fn_report_try_boolean(
                            to_jsonb(tv) ->> 'is_witness_variety'
                        ),
                        false
                    )
                ),
                ', '
            ),
            ''
        ) AS witness_varieties,

        NULLIF(
            array_to_string(
                array_agg(
                    DISTINCT COALESCE(
                        NULLIF(to_jsonb(tv) ->> 'variety_name', ''),
                        NULLIF(to_jsonb(tv) ->> 'name', ''),
                        NULLIF(to_jsonb(tv) ->> 'variety', '')
                    )
                ) FILTER (
                    WHERE COALESCE(
                        public.fn_report_try_boolean(
                            to_jsonb(tv) ->> 'is_leader'
                        ),
                        public.fn_report_try_boolean(
                            to_jsonb(tv) ->> 'is_variety_leader'
                        ),
                        false
                    )
                ),
                ', '
            ),
            ''
        ) AS leader_varieties

    FROM public.trial_varieties tv

    WHERE public.fn_report_try_uuid(
        to_jsonb(tv) ->> 'trial_id'
    ) = t.id

      AND COALESCE(
            public.fn_report_try_boolean(
                to_jsonb(tv) ->> 'is_active'
            ),
            true
          )

      AND NULLIF(
            to_jsonb(tv) ->> 'deleted_at',
            ''
          ) IS NULL
) variety_data
    ON true

WHERE NULLIF(
    to_jsonb(t) ->> 'deleted_at',
    ''
) IS NULL;

COMMENT ON VIEW public.v_report_trial_register IS
'Complete trial register with master-data names, workflow status, location, varieties, installation data, and audit information.';

CREATE VIEW public.v_report_trial_varieties
WITH (security_invoker = true)
AS
SELECT
    tv.id AS trial_variety_id,

    public.fn_report_try_uuid(
        to_jsonb(tv) ->> 'trial_id'
    ) AS trial_id,

    COALESCE(
        NULLIF(to_jsonb(t) ->> 'business_id', ''),
        NULLIF(to_jsonb(t) ->> 'trial_code', ''),
        NULLIF(to_jsonb(t) ->> 'code', ''),
        t.id::text
    ) AS business_id,

    COALESCE(
        NULLIF(to_jsonb(tv) ->> 'variety_name', ''),
        NULLIF(to_jsonb(tv) ->> 'name', ''),
        NULLIF(to_jsonb(tv) ->> 'variety', '')
    ) AS variety_name,

    COALESCE(
        public.fn_report_try_boolean(
            to_jsonb(tv) ->> 'is_witness'
        ),
        public.fn_report_try_boolean(
            to_jsonb(tv) ->> 'is_witness_variety'
        ),
        false
    ) AS is_witness_variety,

    COALESCE(
        public.fn_report_try_boolean(
            to_jsonb(tv) ->> 'is_leader'
        ),
        public.fn_report_try_boolean(
            to_jsonb(tv) ->> 'is_variety_leader'
        ),
        false
    ) AS is_variety_leader,

    public.fn_report_try_numeric(
        COALESCE(
            to_jsonb(tv) ->> 'display_order',
            to_jsonb(tv) ->> 'sort_order',
            to_jsonb(tv) ->> 'position'
        )
    ) AS display_order,

    COALESCE(
        NULLIF(to_jsonb(tv) ->> 'remarks', ''),
        NULLIF(to_jsonb(tv) ->> 'notes', '')
    ) AS remarks,

    public.fn_report_try_timestamptz(
        to_jsonb(tv) ->> 'created_at'
    ) AS created_at,

    public.fn_report_try_timestamptz(
        to_jsonb(tv) ->> 'updated_at'
    ) AS updated_at

FROM public.trial_varieties tv

JOIN public.trials t
    ON t.id = public.fn_report_try_uuid(
        to_jsonb(tv) ->> 'trial_id'
    )

WHERE COALESCE(
        public.fn_report_try_boolean(
            to_jsonb(tv) ->> 'is_active'
        ),
        true
      )

  AND NULLIF(
        to_jsonb(tv) ->> 'deleted_at',
        ''
      ) IS NULL

  AND NULLIF(
        to_jsonb(t) ->> 'deleted_at',
        ''
      ) IS NULL;

COMMENT ON VIEW public.v_report_trial_varieties IS
'One reporting row per trial variety, including witness and leader indicators.';

CREATE VIEW public.v_report_evaluations
WITH (security_invoker = true)
AS
SELECT
    e.id AS evaluation_id,

    public.fn_report_try_uuid(
        to_jsonb(e) ->> 'trial_id'
    ) AS trial_id,

    COALESCE(
        NULLIF(to_jsonb(t) ->> 'business_id', ''),
        NULLIF(to_jsonb(t) ->> 'trial_code', ''),
        NULLIF(to_jsonb(t) ->> 'code', ''),
        t.id::text
    ) AS business_id,

    COALESCE(
        NULLIF(to_jsonb(et) ->> 'code', ''),
        NULLIF(to_jsonb(et) ->> 'name', ''),
        NULLIF(to_jsonb(e) ->> 'evaluation_type', ''),
        'UNKNOWN'
    ) AS evaluation_type,

    COALESCE(
        public.fn_report_try_date(
            to_jsonb(e) ->> 'evaluation_date'
        ),
        public.fn_report_try_date(
            to_jsonb(e) ->> 'created_at'
        )
    ) AS evaluation_date,

    COALESCE(
        NULLIF(to_jsonb(gs) ->> 'name', ''),
        NULLIF(to_jsonb(gs) ->> 'code', '')
    ) AS growth_stage,

    COALESCE(
        NULLIF(to_jsonb(wc) ->> 'name', ''),
        NULLIF(to_jsonb(wc) ->> 'code', ''),
        NULLIF(to_jsonb(e) ->> 'weather_condition', '')
    ) AS weather_condition,

    COALESCE(
        NULLIF(to_jsonb(rt) ->> 'name', ''),
        NULLIF(to_jsonb(rt) ->> 'code', ''),
        NULLIF(to_jsonb(e) ->> 'recommendation', '')
    ) AS recommendation,

    COALESCE(
        NULLIF(to_jsonb(dt) ->> 'name', ''),
        NULLIF(to_jsonb(dt) ->> 'code', ''),
        NULLIF(to_jsonb(e) ->> 'decision', '')
    ) AS decision,

    COALESCE(
        NULLIF(to_jsonb(e) ->> 'status', ''),
        CASE
            WHEN public.fn_report_try_timestamptz(
                to_jsonb(e) ->> 'completed_at'
            ) IS NOT NULL
                THEN 'COMPLETED'
            ELSE 'IN_PROGRESS'
        END
    ) AS evaluation_status,

    COALESCE(
        NULLIF(to_jsonb(e) ->> 'comments', ''),
        NULLIF(to_jsonb(e) ->> 'remarks', ''),
        NULLIF(to_jsonb(e) ->> 'notes', '')
    ) AS comments,

    COALESCE(
        public.fn_report_try_uuid(
            to_jsonb(e) ->> 'evaluator_user_id'
        ),
        public.fn_report_try_uuid(
            to_jsonb(e) ->> 'evaluated_by'
        ),
        public.fn_report_try_uuid(
            to_jsonb(e) ->> 'created_by'
        )
    ) AS evaluator_user_id,

    NULLIF(
        concat_ws(
            ' ',
            NULLIF(to_jsonb(ep) ->> 'first_name', ''),
            NULLIF(to_jsonb(ep) ->> 'last_name', '')
        ),
        ''
    ) AS evaluator_name,

    result_data.result_count,

    photo_data.photo_count,

    public.fn_report_try_timestamptz(
        to_jsonb(e) ->> 'completed_at'
    ) AS completed_at,

    public.fn_report_try_timestamptz(
        to_jsonb(e) ->> 'created_at'
    ) AS created_at,

    public.fn_report_try_timestamptz(
        to_jsonb(e) ->> 'updated_at'
    ) AS updated_at

FROM public.evaluations e

JOIN public.trials t
    ON t.id = public.fn_report_try_uuid(
        to_jsonb(e) ->> 'trial_id'
    )

LEFT JOIN public.evaluation_types et
    ON et.id = public.fn_report_try_uuid(
        to_jsonb(e) ->> 'evaluation_type_id'
    )

LEFT JOIN public.growth_stages gs
    ON gs.id = public.fn_report_try_uuid(
        to_jsonb(e) ->> 'growth_stage_id'
    )

LEFT JOIN public.weather_conditions wc
    ON wc.id = public.fn_report_try_uuid(
        to_jsonb(e) ->> 'weather_condition_id'
    )

LEFT JOIN public.recommendation_types rt
    ON rt.id = public.fn_report_try_uuid(
        to_jsonb(e) ->> 'recommendation_type_id'
    )

LEFT JOIN public.decision_types dt
    ON dt.id = public.fn_report_try_uuid(
        to_jsonb(e) ->> 'decision_type_id'
    )

LEFT JOIN public.profiles ep
    ON ep.user_id = COALESCE(
        public.fn_report_try_uuid(
            to_jsonb(e) ->> 'evaluator_user_id'
        ),
        public.fn_report_try_uuid(
            to_jsonb(e) ->> 'evaluated_by'
        ),
        public.fn_report_try_uuid(
            to_jsonb(e) ->> 'created_by'
        )
    )

LEFT JOIN LATERAL (
    SELECT count(*)::integer AS result_count
    FROM public.evaluation_details ed
    WHERE public.fn_report_try_uuid(
        to_jsonb(ed) ->> 'evaluation_id'
    ) = e.id
      AND COALESCE(
            public.fn_report_try_boolean(
                to_jsonb(ed) ->> 'is_active'
            ),
            true
          )
      AND NULLIF(
            to_jsonb(ed) ->> 'deleted_at',
            ''
          ) IS NULL
) result_data
    ON true

LEFT JOIN LATERAL (
    SELECT count(*)::integer AS photo_count
    FROM public.evaluation_photos eph
    WHERE public.fn_report_try_uuid(
        to_jsonb(eph) ->> 'evaluation_id'
    ) = e.id
      AND COALESCE(
            public.fn_report_try_boolean(
                to_jsonb(eph) ->> 'is_active'
            ),
            true
          )
      AND NULLIF(
            to_jsonb(eph) ->> 'deleted_at',
            ''
          ) IS NULL
) photo_data
    ON true

WHERE COALESCE(
        public.fn_report_try_boolean(
            to_jsonb(e) ->> 'is_active'
        ),
        true
      )

  AND NULLIF(
        to_jsonb(e) ->> 'deleted_at',
        ''
      ) IS NULL

  AND NULLIF(
        to_jsonb(t) ->> 'deleted_at',
        ''
      ) IS NULL;

COMMENT ON VIEW public.v_report_evaluations IS
'One reporting row per evaluation with type, stage, weather, recommendation, decision, evaluator, result count, and photo count.';

CREATE VIEW public.v_report_evaluation_results
WITH (security_invoker = true)
AS
SELECT
    ed.id AS evaluation_detail_id,

    public.fn_report_try_uuid(
        to_jsonb(ed) ->> 'evaluation_id'
    ) AS evaluation_id,

    public.fn_report_try_uuid(
        to_jsonb(e) ->> 'trial_id'
    ) AS trial_id,

    COALESCE(
        NULLIF(to_jsonb(t) ->> 'business_id', ''),
        NULLIF(to_jsonb(t) ->> 'trial_code', ''),
        NULLIF(to_jsonb(t) ->> 'code', ''),
        t.id::text
    ) AS business_id,

    COALESCE(
        NULLIF(to_jsonb(ec) ->> 'code', ''),
        NULLIF(to_jsonb(ec) ->> 'name', ''),
        ed.id::text
    ) AS criterion_code,

    COALESCE(
        NULLIF(to_jsonb(ec) ->> 'name', ''),
        NULLIF(to_jsonb(ec) ->> 'label', ''),
        NULLIF(to_jsonb(ec) ->> 'code', '')
    ) AS criterion_name,

    COALESCE(
        NULLIF(to_jsonb(ec) ->> 'category', ''),
        NULLIF(to_jsonb(ec) ->> 'section', ''),
        NULLIF(to_jsonb(ec) ->> 'criterion_group', '')
    ) AS criterion_group,

    COALESCE(
        NULLIF(to_jsonb(cdt) ->> 'code', ''),
        NULLIF(to_jsonb(cdt) ->> 'name', ''),
        NULLIF(to_jsonb(ed) ->> 'data_type', '')
    ) AS data_type,

    NULLIF(to_jsonb(ed) ->> 'value_text', '')
        AS value_text,

    public.fn_report_try_numeric(
        COALESCE(
            to_jsonb(ed) ->> 'value_number',
            to_jsonb(ed) ->> 'numeric_value'
        )
    ) AS value_number,

    public.fn_report_try_boolean(
        COALESCE(
            to_jsonb(ed) ->> 'value_boolean',
            to_jsonb(ed) ->> 'boolean_value'
        )
    ) AS value_boolean,

    public.fn_report_try_date(
        COALESCE(
            to_jsonb(ed) ->> 'value_date',
            to_jsonb(ed) ->> 'date_value'
        )
    ) AS value_date,

    option_data.selected_options,

    COALESCE(
        NULLIF(to_jsonb(ed) ->> 'custom_value', ''),
        NULLIF(to_jsonb(ed) ->> 'manual_value', ''),
        NULLIF(to_jsonb(ed) ->> 'other_value', '')
    ) AS custom_value,

    COALESCE(
        NULLIF(to_jsonb(ed) ->> 'value_text', ''),
        NULLIF(
            public.fn_report_try_numeric(
                COALESCE(
                    to_jsonb(ed) ->> 'value_number',
                    to_jsonb(ed) ->> 'numeric_value'
                )
            )::text,
            ''
        ),
        NULLIF(
            public.fn_report_try_boolean(
                COALESCE(
                    to_jsonb(ed) ->> 'value_boolean',
                    to_jsonb(ed) ->> 'boolean_value'
                )
            )::text,
            ''
        ),
        NULLIF(
            public.fn_report_try_date(
                COALESCE(
                    to_jsonb(ed) ->> 'value_date',
                    to_jsonb(ed) ->> 'date_value'
                )
            )::text,
            ''
        ),
        option_data.selected_options,
        NULLIF(to_jsonb(ed) ->> 'custom_value', ''),
        NULLIF(to_jsonb(ed) ->> 'manual_value', ''),
        NULLIF(to_jsonb(ed) ->> 'other_value', '')
    ) AS display_value,

    COALESCE(
        NULLIF(to_jsonb(ed) ->> 'notes', ''),
        NULLIF(to_jsonb(ed) ->> 'remarks', ''),
        NULLIF(to_jsonb(ed) ->> 'comments', '')
    ) AS notes,

    public.fn_report_try_timestamptz(
        to_jsonb(ed) ->> 'created_at'
    ) AS created_at,

    public.fn_report_try_timestamptz(
        to_jsonb(ed) ->> 'updated_at'
    ) AS updated_at

FROM public.evaluation_details ed

JOIN public.evaluations e
    ON e.id = public.fn_report_try_uuid(
        to_jsonb(ed) ->> 'evaluation_id'
    )

JOIN public.trials t
    ON t.id = public.fn_report_try_uuid(
        to_jsonb(e) ->> 'trial_id'
    )

LEFT JOIN public.evaluation_criteria ec
    ON ec.id = public.fn_report_try_uuid(
        COALESCE(
            to_jsonb(ed) ->> 'criterion_id',
            to_jsonb(ed) ->> 'evaluation_criterion_id'
        )
    )

LEFT JOIN public.criterion_data_types cdt
    ON cdt.id = public.fn_report_try_uuid(
        COALESCE(
            to_jsonb(ec) ->> 'data_type_id',
            to_jsonb(ec) ->> 'criterion_data_type_id'
        )
    )

LEFT JOIN LATERAL (
    SELECT
        NULLIF(
            array_to_string(
                array_agg(
                    DISTINCT COALESCE(
                        NULLIF(to_jsonb(co) ->> 'label', ''),
                        NULLIF(to_jsonb(co) ->> 'name', ''),
                        NULLIF(to_jsonb(co) ->> 'code', ''),
                        NULLIF(to_jsonb(edo) ->> 'custom_value', '')
                    )
                ) FILTER (
                    WHERE COALESCE(
                        NULLIF(to_jsonb(co) ->> 'label', ''),
                        NULLIF(to_jsonb(co) ->> 'name', ''),
                        NULLIF(to_jsonb(co) ->> 'code', ''),
                        NULLIF(to_jsonb(edo) ->> 'custom_value', '')
                    ) IS NOT NULL
                ),
                ', '
            ),
            ''
        ) AS selected_options

    FROM public.evaluation_detail_options edo

    LEFT JOIN public.criterion_options co
        ON co.id = public.fn_report_try_uuid(
            COALESCE(
                to_jsonb(edo) ->> 'criterion_option_id',
                to_jsonb(edo) ->> 'option_id'
            )
        )

    WHERE public.fn_report_try_uuid(
        COALESCE(
            to_jsonb(edo) ->> 'evaluation_detail_id',
            to_jsonb(edo) ->> 'detail_id'
        )
    ) = ed.id

      AND NULLIF(
            to_jsonb(edo) ->> 'deleted_at',
            ''
          ) IS NULL
) option_data
    ON true

WHERE COALESCE(
        public.fn_report_try_boolean(
            to_jsonb(ed) ->> 'is_active'
        ),
        true
      )

  AND NULLIF(
        to_jsonb(ed) ->> 'deleted_at',
        ''
      ) IS NULL

  AND COALESCE(
        public.fn_report_try_boolean(
            to_jsonb(e) ->> 'is_active'
        ),
        true
      )

  AND NULLIF(
        to_jsonb(e) ->> 'deleted_at',
        ''
      ) IS NULL

  AND NULLIF(
        to_jsonb(t) ->> 'deleted_at',
        ''
      ) IS NULL;

COMMENT ON VIEW public.v_report_evaluation_results IS
'Flattened evaluation result dataset containing criterion metadata, typed values, selected options, custom values, and display-ready output.';

CREATE VIEW public.v_report_trial_status_history
WITH (security_invoker = true)
AS
SELECT
    tsh.id AS status_history_id,

    public.fn_report_try_uuid(
        to_jsonb(tsh) ->> 'trial_id'
    ) AS trial_id,

    COALESCE(
        NULLIF(to_jsonb(t) ->> 'business_id', ''),
        NULLIF(to_jsonb(t) ->> 'trial_code', ''),
        NULLIF(to_jsonb(t) ->> 'code', ''),
        t.id::text
    ) AS business_id,

    COALESCE(
        NULLIF(to_jsonb(from_status) ->> 'code', ''),
        NULLIF(to_jsonb(from_status) ->> 'name', ''),
        NULLIF(to_jsonb(tsh) ->> 'from_status', ''),
        NULLIF(to_jsonb(tsh) ->> 'old_status', '')
    ) AS previous_status,

    COALESCE(
        NULLIF(to_jsonb(to_status) ->> 'code', ''),
        NULLIF(to_jsonb(to_status) ->> 'name', ''),
        NULLIF(to_jsonb(tsh) ->> 'to_status', ''),
        NULLIF(to_jsonb(tsh) ->> 'new_status', '')
    ) AS new_status,

    COALESCE(
        NULLIF(to_jsonb(tsh) ->> 'reason', ''),
        NULLIF(to_jsonb(tsh) ->> 'comment', ''),
        NULLIF(to_jsonb(tsh) ->> 'comments', ''),
        NULLIF(to_jsonb(tsh) ->> 'notes', '')
    ) AS change_reason,

    COALESCE(
        public.fn_report_try_uuid(
            to_jsonb(tsh) ->> 'changed_by'
        ),
        public.fn_report_try_uuid(
            to_jsonb(tsh) ->> 'created_by'
        )
    ) AS changed_by_user_id,

    NULLIF(
        concat_ws(
            ' ',
            NULLIF(to_jsonb(changer) ->> 'first_name', ''),
            NULLIF(to_jsonb(changer) ->> 'last_name', '')
        ),
        ''
    ) AS changed_by_name,

    COALESCE(
        public.fn_report_try_timestamptz(
            to_jsonb(tsh) ->> 'changed_at'
        ),
        public.fn_report_try_timestamptz(
            to_jsonb(tsh) ->> 'created_at'
        )
    ) AS changed_at

FROM public.trial_status_history tsh

JOIN public.trials t
    ON t.id = public.fn_report_try_uuid(
        to_jsonb(tsh) ->> 'trial_id'
    )

LEFT JOIN public.trial_statuses from_status
    ON from_status.id = public.fn_report_try_uuid(
        COALESCE(
            to_jsonb(tsh) ->> 'from_status_id',
            to_jsonb(tsh) ->> 'old_status_id'
        )
    )

LEFT JOIN public.trial_statuses to_status
    ON to_status.id = public.fn_report_try_uuid(
        COALESCE(
            to_jsonb(tsh) ->> 'to_status_id',
            to_jsonb(tsh) ->> 'new_status_id',
            to_jsonb(tsh) ->> 'status_id'
        )
    )

LEFT JOIN public.profiles changer
    ON changer.user_id = COALESCE(
        public.fn_report_try_uuid(
            to_jsonb(tsh) ->> 'changed_by'
        ),
        public.fn_report_try_uuid(
            to_jsonb(tsh) ->> 'created_by'
        )
    )

WHERE NULLIF(
        to_jsonb(tsh) ->> 'deleted_at',
        ''
      ) IS NULL

  AND NULLIF(
        to_jsonb(t) ->> 'deleted_at',
        ''
      ) IS NULL;

COMMENT ON VIEW public.v_report_trial_status_history IS
'Trial workflow history with previous status, new status, reason, actor, and change timestamp.';

CREATE VIEW public.v_report_media_inventory
WITH (security_invoker = true)
AS
SELECT
    tp.id AS media_id,
    'TRIAL'::text AS media_scope,
    public.fn_report_try_uuid(
        to_jsonb(tp) ->> 'trial_id'
    ) AS trial_id,
    NULL::uuid AS evaluation_id,

    COALESCE(
        NULLIF(to_jsonb(tp) ->> 'storage_path', ''),
        NULLIF(to_jsonb(tp) ->> 'file_path', ''),
        NULLIF(to_jsonb(tp) ->> 'path', ''),
        NULLIF(to_jsonb(tp) ->> 'url', '')
    ) AS storage_path,

    COALESCE(
        NULLIF(to_jsonb(tp) ->> 'file_name', ''),
        NULLIF(to_jsonb(tp) ->> 'original_filename', ''),
        NULLIF(to_jsonb(tp) ->> 'name', '')
    ) AS file_name,

    COALESCE(
        NULLIF(to_jsonb(tp) ->> 'mime_type', ''),
        NULLIF(to_jsonb(tp) ->> 'content_type', '')
    ) AS mime_type,

    public.fn_report_try_numeric(
        COALESCE(
            to_jsonb(tp) ->> 'file_size_bytes',
            to_jsonb(tp) ->> 'size_bytes',
            to_jsonb(tp) ->> 'file_size'
        )
    ) AS file_size_bytes,

    COALESCE(
        NULLIF(to_jsonb(tp) ->> 'caption', ''),
        NULLIF(to_jsonb(tp) ->> 'description', ''),
        NULLIF(to_jsonb(tp) ->> 'notes', '')
    ) AS caption,

    COALESCE(
        public.fn_report_try_uuid(
            to_jsonb(tp) ->> 'uploaded_by'
        ),
        public.fn_report_try_uuid(
            to_jsonb(tp) ->> 'created_by'
        )
    ) AS uploaded_by_user_id,

    public.fn_report_try_timestamptz(
        to_jsonb(tp) ->> 'created_at'
    ) AS uploaded_at

FROM public.trial_photos tp

WHERE COALESCE(
        public.fn_report_try_boolean(
            to_jsonb(tp) ->> 'is_active'
        ),
        true
      )

  AND NULLIF(
        to_jsonb(tp) ->> 'deleted_at',
        ''
      ) IS NULL

UNION ALL

SELECT
    ep.id AS media_id,
    'EVALUATION'::text AS media_scope,
    public.fn_report_try_uuid(
        to_jsonb(e) ->> 'trial_id'
    ) AS trial_id,
    public.fn_report_try_uuid(
        to_jsonb(ep) ->> 'evaluation_id'
    ) AS evaluation_id,

    COALESCE(
        NULLIF(to_jsonb(ep) ->> 'storage_path', ''),
        NULLIF(to_jsonb(ep) ->> 'file_path', ''),
        NULLIF(to_jsonb(ep) ->> 'path', ''),
        NULLIF(to_jsonb(ep) ->> 'url', '')
    ) AS storage_path,

    COALESCE(
        NULLIF(to_jsonb(ep) ->> 'file_name', ''),
        NULLIF(to_jsonb(ep) ->> 'original_filename', ''),
        NULLIF(to_jsonb(ep) ->> 'name', '')
    ) AS file_name,

    COALESCE(
        NULLIF(to_jsonb(ep) ->> 'mime_type', ''),
        NULLIF(to_jsonb(ep) ->> 'content_type', '')
    ) AS mime_type,

    public.fn_report_try_numeric(
        COALESCE(
            to_jsonb(ep) ->> 'file_size_bytes',
            to_jsonb(ep) ->> 'size_bytes',
            to_jsonb(ep) ->> 'file_size'
        )
    ) AS file_size_bytes,

    COALESCE(
        NULLIF(to_jsonb(ep) ->> 'caption', ''),
        NULLIF(to_jsonb(ep) ->> 'description', ''),
        NULLIF(to_jsonb(ep) ->> 'notes', '')
    ) AS caption,

    COALESCE(
        public.fn_report_try_uuid(
            to_jsonb(ep) ->> 'uploaded_by'
        ),
        public.fn_report_try_uuid(
            to_jsonb(ep) ->> 'created_by'
        )
    ) AS uploaded_by_user_id,

    public.fn_report_try_timestamptz(
        to_jsonb(ep) ->> 'created_at'
    ) AS uploaded_at

FROM public.evaluation_photos ep

JOIN public.evaluations e
    ON e.id = public.fn_report_try_uuid(
        to_jsonb(ep) ->> 'evaluation_id'
    )

WHERE COALESCE(
        public.fn_report_try_boolean(
            to_jsonb(ep) ->> 'is_active'
        ),
        true
      )

  AND NULLIF(
        to_jsonb(ep) ->> 'deleted_at',
        ''
      ) IS NULL

  AND COALESCE(
        public.fn_report_try_boolean(
            to_jsonb(e) ->> 'is_active'
        ),
        true
      )

  AND NULLIF(
        to_jsonb(e) ->> 'deleted_at',
        ''
      ) IS NULL;

COMMENT ON VIEW public.v_report_media_inventory IS
'Unified inventory of trial and evaluation media records.';

CREATE VIEW public.v_report_executive_summary
WITH (security_invoker = true)
AS
SELECT
    1::smallint AS row_id,

    trial_metrics.total_trials,

    trial_metrics.pending_approval_trials,

    trial_metrics.approved_trials,

    trial_metrics.rejected_trials,

    trial_metrics.corrections_requested_trials,

    trial_metrics.crops_covered,

    trial_metrics.regions_covered,

    trial_metrics.grower_farm_trials,

    trial_metrics.experimental_station_trials,

    evaluation_metrics.total_evaluations,

    evaluation_metrics.evaluated_trials,

    evaluation_metrics.completed_evaluations,

    media_metrics.total_media_files,

    media_metrics.trial_media_files,

    media_metrics.evaluation_media_files,

    now() AS generated_at

FROM (
    SELECT
        count(*)::bigint AS total_trials,

        count(*) FILTER (
            WHERE upper(status_key) IN (
                'PENDING_APPROVAL',
                'PENDING',
                'SUBMITTED'
            )
        )::bigint AS pending_approval_trials,

        count(*) FILTER (
            WHERE upper(status_key) = 'APPROVED'
        )::bigint AS approved_trials,

        count(*) FILTER (
            WHERE upper(status_key) = 'REJECTED'
        )::bigint AS rejected_trials,

        count(*) FILTER (
            WHERE upper(status_key) IN (
                'CORRECTIONS_REQUESTED',
                'CORRECTION_REQUESTED',
                'NEEDS_CORRECTION'
            )
        )::bigint AS corrections_requested_trials,

        count(DISTINCT crop_name) FILTER (
            WHERE crop_name IS NOT NULL
        )::bigint AS crops_covered,

        count(DISTINCT region_name) FILTER (
            WHERE region_name IS NOT NULL
        )::bigint AS regions_covered,

        count(*) FILTER (
            WHERE location_type = 'GROWER_FARM'
        )::bigint AS grower_farm_trials,

        count(*) FILTER (
            WHERE location_type = 'EXPERIMENTAL_STATION'
        )::bigint AS experimental_station_trials

    FROM public.v_report_trial_register
) trial_metrics

CROSS JOIN (
    SELECT
        count(*)::bigint AS total_evaluations,

        count(DISTINCT trial_id)::bigint AS evaluated_trials,

        count(*) FILTER (
            WHERE upper(evaluation_status) IN (
                'COMPLETED',
                'FINALIZED',
                'SUBMITTED'
            )
        )::bigint AS completed_evaluations

    FROM public.v_report_evaluations
) evaluation_metrics

CROSS JOIN (
    SELECT
        count(*)::bigint AS total_media_files,

        count(*) FILTER (
            WHERE media_scope = 'TRIAL'
        )::bigint AS trial_media_files,

        count(*) FILTER (
            WHERE media_scope = 'EVALUATION'
        )::bigint AS evaluation_media_files

    FROM public.v_report_media_inventory
) media_metrics;

COMMENT ON VIEW public.v_report_executive_summary IS
'Single-row executive reporting summary across trials, evaluations, locations, crops, regions, and media.';

REVOKE ALL
ON TABLE public.v_report_trial_register
FROM PUBLIC, anon;

REVOKE ALL
ON TABLE public.v_report_trial_varieties
FROM PUBLIC, anon;

REVOKE ALL
ON TABLE public.v_report_evaluations
FROM PUBLIC, anon;

REVOKE ALL
ON TABLE public.v_report_evaluation_results
FROM PUBLIC, anon;

REVOKE ALL
ON TABLE public.v_report_trial_status_history
FROM PUBLIC, anon;

REVOKE ALL
ON TABLE public.v_report_media_inventory
FROM PUBLIC, anon;

REVOKE ALL
ON TABLE public.v_report_executive_summary
FROM PUBLIC, anon;

GRANT SELECT
ON TABLE public.v_report_trial_register
TO authenticated, service_role;

GRANT SELECT
ON TABLE public.v_report_trial_varieties
TO authenticated, service_role;

GRANT SELECT
ON TABLE public.v_report_evaluations
TO authenticated, service_role;

GRANT SELECT
ON TABLE public.v_report_evaluation_results
TO authenticated, service_role;

GRANT SELECT
ON TABLE public.v_report_trial_status_history
TO authenticated, service_role;

GRANT SELECT
ON TABLE public.v_report_media_inventory
TO authenticated, service_role;

GRANT SELECT
ON TABLE public.v_report_executive_summary
TO authenticated, service_role;

REVOKE ALL
ON FUNCTION public.fn_report_try_uuid(text)
FROM PUBLIC, anon;

REVOKE ALL
ON FUNCTION public.fn_report_try_date(text)
FROM PUBLIC, anon;

REVOKE ALL
ON FUNCTION public.fn_report_try_timestamptz(text)
FROM PUBLIC, anon;

REVOKE ALL
ON FUNCTION public.fn_report_try_numeric(text)
FROM PUBLIC, anon;

REVOKE ALL
ON FUNCTION public.fn_report_try_boolean(text)
FROM PUBLIC, anon;

GRANT EXECUTE
ON FUNCTION public.fn_report_try_uuid(text)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_report_try_date(text)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_report_try_timestamptz(text)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_report_try_numeric(text)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_report_try_boolean(text)
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
            59,
            '0059_reporting_views.sql'
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
    IF to_regclass('public.v_report_trial_register') IS NULL THEN
        RAISE EXCEPTION 'View public.v_report_trial_register was not created.';
    END IF;

    IF to_regclass('public.v_report_trial_varieties') IS NULL THEN
        RAISE EXCEPTION 'View public.v_report_trial_varieties was not created.';
    END IF;

    IF to_regclass('public.v_report_evaluations') IS NULL THEN
        RAISE EXCEPTION 'View public.v_report_evaluations was not created.';
    END IF;

    IF to_regclass('public.v_report_evaluation_results') IS NULL THEN
        RAISE EXCEPTION 'View public.v_report_evaluation_results was not created.';
    END IF;

    IF to_regclass('public.v_report_trial_status_history') IS NULL THEN
        RAISE EXCEPTION 'View public.v_report_trial_status_history was not created.';
    END IF;

    IF to_regclass('public.v_report_media_inventory') IS NULL THEN
        RAISE EXCEPTION 'View public.v_report_media_inventory was not created.';
    END IF;

    IF to_regclass('public.v_report_executive_summary') IS NULL THEN
        RAISE EXCEPTION 'View public.v_report_executive_summary was not created.';
    END IF;

    IF to_regprocedure('public.fn_report_try_uuid(text)') IS NULL THEN
        RAISE EXCEPTION 'Function public.fn_report_try_uuid was not created.';
    END IF;

    IF to_regprocedure('public.fn_report_try_date(text)') IS NULL THEN
        RAISE EXCEPTION 'Function public.fn_report_try_date was not created.';
    END IF;

    IF to_regprocedure('public.fn_report_try_timestamptz(text)') IS NULL THEN
        RAISE EXCEPTION 'Function public.fn_report_try_timestamptz was not created.';
    END IF;

    IF to_regprocedure('public.fn_report_try_numeric(text)') IS NULL THEN
        RAISE EXCEPTION 'Function public.fn_report_try_numeric was not created.';
    END IF;

    IF to_regprocedure('public.fn_report_try_boolean(text)') IS NULL THEN
        RAISE EXCEPTION 'Function public.fn_report_try_boolean was not created.';
    END IF;

    RAISE NOTICE '0059_reporting_views.sql completed successfully.';
END;
$$;

COMMIT;
