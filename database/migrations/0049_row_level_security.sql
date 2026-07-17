-- ============================================================
-- AgriTrial Pro
-- Migration: 0049_row_level_security.sql
-- Purpose: Enable Row Level Security and create access policies
-- ============================================================

BEGIN;

SET search_path = public, auth, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

-- ============================================================
-- 1. ENABLE ROW LEVEL SECURITY
-- ============================================================

DO $$
DECLARE
    v_table_name text;
    v_tables text[] := ARRAY[
        'roles',
        'profiles',
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
        'trials',
        'trial_varieties',
        'trial_photos',
        'trial_status_history',
        'evaluations',
        'evaluation_details',
        'evaluation_detail_options',
        'evaluation_photos',
        'generated_reports',
        'report_templates'
    ];
BEGIN
    FOREACH v_table_name IN ARRAY v_tables
    LOOP
        IF to_regclass(
            format(
                'public.%I',
                v_table_name
            )
        ) IS NOT NULL THEN
            EXECUTE format(
                'ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY',
                v_table_name
            );
        END IF;
    END LOOP;
END;
$$;

-- ============================================================
-- 2. ROLES POLICIES
-- ============================================================

DROP POLICY IF EXISTS roles_select_authenticated
ON public.roles;

DROP POLICY IF EXISTS roles_insert_general_director
ON public.roles;

DROP POLICY IF EXISTS roles_update_general_director
ON public.roles;

DROP POLICY IF EXISTS roles_delete_general_director
ON public.roles;

CREATE POLICY roles_select_authenticated
ON public.roles
FOR SELECT
TO authenticated
USING (
    public.fn_current_user_is_active()
);

CREATE POLICY roles_insert_general_director
ON public.roles
FOR INSERT
TO authenticated
WITH CHECK (
    public.fn_can_manage_users()
);

CREATE POLICY roles_update_general_director
ON public.roles
FOR UPDATE
TO authenticated
USING (
    public.fn_can_manage_users()
)
WITH CHECK (
    public.fn_can_manage_users()
);

CREATE POLICY roles_delete_general_director
ON public.roles
FOR DELETE
TO authenticated
USING (
    public.fn_can_manage_users()
);

-- ============================================================
-- 3. PROFILES POLICIES
-- ============================================================

DROP POLICY IF EXISTS profiles_select_authorized
ON public.profiles;

DROP POLICY IF EXISTS profiles_insert_general_director
ON public.profiles;

DROP POLICY IF EXISTS profiles_update_authorized
ON public.profiles;

DROP POLICY IF EXISTS profiles_delete_general_director
ON public.profiles;

CREATE POLICY profiles_select_authorized
ON public.profiles
FOR SELECT
TO authenticated
USING (
    public.fn_current_user_is_active()
    AND (
        user_id = auth.uid()
        OR public.fn_is_management()
    )
);

CREATE POLICY profiles_insert_general_director
ON public.profiles
FOR INSERT
TO authenticated
WITH CHECK (
    public.fn_can_manage_users()
);

CREATE POLICY profiles_update_authorized
ON public.profiles
FOR UPDATE
TO authenticated
USING (
    public.fn_current_user_is_active()
    AND (
        user_id = auth.uid()
        OR public.fn_can_manage_users()
    )
)
WITH CHECK (
    public.fn_current_user_is_active()
    AND (
        user_id = auth.uid()
        OR public.fn_can_manage_users()
    )
);

CREATE POLICY profiles_delete_general_director
ON public.profiles
FOR DELETE
TO authenticated
USING (
    public.fn_can_manage_users()
);

-- ============================================================
-- 4. MASTER DATA POLICIES
-- ============================================================

DO $$
DECLARE
    v_table_name text;
    v_master_tables text[] := ARRAY[
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
        'criterion_assignments'
    ];
