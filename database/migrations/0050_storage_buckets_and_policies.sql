```sql
-- ============================================================
-- AgriTrial Pro
-- Migration: 0050_storage_buckets_and_policies.sql
-- Purpose: Supabase Storage buckets, validation helpers,
--          permissions, and Row Level Security policies
-- ============================================================

BEGIN;

SET search_path = public, auth, storage, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

-- ============================================================
-- 1. STORAGE PATH UUID HELPER
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_storage_path_uuid(
    p_object_name text,
    p_segment_position integer DEFAULT 1
)
RETURNS uuid
LANGUAGE plpgsql
IMMUTABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
DECLARE
    v_segment text;
BEGIN
    IF p_object_name IS NULL
       OR btrim(p_object_name) = ''
       OR p_segment_position IS NULL
       OR p_segment_position < 1 THEN
        RETURN NULL;
    END IF;

    v_segment := split_part(
        p_object_name,
        '/',
        p_segment_position
    );

    IF v_segment IS NULL
       OR btrim(v_segment) = '' THEN
        RETURN NULL;
    END IF;

    BEGIN
        RETURN btrim(v_segment)::uuid;
    EXCEPTION
        WHEN invalid_text_representation THEN
            RETURN NULL;
    END;
END;
$$;

COMMENT ON FUNCTION public.fn_storage_path_uuid(
    text,
    integer
) IS
'Extracts a UUID from a specified segment of a slash-separated Supabase Storage object path. Returns NULL when the segment is missing or invalid.';

-- ============================================================
-- 2. STORAGE FILE EXTENSION HELPER
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_storage_file_extension(
    p_object_name text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
    SELECT CASE
        WHEN p_object_name IS NULL
             OR btrim(p_object_name) = ''
             OR split_part(
                    regexp_replace(
                        p_object_name,
                        '^.*/',
                        ''
                    ),
                    '.',
                    2
                ) = ''
        THEN NULL
        ELSE lower(
            substring(
                regexp_replace(
                    p_object_name,
                    '^.*/',
                    ''
                )
                FROM '\.([^.]+)$'
            )
        )
    END;
$$;

COMMENT ON FUNCTION public.fn_storage_file_extension(text)
IS 'Returns the lowercase file extension from a Supabase Storage object path.';

-- ============================================================
-- 3. ALLOWED IMAGE EXTENSION CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_storage_is_allowed_image(
    p_object_name text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
    SELECT COALESCE(
        public.fn_storage_file_extension(
            p_object_name
        ) = ANY (
            ARRAY[
                'jpg',
                'jpeg',
                'png',
                'webp',
                'heic'
            ]::text[]
        ),
        false
    );
$$;

COMMENT ON FUNCTION public.fn_storage_is_allowed_image(text)
IS 'Returns true when the supplied Storage object path has an approved image extension.';

-- ============================================================
-- 4. ALLOWED GENERATED REPORT EXTENSION CHECK
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_storage_is_allowed_report(
    p_object_name text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SECURITY INVOKER
SET search_path = public, extensions
AS $$
    SELECT COALESCE(
        public.fn_storage_file_extension(
            p_object_name
        ) = ANY (
            ARRAY[
                'pdf',
                'csv',
                'xlsx'
            ]::text[]
        ),
        false
    );
$$;

COMMENT ON FUNCTION public.fn_storage_is_allowed_report(text)
IS 'Returns true when the supplied Storage object path has an approved report extension.';

-- ============================================================
-- 5. TRIAL STORAGE ACCESS HELPERS
-- Path format:
-- {trial_id}/{filename}
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_storage_can_access_trial(
    p_object_name text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT COALESCE(
        public.fn_can_access_trial(
            public.fn_storage_path_uuid(
                p_object_name,
                1
            )
        ),
        false
    );
$$;

CREATE OR REPLACE FUNCTION public.fn_storage_can_modify_trial(
    p_object_name text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT COALESCE(
        public.fn_can_modify_trial(
            public.fn_storage_path_uuid(
                p_object_name,
                1
            )
        ),
        false
    );
$$;

COMMENT ON FUNCTION public.fn_storage_can_access_trial(text)
IS 'Checks whether the authenticated user may access the trial identified by the first Storage path segment.';

COMMENT ON FUNCTION public.fn_storage_can_modify_trial(text)
IS 'Checks whether the authenticated user may modify the trial identified by the first Storage path segment.';

-- ============================================================
-- 6. EVALUATION STORAGE ACCESS HELPERS
-- Path format:
-- {evaluation_id}/{filename}
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_storage_can_access_evaluation(
    p_object_name text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT COALESCE(
        public.fn_can_access_evaluation(
            public.fn_storage_path_uuid(
                p_object_name,
                1
            )
        ),
        false
    );
$$;

CREATE OR REPLACE FUNCTION public.fn_storage_can_modify_evaluation(
    p_object_name text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT COALESCE(
        public.fn_can_modify_evaluation(
            public.fn_storage_path_uuid(
                p_object_name,
                1
            )
        ),
        false
    );
$$;

COMMENT ON FUNCTION public.fn_storage_can_access_evaluation(text)
IS 'Checks whether the authenticated user may access the evaluation identified by the first Storage path segment.';

COMMENT ON FUNCTION public.fn_storage_can_modify_evaluation(text)
IS 'Checks whether the authenticated user may modify the evaluation identified by the first Storage path segment.';

-- ============================================================
-- 7. PROFILE AVATAR STORAGE ACCESS HELPERS
-- Path format:
-- {user_id}/{filename}
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_storage_can_access_avatar(
    p_object_name text
)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT
        public.fn_current_user_is_active()
        AND public.fn_storage_path_uuid(
            p_object_name,
            1
        ) IS NOT NULL;
$$;

CREATE OR REPLACE FUNCTION public.fn_storage_can_modify_avatar(
    p_object_name text
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
            public.fn_storage_path_uuid(
                p_object_name,
                1
            ) = auth.uid()
            OR public.fn_can_manage_users()
        );
$$;

COMMENT ON FUNCTION public.fn_storage_can_access_avatar(text)
IS 'Allows active authenticated users to view valid profile avatar object paths.';

COMMENT ON FUNCTION public.fn_storage_can_modify_avatar(text)
IS 'Allows users to manage files in their own avatar folder and General Directors to manage all avatar folders.';

-- ============================================================
-- 8. GENERATED REPORT STORAGE ACCESS HELPERS
-- Path format:
-- {user_id}/{filename}
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_storage_can_access_report(
    p_object_name text
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
            public.fn_storage_path_uuid(
                p_object_name,
                1
            ) = auth.uid()
            OR public.fn_is_management()
        );
$$;

CREATE OR REPLACE FUNCTION public.fn_storage_can_modify_report(
    p_object_name text
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
            public.fn_storage_path_uuid(
                p_object_name,
                1
            ) = auth.uid()
            OR public.fn_is_management()
        );
$$;

COMMENT ON FUNCTION public.fn_storage_can_access_report(text)
IS 'Allows users to access generated reports in their own folder and management to access all generated reports.';

COMMENT ON FUNCTION public.fn_storage_can_modify_report(text)
IS 'Allows users to manage generated reports in their own folder and management to manage all generated reports.';

-- ============================================================
-- 9. FUNCTION SECURITY
-- ============================================================

REVOKE ALL
ON FUNCTION public.fn_storage_path_uuid(
    text,
    integer
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_storage_file_extension(text)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_storage_is_allowed_image(text)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_storage_is_allowed_report(text)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_storage_can_access_trial(text)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_storage_can_modify_trial(text)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_storage_can_access_evaluation(text)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_storage_can_modify_evaluation(text)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_storage_can_access_avatar(text)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_storage_can_modify_avatar(text)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_storage_can_access_report(text)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_storage_can_modify_report(text)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.fn_storage_path_uuid(
    text,
    integer
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_storage_file_extension(text)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_storage_is_allowed_image(text)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_storage_is_allowed_report(text)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_storage_can_access_trial(text)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_storage_can_modify_trial(text)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_storage_can_access_evaluation(text)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_storage_can_modify_evaluation(text)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_storage_can_access_avatar(text)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_storage_can_modify_avatar(text)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_storage_can_access_report(text)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_storage_can_modify_report(text)
TO authenticated, service_role;

-- ============================================================
-- 10. CREATE OR UPDATE STORAGE BUCKETS
-- ============================================================

INSERT INTO storage.buckets (
    id,
    name,
    public,
    file_size_limit,
    allowed_mime_types
)
VALUES
    (
        'trial-photos',
        'trial-photos',
        false,
        20971520,
        ARRAY[
            'image/jpeg',
            'image/png',
            'image/webp',
            'image/heic'
        ]::text[]
    ),
    (
        'evaluation-photos',
        'evaluation-photos',
        false,
        20971520,
        ARRAY[
            'image/jpeg',
            'image/png',
            'image/webp',
            'image/heic'
        ]::text[]
    ),
    (
        'profile-avatars',
        'profile-avatars',
        false,
        5242880,
        ARRAY[
            'image/jpeg',
            'image/png',
            'image/webp'
        ]::text[]
    ),
    (
        'generated-reports',
        'generated-reports',
        false,
        52428800,
        ARRAY[
            'application/pdf',
            'text/csv',
            'application/csv',
            'application/vnd.ms-excel',
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        ]::text[]
    )
ON CONFLICT (id)
DO UPDATE SET
    name = EXCLUDED.name,
    public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

-- ============================================================
-- 11. DROP EXISTING STORAGE POLICIES
-- Policies are dropped before recreation.
-- Functions are not dropped because policies depend on them.
-- ============================================================

DROP POLICY IF EXISTS agritrial_buckets_select_authenticated
ON storage.buckets;

DROP POLICY IF EXISTS trial_photos_storage_select
ON storage.objects;

DROP POLICY IF EXISTS trial_photos_storage_insert
ON storage.objects;

DROP POLICY IF EXISTS trial_photos_storage_update
ON storage.objects;

DROP POLICY IF EXISTS trial_photos_storage_delete
ON storage.objects;

DROP POLICY IF EXISTS evaluation_photos_storage_select
ON storage.objects;

DROP POLICY IF EXISTS evaluation_photos_storage_insert
ON storage.objects;

DROP POLICY IF EXISTS evaluation_photos_storage_update
ON storage.objects;

DROP POLICY IF EXISTS evaluation_photos_storage_delete
ON storage.objects;

DROP POLICY IF EXISTS profile_avatars_storage_select
ON storage.objects;

DROP POLICY IF EXISTS profile_avatars_storage_insert
ON storage.objects;

DROP POLICY IF EXISTS profile_avatars_storage_update
ON storage.objects;

DROP POLICY IF EXISTS profile_avatars_storage_delete
ON storage.objects;

DROP POLICY IF EXISTS generated_reports_storage_select
ON storage.objects;

DROP POLICY IF EXISTS generated_reports_storage_insert
ON storage.objects;

DROP POLICY IF EXISTS generated_reports_storage_update
ON storage.objects;

DROP POLICY IF EXISTS generated_reports_storage_delete
ON storage.objects;

-- ============================================================
-- 12. STORAGE BUCKET SELECT POLICY
-- ============================================================

CREATE POLICY agritrial_buckets_select_authenticated
ON storage.buckets
FOR SELECT
TO authenticated
USING (
    public.fn_current_user_is_active()
    AND id = ANY (
        ARRAY[
            'trial-photos',
            'evaluation-photos',
            'profile-avatars',
            'generated-reports'
        ]::text[]
    )
);

-- ============================================================
-- 13. TRIAL PHOTOS STORAGE POLICIES
-- Bucket:
-- trial-photos
--
-- Required path:
-- {trial_id}/{filename}
-- ============================================================

CREATE POLICY trial_photos_storage_select
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'trial-photos'
    AND public.fn_storage_can_access_trial(name)
);

CREATE POLICY trial_photos_storage_insert
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'trial-photos'
    AND public.fn_storage_path_uuid(
        name,
        1
    ) IS NOT NULL
    AND public.fn_storage_is_allowed_image(name)
    AND public.fn_storage_can_modify_trial(name)
);

CREATE POLICY trial_photos_storage_update
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'trial-photos'
    AND public.fn_storage_can_modify_trial(name)
)
WITH CHECK (
    bucket_id = 'trial-photos'
    AND public.fn_storage_path_uuid(
        name,
        1
    ) IS NOT NULL
    AND public.fn_storage_is_allowed_image(name)
    AND public.fn_storage_can_modify_trial(name)
);

CREATE POLICY trial_photos_storage_delete
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'trial-photos'
    AND public.fn_storage_can_modify_trial(name)
);

-- ============================================================
-- 14. EVALUATION PHOTOS STORAGE POLICIES
-- Bucket:
-- evaluation-photos
--
-- Required path:
-- {evaluation_id}/{filename}
-- ============================================================

CREATE POLICY evaluation_photos_storage_select
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'evaluation-photos'
    AND public.fn_storage_can_access_evaluation(name)
);

CREATE POLICY evaluation_photos_storage_insert
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'evaluation-photos'
    AND public.fn_storage_path_uuid(
        name,
        1
    ) IS NOT NULL
    AND public.fn_storage_is_allowed_image(name)
    AND public.fn_storage_can_modify_evaluation(name)
);

CREATE POLICY evaluation_photos_storage_update
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'evaluation-photos'
    AND public.fn_storage_can_modify_evaluation(name)
)
WITH CHECK (
    bucket_id = 'evaluation-photos'
    AND public.fn_storage_path_uuid(
        name,
        1
    ) IS NOT NULL
    AND public.fn_storage_is_allowed_image(name)
    AND public.fn_storage_can_modify_evaluation(name)
);

CREATE POLICY evaluation_photos_storage_delete
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'evaluation-photos'
    AND public.fn_storage_can_modify_evaluation(name)
);

-- ============================================================
-- 15. PROFILE AVATAR STORAGE POLICIES
-- Bucket:
-- profile-avatars
--
-- Required path:
-- {user_id}/{filename}
-- ============================================================

CREATE POLICY profile_avatars_storage_select
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'profile-avatars'
    AND public.fn_storage_can_access_avatar(name)
);

CREATE POLICY profile_avatars_storage_insert
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'profile-avatars'
    AND public.fn_storage_path_uuid(
        name,
        1
    ) IS NOT NULL
    AND public.fn_storage_is_allowed_image(name)
    AND public.fn_storage_can_modify_avatar(name)
);

CREATE POLICY profile_avatars_storage_update
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'profile-avatars'
    AND public.fn_storage_can_modify_avatar(name)
)
WITH CHECK (
    bucket_id = 'profile-avatars'
    AND public.fn_storage_path_uuid(
        name,
        1
    ) IS NOT NULL
    AND public.fn_storage_is_allowed_image(name)
    AND public.fn_storage_can_modify_avatar(name)
);

CREATE POLICY profile_avatars_storage_delete
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'profile-avatars'
    AND public.fn_storage_can_modify_avatar(name)
);

-- ============================================================
-- 16. GENERATED REPORT STORAGE POLICIES
-- Bucket:
-- generated-reports
--
-- Required path:
-- {user_id}/{filename}
-- ============================================================

CREATE POLICY generated_reports_storage_select
ON storage.objects
FOR SELECT
TO authenticated
USING (
    bucket_id = 'generated-reports'
    AND public.fn_storage_can_access_report(name)
);

CREATE POLICY generated_reports_storage_insert
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
    bucket_id = 'generated-reports'
    AND public.fn_storage_path_uuid(
        name,
        1
    ) IS NOT NULL
    AND public.fn_storage_is_allowed_report(name)
    AND public.fn_storage_can_modify_report(name)
);

CREATE POLICY generated_reports_storage_update
ON storage.objects
FOR UPDATE
TO authenticated
USING (
    bucket_id = 'generated-reports'
    AND public.fn_storage_can_modify_report(name)
)
WITH CHECK (
    bucket_id = 'generated-reports'
    AND public.fn_storage_path_uuid(
        name,
        1
    ) IS NOT NULL
    AND public.fn_storage_is_allowed_report(name)
    AND public.fn_storage_can_modify_report(name)
);

CREATE POLICY generated_reports_storage_delete
ON storage.objects
FOR DELETE
TO authenticated
USING (
    bucket_id = 'generated-reports'
    AND public.fn_storage_can_modify_report(name)
);

-- ============================================================
-- 17. STORAGE VALIDATION
-- ============================================================

DO $$
DECLARE
    v_missing_buckets text[];
    v_missing_object_policies text[];
    v_missing_bucket_policies text[];
BEGIN
    SELECT array_agg(required_bucket)
    INTO v_missing_buckets
    FROM (
        VALUES
            ('trial-photos'),
            ('evaluation-photos'),
            ('profile-avatars'),
            ('generated-reports')
    ) AS required(required_bucket)
    WHERE NOT EXISTS (
        SELECT 1
        FROM storage.buckets b
        WHERE b.id = required.required_bucket
    );

    IF v_missing_buckets IS NOT NULL THEN
        RAISE EXCEPTION
            'Storage bucket validation failed. Missing buckets: %',
            array_to_string(
                v_missing_buckets,
                ', '
            );
    END IF;

    SELECT array_agg(required_policy)
    INTO v_missing_object_policies
    FROM (
        VALUES
            ('trial_photos_storage_select'),
            ('trial_photos_storage_insert'),
            ('trial_photos_storage_update'),
            ('trial_photos_storage_delete'),
            ('evaluation_photos_storage_select'),
            ('evaluation_photos_storage_insert'),
            ('evaluation_photos_storage_update'),
            ('evaluation_photos_storage_delete'),
            ('profile_avatars_storage_select'),
            ('profile_avatars_storage_insert'),
            ('profile_avatars_storage_update'),
            ('profile_avatars_storage_delete'),
            ('generated_reports_storage_select'),
            ('generated_reports_storage_insert'),
            ('generated_reports_storage_update'),
            ('generated_reports_storage_delete')
    ) AS required(required_policy)
    WHERE NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_policies p
        WHERE p.schemaname = 'storage'
          AND p.tablename = 'objects'
          AND p.policyname = required.required_policy
    );

    IF v_missing_object_policies IS NOT NULL THEN
        RAISE EXCEPTION
            'Storage object policy validation failed. Missing policies: %',
            array_to_string(
                v_missing_object_policies,
                ', '
            );
    END IF;

    SELECT array_agg(required_policy)
    INTO v_missing_bucket_policies
    FROM (
        VALUES
            ('agritrial_buckets_select_authenticated')
    ) AS required(required_policy)
    WHERE NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_policies p
        WHERE p.schemaname = 'storage'
          AND p.tablename = 'buckets'
          AND p.policyname = required.required_policy
    );

    IF v_missing_bucket_policies IS NOT NULL THEN
        RAISE EXCEPTION
            'Storage bucket policy validation failed. Missing policies: %',
            array_to_string(
                v_missing_bucket_policies,
                ', '
            );
    END IF;

    IF public.fn_storage_path_uuid(
        '00000000-0000-0000-0000-000000000000/file.jpg',
        1
    ) IS DISTINCT FROM
       '00000000-0000-0000-0000-000000000000'::uuid THEN
        RAISE EXCEPTION
            'Storage UUID path helper validation failed.';
    END IF;

    IF public.fn_storage_path_uuid(
        'invalid-uuid/file.jpg',
        1
    ) IS NOT NULL THEN
        RAISE EXCEPTION
            'Invalid Storage UUID path validation failed.';
    END IF;

    IF public.fn_storage_file_extension(
        '00000000-0000-0000-0000-000000000000/photo.JPG'
    ) IS DISTINCT FROM 'jpg' THEN
        RAISE EXCEPTION
            'Storage file extension helper validation failed.';
    END IF;

    IF NOT public.fn_storage_is_allowed_image(
        '00000000-0000-0000-0000-000000000000/photo.jpg'
    ) THEN
        RAISE EXCEPTION
            'Storage image extension validation failed.';
    END IF;

    IF public.fn_storage_is_allowed_image(
        '00000000-0000-0000-0000-000000000000/malicious.exe'
    ) THEN
        RAISE EXCEPTION
            'Storage disallowed image extension validation failed.';
    END IF;

    IF NOT public.fn_storage_is_allowed_report(
        '00000000-0000-0000-0000-000000000000/report.pdf'
    ) THEN
        RAISE EXCEPTION
            'Storage report extension validation failed.';
    END IF;

    IF public.fn_storage_is_allowed_report(
        '00000000-0000-0000-0000-000000000000/report.exe'
    ) THEN
        RAISE EXCEPTION
            'Storage disallowed report extension validation failed.';
    END IF;

    RAISE NOTICE
        '0050_storage_buckets_and_policies.sql completed successfully.';
END;
$$;

COMMIT;
```
