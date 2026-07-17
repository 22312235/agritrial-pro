-- ============================================================
-- AgriTrial Pro
-- Migration: 0048_security_helper_functions.sql
-- Purpose: Authentication, authorization, and RLS helper functions
-- ============================================================

BEGIN;

SET search_path = public, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

-- ============================================================
-- DROP EXISTING FUNCTIONS
-- ============================================================

DROP FUNCTION IF EXISTS public.fn_current_user_id();

DROP FUNCTION IF EXISTS public.fn_current_profile_id();

DROP FUNCTION IF EXISTS public.fn_current_user_role_code();

DROP FUNCTION IF EXISTS public.fn_current_user_role_name();

DROP FUNCTION IF EXISTS public.fn_current_user_is_active();

DROP FUNCTION IF EXISTS public.fn_current_user_has_role(text);

DROP FUNCTION IF EXISTS public.fn_current_user_has_any_role(text[]);

DROP FUNCTION IF EXISTS public.fn_is_trial_officer();

DROP FUNCTION IF EXISTS public.fn_is_manager();

DROP FUNCTION IF EXISTS public.fn_is_general_director();

DROP FUNCTION IF EXISTS public.fn_is_management();

DROP FUNCTION IF EXISTS public.fn_can_manage_master_data();

DROP FUNCTION IF EXISTS public.fn_can_review_trials();

DROP FUNCTION IF EXISTS public.fn_can_manage_users();

DROP FUNCTION IF EXISTS public.fn_is_trial_creator(uuid);

DROP FUNCTION IF EXISTS public.fn_is_evaluation_creator(uuid);

DROP FUNCTION IF EXISTS public.fn_can_access_trial(uuid);

DROP FUNCTION IF EXISTS public.fn_can_modify_trial(uuid);

DROP FUNCTION IF EXISTS public.fn_can_access_evaluation(uuid);

DROP FUNCTION IF EXISTS public.fn_can_modify_evaluation(uuid);

DROP FUNCTION IF EXISTS public.fn_assert_authenticated();

DROP FUNCTION IF EXISTS public.fn_assert_active_profile();

DROP FUNCTION IF EXISTS public.fn_assert_role(text[]);

-- ============================================================
-- 1. CURRENT AUTHENTICATED USER
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_current_user_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT auth.uid();
$$;

COMMENT ON FUNCTION public.fn_current_user_id()
IS 'Returns the UUID of the currently authenticated Supabase user.';

-- ============================================================
-- 2. CURRENT PROFILE ID
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_current_profile_id()
RETURNS uuid
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT p.id
    FROM public.profiles p
    WHERE p.user_id = auth.uid()
      AND p.deleted_at IS NULL
    LIMIT 1;
$$;

COMMENT ON FUNCTION public.fn_current_profile_id()
IS 'Returns the active profile identifier associated with the authenticated user.';

-- ============================================================
-- 3. CURRENT USER ROLE CODE
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_current_user_role_code()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT r.code::text
    FROM public.profiles p
    JOIN public.roles r
      ON r.id = p.role_id
     AND r.deleted_at IS NULL
     AND r.is_active = true
    WHERE p.user_id = auth.uid()
      AND p.deleted_at IS NULL
      AND p.is_active = true
    LIMIT 1;
$$;

COMMENT ON FUNCTION public.fn_current_user_role_code()
IS 'Returns the role code of the currently authenticated active user.';

-- ============================================================
-- 4. CURRENT USER ROLE NAME
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_current_user_role_name()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT r.name::text
    FROM public.profiles p
    JOIN public.roles r
      ON r.id = p.role_id
     AND r.deleted_at IS NULL
     AND r.is_active = true
    WHERE p.user_id = auth.uid()
      AND p.deleted_at IS NULL
      AND p.is_active = true
    LIMIT 1;
$$;

COMMENT ON FUNCTION public.fn_current_user_role_name()
IS 'Returns the role name of the currently authenticated active user.';

-- ============================================================
-- 5. ACTIVE PROFILE CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_current_user_is_active()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles p
        JOIN public.roles r
          ON r.id = p.role_id
         AND r.deleted_at IS NULL
         AND r.is_active = true
        WHERE p.user_id = auth.uid()
          AND p.deleted_at IS NULL
          AND p.is_active = true
    );
$$;

COMMENT ON FUNCTION public.fn_current_user_is_active()
IS 'Returns true when the authenticated user has an active, non-deleted profile and active role.';