BEGIN
    FOREACH v_table_name IN ARRAY v_master_tables
    LOOP
        IF to_regclass(
            format(
                'public.%I',
                v_table_name
            )
        ) IS NOT NULL THEN

            EXECUTE format(
                'DROP POLICY IF EXISTS %I ON public.%I',
                v_table_name || '_select_authenticated',
                v_table_name
            );

            EXECUTE format(
                'DROP POLICY IF EXISTS %I ON public.%I',
                v_table_name || '_insert_management',
                v_table_name
            );

            EXECUTE format(
                'DROP POLICY IF EXISTS %I ON public.%I',
                v_table_name || '_update_management',
                v_table_name
            );

            EXECUTE format(
                'DROP POLICY IF EXISTS %I ON public.%I',
                v_table_name || '_delete_management',
                v_table_name
            );

            EXECUTE format(
                'CREATE POLICY %I
                 ON public.%I
                 FOR SELECT
                 TO authenticated
                 USING (
                     public.fn_current_user_is_active()
                 )',
                v_table_name || '_select_authenticated',
                v_table_name
            );

            EXECUTE format(
                'CREATE POLICY %I
                 ON public.%I
                 FOR INSERT
                 TO authenticated
                 WITH CHECK (
                     public.fn_can_manage_master_data()
                 )',
                v_table_name || '_insert_management',
                v_table_name
            );

            EXECUTE format(
                'CREATE POLICY %I
                 ON public.%I
                 FOR UPDATE
                 TO authenticated
                 USING (
                     public.fn_can_manage_master_data()
                 )
                 WITH CHECK (
                     public.fn_can_manage_master_data()
                 )',
                v_table_name || '_update_management',
                v_table_name
            );

            EXECUTE format(
                'CREATE POLICY %I
                 ON public.%I
                 FOR DELETE
                 TO authenticated
                 USING (
                     public.fn_can_manage_master_data()
                 )',
                v_table_name || '_delete_management',
                v_table_name
            );
        END IF;
    END LOOP;
END;
$$;

-- ============================================================
-- 5. TRIALS POLICIES
-- ============================================================

DROP POLICY IF EXISTS trials_select_authenticated
ON public.trials;

DROP POLICY IF EXISTS trials_insert_authorized
ON public.trials;

DROP POLICY IF EXISTS trials_update_authorized
ON public.trials;

DROP POLICY IF EXISTS trials_delete_management
ON public.trials;

CREATE POLICY trials_select_authenticated
ON public.trials
FOR SELECT
TO authenticated
USING (
    public.fn_current_user_is_active()
    AND deleted_at IS NULL
);

CREATE POLICY trials_insert_authorized
ON public.trials
FOR INSERT
TO authenticated
WITH CHECK (
    public.fn_current_user_is_active()
    AND (
        public.fn_is_trial_officer()
        OR public.fn_is_management()
    )
    AND created_by = auth.uid()
);

CREATE POLICY trials_update_authorized
ON public.trials
FOR UPDATE
TO authenticated
USING (
    public.fn_can_modify_trial(id)
)
WITH CHECK (
    public.fn_current_user_is_active()
    AND (
        public.fn_is_management()
        OR created_by = auth.uid()
    )
);

CREATE POLICY trials_delete_management
ON public.trials
FOR DELETE
TO authenticated
USING (
    public.fn_is_management()
);

-- ============================================================
-- 6. TRIAL VARIETIES POLICIES
-- ============================================================

DROP POLICY IF EXISTS trial_varieties_select_authorized
ON public.trial_varieties;

DROP POLICY IF EXISTS trial_varieties_insert_authorized
ON public.trial_varieties;

DROP POLICY IF EXISTS trial_varieties_update_authorized
ON public.trial_varieties;

DROP POLICY IF EXISTS trial_varieties_delete_authorized
ON public.trial_varieties;

CREATE POLICY trial_varieties_select_authorized
ON public.trial_varieties
FOR SELECT
TO authenticated
USING (
    deleted_at IS NULL
    AND public.fn_can_access_trial(trial_id)
);

CREATE POLICY trial_varieties_insert_authorized
ON public.trial_varieties
FOR INSERT
TO authenticated
WITH CHECK (
    public.fn_can_modify_trial(trial_id)
);

