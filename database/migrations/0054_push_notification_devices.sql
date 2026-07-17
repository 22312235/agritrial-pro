BEGIN;

SET search_path = public, auth, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

CREATE TABLE IF NOT EXISTS public.user_push_devices
(
    id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    user_id                 uuid NOT NULL
                            REFERENCES auth.users(id)
                            ON DELETE CASCADE,

    push_token              text NOT NULL,

    platform                varchar(20) NOT NULL,

    device_identifier       text NULL,

    device_name             varchar(150) NULL,

    device_model            varchar(150) NULL,

    operating_system        varchar(100) NULL,

    operating_system_version varchar(50) NULL,

    application_version     varchar(50) NULL,

    locale                  varchar(20) NULL,

    timezone                varchar(100) NULL,

    notifications_enabled   boolean NOT NULL DEFAULT true,

    is_active               boolean NOT NULL DEFAULT true,

    last_registered_at      timestamptz NOT NULL DEFAULT now(),

    last_seen_at            timestamptz NOT NULL DEFAULT now(),

    token_refreshed_at      timestamptz NOT NULL DEFAULT now(),

    deactivated_at          timestamptz NULL,

    deactivation_reason     text NULL,

    created_at              timestamptz NOT NULL DEFAULT now(),

    updated_at              timestamptz NOT NULL DEFAULT now(),

    created_by              uuid NULL
                            REFERENCES auth.users(id)
                            ON DELETE SET NULL,

    updated_by              uuid NULL
                            REFERENCES auth.users(id)
                            ON DELETE SET NULL,

    deleted_at              timestamptz NULL,

    CONSTRAINT user_push_devices_token_not_blank
        CHECK (
            btrim(push_token) <> ''
        ),

    CONSTRAINT user_push_devices_platform_check
        CHECK (
            platform IN (
                'ANDROID',
                'IOS',
                'WEB'
            )
        ),

    CONSTRAINT user_push_devices_device_identifier_not_blank
        CHECK (
            device_identifier IS NULL
            OR btrim(device_identifier) <> ''
        ),

    CONSTRAINT user_push_devices_device_name_not_blank
        CHECK (
            device_name IS NULL
            OR btrim(device_name) <> ''
        ),

    CONSTRAINT user_push_devices_deleted_state_check
        CHECK (
            deleted_at IS NULL
            OR is_active = false
        ),

    CONSTRAINT user_push_devices_deactivated_state_check
        CHECK (
            (
                is_active = true
                AND deactivated_at IS NULL
            )
            OR (
                is_active = false
            )
        )
);

COMMENT ON TABLE public.user_push_devices
IS 'Stores Firebase Cloud Messaging device registrations for authenticated AgriTrial Pro users.';

COMMENT ON COLUMN public.user_push_devices.push_token
IS 'Firebase Cloud Messaging registration token.';

COMMENT ON COLUMN public.user_push_devices.platform
IS 'Device platform: ANDROID, IOS, or WEB.';

COMMENT ON COLUMN public.user_push_devices.device_identifier
IS 'Optional application-generated stable device identifier.';

COMMENT ON COLUMN public.user_push_devices.notifications_enabled
IS 'Indicates whether the user enabled push notifications on this device.';

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_push_devices_token
ON public.user_push_devices(push_token)
WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_user_push_devices_user_identifier
ON public.user_push_devices
(
    user_id,
    device_identifier
)
WHERE device_identifier IS NOT NULL
  AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_push_devices_user
ON public.user_push_devices
(
    user_id,
    is_active
)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_push_devices_active_notifications
ON public.user_push_devices
(
    user_id,
    platform,
    last_seen_at DESC
)
WHERE is_active = true
  AND notifications_enabled = true
  AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_push_devices_last_seen
ON public.user_push_devices(last_seen_at DESC)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_user_push_devices_inactive
ON public.user_push_devices(deactivated_at)
WHERE is_active = false
  AND deleted_at IS NULL;