-- ============================================================
-- 6. SINGLE ROLE CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_current_user_has_role(
    p_role_code text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles p
        JOIN public.roles r
          ON r.id = p.role_id
         AND r.deleted_at IS NULL
         AND r.is_active = true
        WHERE p.user_id = auth.uid()
          AND p.deleted_at IS NULL
          AND p.is_active = true
          AND upper(r.code::text) = upper(trim(p_role_code))
    );
$$;

COMMENT ON FUNCTION public.fn_current_user_has_role(text)
IS 'Returns true when the authenticated active user has the specified role code.';

-- ============================================================
-- 7. MULTIPLE ROLE CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_current_user_has_any_role(
    p_role_codes text[]
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.profiles p
        JOIN public.roles r
          ON r.id = p.role_id
         AND r.deleted_at IS NULL
         AND r.is_active = true
        WHERE p.user_id = auth.uid()
          AND p.deleted_at IS NULL
          AND p.is_active = true
          AND upper(r.code::text) = ANY (
                SELECT upper(trim(role_code))
                FROM unnest(p_role_codes) AS role_code
          )
    );
$$;

COMMENT ON FUNCTION public.fn_current_user_has_any_role(text[])
IS 'Returns true when the authenticated active user has at least one role in the supplied role-code array.';

-- ============================================================
-- 8. TRIAL OFFICER CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_is_trial_officer()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT public.fn_current_user_has_role('TRIAL_OFFICER');
$$;

COMMENT ON FUNCTION public.fn_is_trial_officer()
IS 'Returns true when the authenticated user is an active Trial Officer.';

-- ============================================================
-- 9. MANAGER CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_is_manager()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT public.fn_current_user_has_role('MANAGER');
$$;

COMMENT ON FUNCTION public.fn_is_manager()
IS 'Returns true when the authenticated user is an active Manager.';

-- ============================================================
-- 10. GENERAL DIRECTOR CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_is_general_director()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT public.fn_current_user_has_role('GENERAL_DIRECTOR');
$$;

COMMENT ON FUNCTION public.fn_is_general_director()
IS 'Returns true when the authenticated user is an active General Director.';

-- ============================================================
-- 11. MANAGEMENT CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_is_management()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT public.fn_current_user_has_any_role(
        ARRAY[
            'MANAGER',
            'GENERAL_DIRECTOR'
        ]::text[]
    );
$$;

COMMENT ON FUNCTION public.fn_is_management()
IS 'Returns true when the authenticated user is a Manager or General Director.';

-- ============================================================
-- 12. MASTER DATA MANAGEMENT PERMISSION
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_can_manage_master_data()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT public.fn_current_user_has_any_role(
        ARRAY[
            'MANAGER',
            'GENERAL_DIRECTOR'
        ]::text[]
    );
$$;

COMMENT ON FUNCTION public.fn_can_manage_master_data()
IS 'Returns true when the authenticated user may create, update, or archive agricultural master data.';

-- ============================================================
-- 13. TRIAL REVIEW PERMISSION
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_can_review_trials()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT public.fn_current_user_has_any_role(
        ARRAY[
            'MANAGER',
            'GENERAL_DIRECTOR'
        ]::text[]
    );
$$;

COMMENT ON FUNCTION public.fn_can_review_trials()
IS 'Returns true when the authenticated user may approve, reject, or request corrections for trials.';

-- ============================================================
-- 14. USER MANAGEMENT PERMISSION
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_can_manage_users()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT public.fn_current_user_has_role(
        'GENERAL_DIRECTOR'
    );
$$;

COMMENT ON FUNCTION public.fn_can_manage_users()
IS 'Returns true when the authenticated user may manage application profiles and role assignments.';

-- ============================================================
-- 15. TRIAL CREATOR CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_is_trial_creator(
    p_trial_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.trials t
        WHERE t.id = p_trial_id
          AND t.deleted_at IS NULL
          AND t.created_by = auth.uid()
    );
$$;

COMMENT ON FUNCTION public.fn_is_trial_creator(uuid)
IS 'Returns true when the authenticated user created the specified non-deleted trial.';

-- ============================================================
-- 16. EVALUATION CREATOR CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_is_evaluation_creator(
    p_evaluation_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.evaluations e
        WHERE e.id = p_evaluation_id
          AND e.deleted_at IS NULL
          AND e.created_by = auth.uid()
    );
$$;

COMMENT ON FUNCTION public.fn_is_evaluation_creator(uuid)
IS 'Returns true when the authenticated user created the specified non-deleted evaluation.';