CREATE POLICY trial_varieties_update_authorized
ON public.trial_varieties
FOR UPDATE
TO authenticated
USING (
    public.fn_can_modify_trial(trial_id)
)
WITH CHECK (
    public.fn_can_modify_trial(trial_id)
);

CREATE POLICY trial_varieties_delete_authorized
ON public.trial_varieties
FOR DELETE
TO authenticated
USING (
    public.fn_can_modify_trial(trial_id)
);

-- ============================================================
-- 7. TRIAL PHOTOS POLICIES
-- ============================================================

DROP POLICY IF EXISTS trial_photos_select_authorized
ON public.trial_photos;

DROP POLICY IF EXISTS trial_photos_insert_authorized
ON public.trial_photos;

DROP POLICY IF EXISTS trial_photos_update_authorized
ON public.trial_photos;

DROP POLICY IF EXISTS trial_photos_delete_authorized
ON public.trial_photos;

CREATE POLICY trial_photos_select_authorized
ON public.trial_photos
FOR SELECT
TO authenticated
USING (
    deleted_at IS NULL
    AND public.fn_can_access_trial(trial_id)
);

CREATE POLICY trial_photos_insert_authorized
ON public.trial_photos
FOR INSERT
TO authenticated
WITH CHECK (
    public.fn_can_modify_trial(trial_id)
);

CREATE POLICY trial_photos_update_authorized
ON public.trial_photos
FOR UPDATE
TO authenticated
USING (
    public.fn_can_modify_trial(trial_id)
)
WITH CHECK (
    public.fn_can_modify_trial(trial_id)
);

CREATE POLICY trial_photos_delete_authorized
ON public.trial_photos
FOR DELETE
TO authenticated
USING (
    public.fn_can_modify_trial(trial_id)
);

-- ============================================================
-- 8. TRIAL STATUS HISTORY POLICIES
-- ============================================================

DROP POLICY IF EXISTS trial_status_history_select_authorized
ON public.trial_status_history;

DROP POLICY IF EXISTS trial_status_history_insert_authorized
ON public.trial_status_history;

DROP POLICY IF EXISTS trial_status_history_update_denied
ON public.trial_status_history;

DROP POLICY IF EXISTS trial_status_history_delete_management
ON public.trial_status_history;

CREATE POLICY trial_status_history_select_authorized
ON public.trial_status_history
FOR SELECT
TO authenticated
USING (
    public.fn_can_access_trial(trial_id)
);

CREATE POLICY trial_status_history_insert_authorized
ON public.trial_status_history
FOR INSERT
TO authenticated
WITH CHECK (
    public.fn_current_user_is_active()
    AND (
        public.fn_can_review_trials()
        OR public.fn_is_trial_creator(trial_id)
    )
);

CREATE POLICY trial_status_history_delete_management
ON public.trial_status_history
FOR DELETE
TO authenticated
USING (
    public.fn_is_management()
);

-- ============================================================
-- 9. EVALUATIONS POLICIES
-- ============================================================

DROP POLICY IF EXISTS evaluations_select_authorized
ON public.evaluations;

DROP POLICY IF EXISTS evaluations_insert_authorized
ON public.evaluations;

DROP POLICY IF EXISTS evaluations_update_authorized
ON public.evaluations;

DROP POLICY IF EXISTS evaluations_delete_authorized
ON public.evaluations;

CREATE POLICY evaluations_select_authorized
ON public.evaluations
FOR SELECT
TO authenticated
USING (
    deleted_at IS NULL
    AND public.fn_can_access_trial(trial_id)
);

CREATE POLICY evaluations_insert_authorized
ON public.evaluations
FOR INSERT
TO authenticated
WITH CHECK (
    public.fn_current_user_is_active()
    AND public.fn_can_access_trial(trial_id)
    AND (
        public.fn_is_trial_officer()
        OR public.fn_is_management()
    )
    AND created_by = auth.uid()
);

CREATE POLICY evaluations_update_authorized
ON public.evaluations
FOR UPDATE
TO authenticated
USING (
    public.fn_can_modify_evaluation(id)
)
WITH CHECK (
    public.fn_current_user_is_active()
    AND (
        public.fn_is_management()
        OR created_by = auth.uid()
    )
);