CREATE OR REPLACE FUNCTION public.fn_user_push_device_normalize()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth, extensions
AS $$
BEGIN
    NEW.push_token :=
        btrim(NEW.push_token);

    NEW.platform :=
        upper(
            btrim(NEW.platform)
        );

    NEW.device_identifier :=
        NULLIF(
            btrim(NEW.device_identifier),
            ''
        );

    NEW.device_name :=
        NULLIF(
            btrim(NEW.device_name),
            ''
        );

    NEW.device_model :=
        NULLIF(
            btrim(NEW.device_model),
            ''
        );

    NEW.operating_system :=
        NULLIF(
            btrim(NEW.operating_system),
            ''
        );

    NEW.operating_system_version :=
        NULLIF(
            btrim(NEW.operating_system_version),
            ''
        );

    NEW.application_version :=
        NULLIF(
            btrim(NEW.application_version),
            ''
        );

    NEW.locale :=
        NULLIF(
            btrim(NEW.locale),
            ''
        );

    NEW.timezone :=
        NULLIF(
            btrim(NEW.timezone),
            ''
        );

    NEW.deactivation_reason :=
        NULLIF(
            btrim(NEW.deactivation_reason),
            ''
        );

    IF TG_OP = 'INSERT' THEN
        NEW.created_by :=
            COALESCE(
                NEW.created_by,
                auth.uid(),
                NEW.user_id
            );

        NEW.updated_by :=
            COALESCE(
                NEW.updated_by,
                auth.uid(),
                NEW.user_id
            );
    ELSE
        NEW.updated_by :=
            COALESCE(
                auth.uid(),
                NEW.updated_by
            );
    END IF;

    NEW.updated_at := now();

    IF NEW.is_active = true THEN
        NEW.deleted_at := NULL;
        NEW.deactivated_at := NULL;
        NEW.deactivation_reason := NULL;
    ELSIF NEW.deactivated_at IS NULL THEN
        NEW.deactivated_at := now();
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_user_push_device_normalize
ON public.user_push_devices;

CREATE TRIGGER trg_user_push_device_normalize
BEFORE INSERT OR UPDATE
ON public.user_push_devices
FOR EACH ROW
EXECUTE FUNCTION public.fn_user_push_device_normalize();