-- ============================================================
-- 17. TRIAL ACCESS CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_can_access_trial(
    p_trial_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT
        public.fn_current_user_is_active()
        AND EXISTS (
            SELECT 1
            FROM public.trials t
            WHERE t.id = p_trial_id
              AND t.deleted_at IS NULL
        );
$$;

COMMENT ON FUNCTION public.fn_can_access_trial(uuid)
IS 'Returns true when the authenticated active user may view the specified trial.';

-- ============================================================
-- 18. TRIAL MODIFICATION CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_can_modify_trial(
    p_trial_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT
        public.fn_current_user_is_active()
        AND (
            public.fn_is_management()
            OR (
                public.fn_is_trial_officer()
                AND public.fn_is_trial_creator(p_trial_id)
            )
        )
        AND EXISTS (
            SELECT 1
            FROM public.trials t
            WHERE t.id = p_trial_id
              AND t.deleted_at IS NULL
        );
$$;

COMMENT ON FUNCTION public.fn_can_modify_trial(uuid)
IS 'Returns true when management or the Trial Officer who created the trial may modify it.';

-- ============================================================
-- 19. EVALUATION ACCESS CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_can_access_evaluation(
    p_evaluation_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT
        public.fn_current_user_is_active()
        AND EXISTS (
            SELECT 1
            FROM public.evaluations e
            JOIN public.trials t
              ON t.id = e.trial_id
             AND t.deleted_at IS NULL
            WHERE e.id = p_evaluation_id
              AND e.deleted_at IS NULL
              AND e.is_active = true
        );
$$;

COMMENT ON FUNCTION public.fn_can_access_evaluation(uuid)
IS 'Returns true when the authenticated active user may view the specified evaluation.';

-- ============================================================
-- 20. EVALUATION MODIFICATION CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_can_modify_evaluation(
    p_evaluation_id uuid
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT
        public.fn_current_user_is_active()
        AND (
            public.fn_is_management()
            OR (
                public.fn_is_trial_officer()
                AND public.fn_is_evaluation_creator(
                    p_evaluation_id
                )
            )
        )
        AND EXISTS (
            SELECT 1
            FROM public.evaluations e
            WHERE e.id = p_evaluation_id
              AND e.deleted_at IS NULL
              AND e.is_active = true
        );
$$;

COMMENT ON FUNCTION public.fn_can_modify_evaluation(uuid)
IS 'Returns true when management or the Trial Officer who created the evaluation may modify it.';

-- ============================================================
-- 21. AUTHENTICATION ASSERTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_assert_authenticated()
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '42501',
                MESSAGE = 'Authentication is required.',
                DETAIL = 'No authenticated Supabase user was found.',
                HINT = 'Sign in before performing this operation.';
    END IF;
END;
$$;

COMMENT ON FUNCTION public.fn_assert_authenticated()
IS 'Raises an insufficient-privilege exception when no Supabase user is authenticated.';

-- ============================================================
-- 22. ACTIVE PROFILE ASSERTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_assert_active_profile()
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
    PERFORM public.fn_assert_authenticated();

    IF NOT public.fn_current_user_is_active() THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '42501',
                MESSAGE = 'An active AgriTrial Pro profile is required.',
                DETAIL = 'The authenticated account has no active application profile or active role.',
                HINT = 'Contact the General Director to activate the profile.';
    END IF;
END;
$$;

COMMENT ON FUNCTION public.fn_assert_active_profile()
IS 'Raises an insufficient-privilege exception when the authenticated account has no active profile.';

-- ============================================================
-- 23. ROLE ASSERTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_assert_role(
    p_allowed_role_codes text[]
)
RETURNS void
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
    PERFORM public.fn_assert_active_profile();

    IF p_allowed_role_codes IS NULL
       OR cardinality(p_allowed_role_codes) = 0 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '22023',
                MESSAGE = 'At least one allowed role code is required.';
    END IF;

    IF NOT public.fn_current_user_has_any_role(
        p_allowed_role_codes
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '42501',
                MESSAGE = 'You do not have permission to perform this operation.',
                DETAIL = format(
                    'Required role: %s. Current role: %s.',
                    array_to_string(
                        p_allowed_role_codes,
                        ', '
                    ),
                    COALESCE(
                        public.fn_current_user_role_code(),
                        'NONE'
                    )
                );
    END IF;
END;
$$;

COMMENT ON FUNCTION public.fn_assert_role(text[])
IS 'Raises an insufficient-privilege exception when the authenticated user does not have an allowed role.';

-- ============================================================
-- 24. FUNCTION OWNERSHIP SAFETY
-- ============================================================

REVOKE ALL
ON FUNCTION public.fn_current_user_id()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_current_profile_id()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_current_user_role_code()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_current_user_role_name()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_current_user_is_active()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_current_user_has_role(text)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_current_user_has_any_role(text[])
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_is_trial_officer()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_is_manager()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_is_general_director()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_is_management()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_can_manage_master_data()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_can_review_trials()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_can_manage_users()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_is_trial_creator(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_is_evaluation_creator(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_can_access_trial(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_can_modify_trial(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_can_access_evaluation(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_can_modify_evaluation(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_assert_authenticated()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_assert_active_profile()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_assert_role(text[])
FROM PUBLIC;

-- ============================================================
-- 25. AUTHENTICATED USER PERMISSIONS
-- ============================================================

GRANT EXECUTE
ON FUNCTION public.fn_current_user_id()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_current_profile_id()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_current_user_role_code()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_current_user_role_name()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_current_user_is_active()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_current_user_has_role(text)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_current_user_has_any_role(text[])
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_is_trial_officer()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_is_manager()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_is_general_director()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_is_management()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_can_manage_master_data()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_can_review_trials()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_can_manage_users()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_is_trial_creator(uuid)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_is_evaluation_creator(uuid)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_can_access_trial(uuid)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_can_modify_trial(uuid)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_can_access_evaluation(uuid)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_can_modify_evaluation(uuid)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_assert_authenticated()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_assert_active_profile()
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_assert_role(text[])
TO authenticated;

-- ============================================================
-- 26. SERVICE ROLE PERMISSIONS
-- ============================================================

GRANT EXECUTE
ON FUNCTION public.fn_current_user_id()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_current_profile_id()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_current_user_role_code()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_current_user_role_name()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_current_user_is_active()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_current_user_has_role(text)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_current_user_has_any_role(text[])
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_is_trial_officer()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_is_manager()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_is_general_director()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_is_management()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_can_manage_master_data()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_can_review_trials()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_can_manage_users()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_is_trial_creator(uuid)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_is_evaluation_creator(uuid)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_can_access_trial(uuid)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_can_modify_trial(uuid)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_can_access_evaluation(uuid)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_can_modify_evaluation(uuid)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_assert_authenticated()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_assert_active_profile()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_assert_role(text[])
TO service_role;

-- ============================================================
-- 27. MIGRATION VALIDATION
-- ============================================================

DO $$
DECLARE
    v_missing_functions text[];
BEGIN
    SELECT array_agg(required_function)
    INTO v_missing_functions
    FROM (
        VALUES
            ('fn_current_user_id'),
            ('fn_current_profile_id'),
            ('fn_current_user_role_code'),
            ('fn_current_user_role_name'),
            ('fn_current_user_is_active'),
            ('fn_current_user_has_role'),
            ('fn_current_user_has_any_role'),
            ('fn_is_trial_officer'),
            ('fn_is_manager'),
            ('fn_is_general_director'),
            ('fn_is_management'),
            ('fn_can_manage_master_data'),
            ('fn_can_review_trials'),
            ('fn_can_manage_users'),
            ('fn_is_trial_creator'),
            ('fn_is_evaluation_creator'),
            ('fn_can_access_trial'),
            ('fn_can_modify_trial'),
            ('fn_can_access_evaluation'),
            ('fn_can_modify_evaluation'),
            ('fn_assert_authenticated'),
            ('fn_assert_active_profile'),
            ('fn_assert_role')
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
            'Security helper migration validation failed. Missing functions: %',
            array_to_string(
                v_missing_functions,
                ', '
            );
    END IF;

    IF public.fn_current_user_id() IS DISTINCT FROM auth.uid() THEN
        RAISE EXCEPTION
            'fn_current_user_id() validation failed.';
    END IF;

    PERFORM public.fn_current_profile_id();
    PERFORM public.fn_current_user_role_code();
    PERFORM public.fn_current_user_role_name();
    PERFORM public.fn_current_user_is_active();
    PERFORM public.fn_current_user_has_role('TRIAL_OFFICER');

    PERFORM public.fn_current_user_has_any_role(
        ARRAY[
            'TRIAL_OFFICER',
            'MANAGER',
            'GENERAL_DIRECTOR'
        ]::text[]
    );

    PERFORM public.fn_is_trial_officer();
    PERFORM public.fn_is_manager();
    PERFORM public.fn_is_general_director();
    PERFORM public.fn_is_management();
    PERFORM public.fn_can_manage_master_data();
    PERFORM public.fn_can_review_trials();
    PERFORM public.fn_can_manage_users();

    RAISE NOTICE
        '0048_security_helper_functions.sql completed successfully.';
END;
$$;

COMMIT;