CREATE POLICY evaluations_delete_authorized
ON public.evaluations
FOR DELETE
TO authenticated
USING (
    public.fn_can_modify_evaluation(id)
);

-- ============================================================
-- 10. EVALUATION DETAILS POLICIES
-- ============================================================

DROP POLICY IF EXISTS evaluation_details_select_authorized
ON public.evaluation_details;

DROP POLICY IF EXISTS evaluation_details_insert_authorized
ON public.evaluation_details;

DROP POLICY IF EXISTS evaluation_details_update_authorized
ON public.evaluation_details;

DROP POLICY IF EXISTS evaluation_details_delete_authorized
ON public.evaluation_details;

CREATE POLICY evaluation_details_select_authorized
ON public.evaluation_details
FOR SELECT
TO authenticated
USING (
    deleted_at IS NULL
    AND public.fn_can_access_evaluation(evaluation_id)
);

CREATE POLICY evaluation_details_insert_authorized
ON public.evaluation_details
FOR INSERT
TO authenticated
WITH CHECK (
    public.fn_can_modify_evaluation(evaluation_id)
);

CREATE POLICY evaluation_details_update_authorized
ON public.evaluation_details
FOR UPDATE
TO authenticated
USING (
    public.fn_can_modify_evaluation(evaluation_id)
)
WITH CHECK (
    public.fn_can_modify_evaluation(evaluation_id)
);

CREATE POLICY evaluation_details_delete_authorized
ON public.evaluation_details
FOR DELETE
TO authenticated
USING (
    public.fn_can_modify_evaluation(evaluation_id)
);

-- ============================================================
-- 11. EVALUATION DETAIL OPTIONS POLICIES
-- ============================================================

DROP POLICY IF EXISTS evaluation_detail_options_select_authorized
ON public.evaluation_detail_options;

DROP POLICY IF EXISTS evaluation_detail_options_insert_authorized
ON public.evaluation_detail_options;

DROP POLICY IF EXISTS evaluation_detail_options_update_authorized
ON public.evaluation_detail_options;

DROP POLICY IF EXISTS evaluation_detail_options_delete_authorized
ON public.evaluation_detail_options;

CREATE POLICY evaluation_detail_options_select_authorized
ON public.evaluation_detail_options
FOR SELECT
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.evaluation_details ed
        WHERE ed.id = evaluation_detail_id
          AND ed.deleted_at IS NULL
          AND public.fn_can_access_evaluation(
                ed.evaluation_id
              )
    )
);

CREATE POLICY evaluation_detail_options_insert_authorized
ON public.evaluation_detail_options
FOR INSERT
TO authenticated
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.evaluation_details ed
        WHERE ed.id = evaluation_detail_id
          AND ed.deleted_at IS NULL
          AND public.fn_can_modify_evaluation(
                ed.evaluation_id
              )
    )
);

CREATE POLICY evaluation_detail_options_update_authorized
ON public.evaluation_detail_options
FOR UPDATE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.evaluation_details ed
        WHERE ed.id = evaluation_detail_id
          AND ed.deleted_at IS NULL
          AND public.fn_can_modify_evaluation(
                ed.evaluation_id
              )
    )
)
WITH CHECK (
    EXISTS (
        SELECT 1
        FROM public.evaluation_details ed
        WHERE ed.id = evaluation_detail_id
          AND ed.deleted_at IS NULL
          AND public.fn_can_modify_evaluation(
                ed.evaluation_id
              )
    )
);

CREATE POLICY evaluation_detail_options_delete_authorized
ON public.evaluation_detail_options
FOR DELETE
TO authenticated
USING (
    EXISTS (
        SELECT 1
        FROM public.evaluation_details ed
        WHERE ed.id = evaluation_detail_id
          AND ed.deleted_at IS NULL
          AND public.fn_can_modify_evaluation(
                ed.evaluation_id
              )
    )
);

-- ============================================================
-- 12. EVALUATION PHOTOS POLICIES
-- ============================================================