CREATE OR REPLACE FUNCTION public.fn_register_push_device(
    p_push_token text,
    p_platform varchar,
    p_device_identifier text DEFAULT NULL,
    p_device_name varchar DEFAULT NULL,
    p_device_model varchar DEFAULT NULL,
    p_operating_system varchar DEFAULT NULL,
    p_operating_system_version varchar DEFAULT NULL,
    p_application_version varchar DEFAULT NULL,
    p_locale varchar DEFAULT NULL,
    p_timezone varchar DEFAULT NULL,
    p_notifications_enabled boolean DEFAULT true
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_user_id uuid;
    v_device_id uuid;
    v_platform varchar(20);
    v_push_token text;
    v_device_identifier text;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION
            'Authentication is required to register a push device.';
    END IF;

    v_push_token :=
        NULLIF(
            btrim(p_push_token),
            ''
        );

    IF v_push_token IS NULL THEN
        RAISE EXCEPTION
            'Push token is required.';
    END IF;

    v_platform :=
        upper(
            btrim(p_platform)
        );

    IF v_platform NOT IN (
        'ANDROID',
        'IOS',
        'WEB'
    ) THEN
        RAISE EXCEPTION
            'Unsupported device platform: %',
            p_platform;
    END IF;

    v_device_identifier :=
        NULLIF(
            btrim(p_device_identifier),
            ''
        );

    UPDATE public.user_push_devices
    SET
        is_active = false,
        notifications_enabled = false,
        deactivated_at = now(),
        deactivation_reason =
            'Push token reassigned to another user.',
        updated_at = now(),
        updated_by = v_user_id
    WHERE push_token = v_push_token
      AND user_id <> v_user_id
      AND deleted_at IS NULL
      AND is_active = true;

    IF v_device_identifier IS NOT NULL THEN
        SELECT d.id
        INTO v_device_id
        FROM public.user_push_devices d
        WHERE d.user_id = v_user_id
          AND d.device_identifier =
              v_device_identifier
          AND d.deleted_at IS NULL
        ORDER BY d.created_at DESC
        LIMIT 1
        FOR UPDATE;
    END IF;

    IF v_device_id IS NULL THEN
        SELECT d.id
        INTO v_device_id
        FROM public.user_push_devices d
        WHERE d.push_token = v_push_token
          AND d.deleted_at IS NULL
        ORDER BY d.created_at DESC
        LIMIT 1
        FOR UPDATE;
    END IF;

    IF v_device_id IS NULL THEN
        INSERT INTO public.user_push_devices
        (
            user_id,
            push_token,
            platform,
            device_identifier,
            device_name,
            device_model,
            operating_system,
            operating_system_version,
            application_version,
            locale,
            timezone,
            notifications_enabled,
            is_active,
            last_registered_at,
            last_seen_at,
            token_refreshed_at,
            created_by,
            updated_by
        )
        VALUES
        (
            v_user_id,
            v_push_token,
            v_platform,
            v_device_identifier,
            NULLIF(btrim(p_device_name), ''),
            NULLIF(btrim(p_device_model), ''),
            NULLIF(btrim(p_operating_system), ''),
            NULLIF(
                btrim(p_operating_system_version),
                ''
            ),
            NULLIF(
                btrim(p_application_version),
                ''
            ),
            NULLIF(btrim(p_locale), ''),
            NULLIF(btrim(p_timezone), ''),
            COALESCE(
                p_notifications_enabled,
                true
            ),
            true,
            now(),
            now(),
            now(),
            v_user_id,
            v_user_id
        )
        RETURNING id
        INTO v_device_id;
    ELSE
        UPDATE public.user_push_devices
        SET
            user_id = v_user_id,
            push_token = v_push_token,
            platform = v_platform,
            device_identifier =
                COALESCE(
                    v_device_identifier,
                    device_identifier
                ),
            device_name =
                COALESCE(
                    NULLIF(
                        btrim(p_device_name),
                        ''
                    ),
                    device_name
                ),
            device_model =
                COALESCE(
                    NULLIF(
                        btrim(p_device_model),
                        ''
                    ),
                    device_model
                ),
            operating_system =
                COALESCE(
                    NULLIF(
                        btrim(p_operating_system),
                        ''
                    ),
                    operating_system
                ),
            operating_system_version =
                COALESCE(
                    NULLIF(
                        btrim(
                            p_operating_system_version
                        ),
                        ''
                    ),
                    operating_system_version
                ),
            application_version =
                COALESCE(
                    NULLIF(
                        btrim(p_application_version),
                        ''
                    ),
                    application_version
                ),
            locale =
                COALESCE(
                    NULLIF(
                        btrim(p_locale),
                        ''
                    ),
                    locale
                ),
            timezone =
                COALESCE(
                    NULLIF(
                        btrim(p_timezone),
                        ''
                    ),
                    timezone
                ),
            notifications_enabled =
                COALESCE(
                    p_notifications_enabled,
                    true
                ),
            is_active = true,
            last_registered_at = now(),
            last_seen_at = now(),
            token_refreshed_at =
                CASE
                    WHEN push_token IS DISTINCT FROM
                         v_push_token
                    THEN now()
                    ELSE token_refreshed_at
                END,
            deactivated_at = NULL,
            deactivation_reason = NULL,
            deleted_at = NULL,
            updated_at = now(),
            updated_by = v_user_id
        WHERE id = v_device_id;
    END IF;

    RETURN v_device_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_update_push_device_token(
    p_device_id uuid,
    p_new_push_token text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_user_id uuid;
    v_new_push_token text;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION
            'Authentication is required.';
    END IF;

    v_new_push_token :=
        NULLIF(
            btrim(p_new_push_token),
            ''
        );

    IF v_new_push_token IS NULL THEN
        RAISE EXCEPTION
            'New push token is required.';
    END IF;

    UPDATE public.user_push_devices
    SET
        is_active = false,
        notifications_enabled = false,
        deactivated_at = now(),
        deactivation_reason =
            'Push token reassigned.',
        updated_at = now(),
        updated_by = v_user_id
    WHERE push_token = v_new_push_token
      AND id <> p_device_id
      AND deleted_at IS NULL;

    UPDATE public.user_push_devices
    SET
        push_token = v_new_push_token,
        token_refreshed_at = now(),
        last_registered_at = now(),
        last_seen_at = now(),
        is_active = true,
        deleted_at = NULL,
        deactivated_at = NULL,
        deactivation_reason = NULL,
        updated_at = now(),
        updated_by = v_user_id
    WHERE id = p_device_id
      AND user_id = v_user_id;

    RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_update_push_device_preferences(
    p_device_id uuid,
    p_notifications_enabled boolean
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION
            'Authentication is required.';
    END IF;

    UPDATE public.user_push_devices
    SET
        notifications_enabled =
            COALESCE(
                p_notifications_enabled,
                false
            ),
        last_seen_at = now(),
        updated_at = now(),
        updated_by = v_user_id
    WHERE id = p_device_id
      AND user_id = v_user_id
      AND deleted_at IS NULL;

    RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_touch_push_device(
    p_device_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION
            'Authentication is required.';
    END IF;

    UPDATE public.user_push_devices
    SET
        last_seen_at = now(),
        updated_at = now(),
        updated_by = v_user_id
    WHERE id = p_device_id
      AND user_id = v_user_id
      AND is_active = true
      AND deleted_at IS NULL;

    RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_unregister_push_device(
    p_device_id uuid,
    p_reason text DEFAULT 'User signed out.'
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_user_id uuid;
BEGIN
    v_user_id := auth.uid();

    IF v_user_id IS NULL THEN
        RAISE EXCEPTION
            'Authentication is required.';
    END IF;

    UPDATE public.user_push_devices
    SET
        is_active = false,
        notifications_enabled = false,
        deactivated_at = now(),
        deactivation_reason =
            COALESCE(
                NULLIF(
                    btrim(p_reason),
                    ''
                ),
                'User signed out.'
            ),
        updated_at = now(),
        updated_by = v_user_id
    WHERE id = p_device_id
      AND user_id = v_user_id
      AND deleted_at IS NULL;

    RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_deactivate_invalid_push_token(
    p_push_token text,
    p_reason text DEFAULT 'Push provider rejected the registration token.'
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_updated_count integer;
BEGIN
    IF p_push_token IS NULL
       OR btrim(p_push_token) = '' THEN
        RETURN 0;
    END IF;

    UPDATE public.user_push_devices
    SET
        is_active = false,
        notifications_enabled = false,
        deactivated_at = now(),
        deactivation_reason =
            COALESCE(
                NULLIF(
                    btrim(p_reason),
                    ''
                ),
                'Push provider rejected the registration token.'
            ),
        updated_at = now(),
        updated_by = auth.uid()
    WHERE push_token = btrim(p_push_token)
      AND deleted_at IS NULL
      AND is_active = true;

    GET DIAGNOSTICS
        v_updated_count = ROW_COUNT;

    RETURN v_updated_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_cleanup_inactive_push_devices(
    p_retention_days integer DEFAULT 90
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_deleted_count integer;
BEGIN
    IF p_retention_days IS NULL
       OR p_retention_days < 30 THEN
        RAISE EXCEPTION
            'Retention period must be at least 30 days.';
    END IF;

    DELETE FROM public.user_push_devices
    WHERE is_active = false
      AND deactivated_at IS NOT NULL
      AND deactivated_at <
          now() - make_interval(
              days => p_retention_days
          );

    GET DIAGNOSTICS
        v_deleted_count = ROW_COUNT;

    RETURN v_deleted_count;
END;
$$;

ALTER TABLE public.user_push_devices
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.user_push_devices
FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS user_push_devices_select_own
ON public.user_push_devices;

DROP POLICY IF EXISTS user_push_devices_insert_own
ON public.user_push_devices;

DROP POLICY IF EXISTS user_push_devices_update_own
ON public.user_push_devices;

DROP POLICY IF EXISTS user_push_devices_delete_own
ON public.user_push_devices;

DROP POLICY IF EXISTS user_push_devices_management_select
ON public.user_push_devices;

CREATE POLICY user_push_devices_select_own
ON public.user_push_devices
FOR SELECT
TO authenticated
USING (
    user_id = auth.uid()
);

CREATE POLICY user_push_devices_insert_own
ON public.user_push_devices
FOR INSERT
TO authenticated
WITH CHECK (
    user_id = auth.uid()
);

CREATE POLICY user_push_devices_update_own
ON public.user_push_devices
FOR UPDATE
TO authenticated
USING (
    user_id = auth.uid()
)
WITH CHECK (
    user_id = auth.uid()
);

CREATE POLICY user_push_devices_delete_own
ON public.user_push_devices
FOR DELETE
TO authenticated
USING (
    user_id = auth.uid()
);

CREATE POLICY user_push_devices_management_select
ON public.user_push_devices
FOR SELECT
TO authenticated
USING (
    public.fn_is_management()
);

REVOKE ALL
ON TABLE public.user_push_devices
FROM PUBLIC, anon, authenticated;

GRANT SELECT
ON TABLE public.user_push_devices
TO authenticated;

GRANT ALL
ON TABLE public.user_push_devices
TO service_role;

REVOKE ALL
ON FUNCTION public.fn_user_push_device_normalize()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_register_push_device(
    text,
    varchar,
    text,
    varchar,
    varchar,
    varchar,
    varchar,
    varchar,
    varchar,
    varchar,
    boolean
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_update_push_device_token(
    uuid,
    text
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_update_push_device_preferences(
    uuid,
    boolean
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_touch_push_device(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_unregister_push_device(
    uuid,
    text
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_deactivate_invalid_push_token(
    text,
    text
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_cleanup_inactive_push_devices(integer)
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.fn_register_push_device(
    text,
    varchar,
    text,
    varchar,
    varchar,
    varchar,
    varchar,
    varchar,
    varchar,
    varchar,
    boolean
)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_update_push_device_token(
    uuid,
    text
)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_update_push_device_preferences(
    uuid,
    boolean
)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_touch_push_device(uuid)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_unregister_push_device(
    uuid,
    text
)
TO authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_deactivate_invalid_push_token(
    text,
    text
)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_cleanup_inactive_push_devices(integer)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_user_push_device_normalize()
TO service_role;

INSERT INTO public.schema_versions
(
    version_number,
    migration_name
)
VALUES
(
    54,
    '0054_push_notification_devices.sql'
)
ON CONFLICT (version_number)
DO UPDATE SET
    migration_name = EXCLUDED.migration_name,
    applied_at = now();

DO $$
BEGIN
    IF to_regclass(
        'public.user_push_devices'
    ) IS NULL THEN
        RAISE EXCEPTION
            'user_push_devices table creation failed.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'user_push_devices'
          AND column_name = 'push_token'
    ) THEN
        RAISE EXCEPTION
            'user_push_devices.push_token column is missing.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'user_push_devices'
          AND column_name = 'notifications_enabled'
    ) THEN
        RAISE EXCEPTION
            'user_push_devices.notifications_enabled column is missing.';
    END IF;

    IF to_regprocedure(
        'public.fn_register_push_device(text,character varying,text,character varying,character varying,character varying,character varying,character varying,character varying,character varying,boolean)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_register_push_device function creation failed.';
    END IF;

    IF to_regprocedure(
        'public.fn_deactivate_invalid_push_token(text,text)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_deactivate_invalid_push_token function creation failed.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.schema_versions
        WHERE version_number = 54
    ) THEN
        RAISE EXCEPTION
            'Schema version 54 registration failed.';
    END IF;

    RAISE NOTICE
        '0054_push_notification_devices.sql completed successfully.';
END;
$$;

COMMIT;