DROP POLICY IF EXISTS evaluation_photos_select_authorized
ON public.evaluation_photos;

DROP POLICY IF EXISTS evaluation_photos_insert_authorized
ON public.evaluation_photos;

DROP POLICY IF EXISTS evaluation_photos_update_authorized
ON public.evaluation_photos;

DROP POLICY IF EXISTS evaluation_photos_delete_authorized
ON public.evaluation_photos;

CREATE POLICY evaluation_photos_select_authorized
ON public.evaluation_photos
FOR SELECT
TO authenticated
USING (
    deleted_at IS NULL
    AND public.fn_can_access_evaluation(evaluation_id)
);

CREATE POLICY evaluation_photos_insert_authorized
ON public.evaluation_photos
FOR INSERT
TO authenticated
WITH CHECK (
    public.fn_can_modify_evaluation(evaluation_id)
);

CREATE POLICY evaluation_photos_update_authorized
ON public.evaluation_photos
FOR UPDATE
TO authenticated
USING (
    public.fn_can_modify_evaluation(evaluation_id)
)
WITH CHECK (
    public.fn_can_modify_evaluation(evaluation_id)
);

CREATE POLICY evaluation_photos_delete_authorized
ON public.evaluation_photos
FOR DELETE
TO authenticated
USING (
    public.fn_can_modify_evaluation(evaluation_id)
);

-- ============================================================
-- 13. GENERATED REPORTS POLICIES
-- ============================================================

DROP POLICY IF EXISTS generated_reports_select_authorized
ON public.generated_reports;

DROP POLICY IF EXISTS generated_reports_insert_authorized
ON public.generated_reports;

DROP POLICY IF EXISTS generated_reports_update_management
ON public.generated_reports;

DROP POLICY IF EXISTS generated_reports_delete_management
ON public.generated_reports;

CREATE POLICY generated_reports_select_authorized
ON public.generated_reports
FOR SELECT
TO authenticated
USING (
    deleted_at IS NULL
    AND public.fn_current_user_is_active()
    AND (
        requested_by = auth.uid()
        OR public.fn_is_management()
        OR (
            trial_id IS NOT NULL
            AND public.fn_can_access_trial(trial_id)
        )
        OR (
            evaluation_id IS NOT NULL
            AND public.fn_can_access_evaluation(evaluation_id)
        )
    )
);

CREATE POLICY generated_reports_insert_authorized
ON public.generated_reports
FOR INSERT
TO authenticated
WITH CHECK (
    public.fn_current_user_is_active()
    AND requested_by = auth.uid()
);

CREATE POLICY generated_reports_update_management
ON public.generated_reports
FOR UPDATE
TO authenticated
USING (
    public.fn_is_management()
)
WITH CHECK (
    public.fn_is_management()
);

CREATE POLICY generated_reports_delete_management
ON public.generated_reports
FOR DELETE
TO authenticated
USING (
    public.fn_is_management()
);

-- ============================================================
-- 14. REPORT TEMPLATES POLICIES
-- ============================================================

DROP POLICY IF EXISTS report_templates_select_authenticated
ON public.report_templates;

DROP POLICY IF EXISTS report_templates_insert_management
ON public.report_templates;

DROP POLICY IF EXISTS report_templates_update_management
ON public.report_templates;

DROP POLICY IF EXISTS report_templates_delete_management
ON public.report_templates;

CREATE POLICY report_templates_select_authenticated
ON public.report_templates
FOR SELECT
TO authenticated
USING (
    public.fn_current_user_is_active()
);

CREATE POLICY report_templates_insert_management
ON public.report_templates
FOR INSERT
TO authenticated
WITH CHECK (
    public.fn_is_management()
);

CREATE POLICY report_templates_update_management
ON public.report_templates
FOR UPDATE
TO authenticated
USING (
    public.fn_is_management()
)
WITH CHECK (
    public.fn_is_management()
);

CREATE POLICY report_templates_delete_management
ON public.report_templates
FOR DELETE
TO authenticated
USING (
    public.fn_is_management()
);

-- ============================================================
-- 15. TABLE PERMISSIONS
-- ============================================================

DO $$
DECLARE
    v_table_name text;
    v_tables text[] := ARRAY[
        'roles',
        'profiles',
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
        'trials',
        'trial_varieties',
        'trial_photos',
        'trial_status_history',
        'evaluations',
        'evaluation_details',
        'evaluation_detail_options',
        'evaluation_photos',
        'generated_reports',
        'report_templates'
    ];
BEGIN
    FOREACH v_table_name IN ARRAY v_tables
    LOOP
        IF to_regclass(
            format(
                'public.%I',
                v_table_name
            )
        ) IS NOT NULL THEN

            EXECUTE format(
                'REVOKE ALL ON TABLE public.%I FROM anon',
                v_table_name
            );

            EXECUTE format(
                'GRANT SELECT, INSERT, UPDATE, DELETE
                 ON TABLE public.%I
                 TO authenticated',
                v_table_name
            );

            EXECUTE format(
                'GRANT ALL
                 ON TABLE public.%I
                 TO service_role',
                v_table_name
            );
        END IF;
    END LOOP;
END;
$$;

-- ============================================================
-- 16. VALIDATE RLS ENABLEMENT
-- ============================================================

DO $$
DECLARE
    v_missing_rls_tables text[];
BEGIN
    SELECT array_agg(required_table)
    INTO v_missing_rls_tables
    FROM (
        VALUES
            ('roles'),
            ('profiles'),
            ('regions'),
            ('provinces'),
            ('growers'),
            ('farms'),
            ('experimental_stations'),
            ('seasons'),
            ('crops'),
            ('crop_types'),
            ('product_types'),
            ('trial_types'),
            ('witness_varieties'),
            ('growth_stages'),
            ('fruit_shapes'),
            ('fruit_colors'),
            ('fruit_defects'),
            ('recommendation_types'),
            ('decision_types'),
            ('weather_conditions'),
            ('trial_statuses'),
            ('evaluation_types'),
            ('criterion_data_types'),
            ('evaluation_criteria'),
            ('criterion_options'),
            ('criterion_assignments'),
            ('trials'),
            ('trial_varieties'),
            ('trial_photos'),
            ('trial_status_history'),
            ('evaluations'),
            ('evaluation_details'),
            ('evaluation_detail_options'),
            ('evaluation_photos'),
            ('generated_reports'),
            ('report_templates')
    ) AS required(required_table)
    WHERE EXISTS (
        SELECT 1
        FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n
          ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relname = required.required_table
          AND c.relkind = 'r'
          AND c.relrowsecurity = false
    );

    IF v_missing_rls_tables IS NOT NULL THEN
        RAISE EXCEPTION
            'RLS validation failed. RLS is disabled on: %',
            array_to_string(
                v_missing_rls_tables,
                ', '
            );
    END IF;
END;
$$;

-- ============================================================
-- 17. VALIDATE REQUIRED POLICIES
-- ============================================================

DO $$
DECLARE
    v_policy_count integer;
BEGIN
    SELECT COUNT(*)
    INTO v_policy_count
    FROM pg_catalog.pg_policies
    WHERE schemaname = 'public';

    IF v_policy_count < 20 THEN
        RAISE EXCEPTION
            'RLS policy validation failed. Expected at least 20 policies, found %.',
            v_policy_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'trials'
          AND policyname = 'trials_select_authenticated'
    ) THEN
        RAISE EXCEPTION
            'Missing required trials SELECT policy.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'evaluations'
          AND policyname = 'evaluations_select_authorized'
    ) THEN
        RAISE EXCEPTION
            'Missing required evaluations SELECT policy.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_policies
        WHERE schemaname = 'public'
          AND tablename = 'profiles'
          AND policyname = 'profiles_select_authorized'
    ) THEN
        RAISE EXCEPTION
            'Missing required profiles SELECT policy.';
    END IF;

    RAISE NOTICE
        '0049_row_level_security.sql completed successfully with % policies.',
        v_policy_count;
END;
$$;

COMMIT;
