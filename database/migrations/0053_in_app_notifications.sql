-- ============================================================
-- AgriTrial Pro
-- Migration: 0053_in_app_notifications.sql
-- Purpose: Create secure in-app notifications for Trial
--          Officers, Managers, and General Directors
-- ============================================================

BEGIN;

SET search_path = public, auth, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

-- ============================================================
-- 1. NOTIFICATIONS TABLE
-- ============================================================

CREATE TABLE IF NOT EXISTS public.notifications
(
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    recipient_user_id   uuid NOT NULL
                        REFERENCES auth.users(id)
                        ON DELETE CASCADE,

    sender_user_id      uuid NULL
                        REFERENCES auth.users(id)
                        ON DELETE SET NULL,

    notification_type   varchar(50) NOT NULL,

    title               varchar(200) NOT NULL,

    message             text NOT NULL,

    entity_type         varchar(50) NULL,

    entity_id           uuid NULL,

    action_url          text NULL,

    metadata            jsonb NOT NULL DEFAULT '{}'::jsonb,

    priority            varchar(20) NOT NULL DEFAULT 'NORMAL',

    is_read             boolean NOT NULL DEFAULT false,

    read_at             timestamptz NULL,

    is_active           boolean NOT NULL DEFAULT true,

    created_at          timestamptz NOT NULL DEFAULT now(),

    updated_at          timestamptz NOT NULL DEFAULT now(),

    created_by          uuid NULL
                        REFERENCES auth.users(id)
                        ON DELETE SET NULL,

    updated_by          uuid NULL
                        REFERENCES auth.users(id)
                        ON DELETE SET NULL,

    deleted_at          timestamptz NULL,

    CONSTRAINT notifications_type_not_blank
        CHECK (
            btrim(notification_type) <> ''
        ),

    CONSTRAINT notifications_title_not_blank
        CHECK (
            btrim(title) <> ''
        ),

    CONSTRAINT notifications_message_not_blank
        CHECK (
            btrim(message) <> ''
        ),

    CONSTRAINT notifications_priority_check
        CHECK (
            priority IN (
                'LOW',
                'NORMAL',
                'HIGH',
                'URGENT'
            )
        ),

    CONSTRAINT notifications_entity_fields_check
        CHECK (
            (
                entity_type IS NULL
                AND entity_id IS NULL
            )
            OR (
                entity_type IS NOT NULL
                AND entity_id IS NOT NULL
            )
        ),

    CONSTRAINT notifications_read_state_check
        CHECK (
            (
                is_read = false
                AND read_at IS NULL
            )
            OR (
                is_read = true
                AND read_at IS NOT NULL
            )
        ),

    CONSTRAINT notifications_metadata_object_check
        CHECK (
            jsonb_typeof(metadata) = 'object'
        )
);

COMMENT ON TABLE public.notifications
IS 'Stores private in-app notifications for AgriTrial Pro users.';

COMMENT ON COLUMN public.notifications.notification_type
IS 'Notification category such as TRIAL_SUBMITTED, TRIAL_APPROVED, TRIAL_REJECTED, CORRECTIONS_REQUESTED, EVALUATION_CREATED, or REPORT_READY.';

COMMENT ON COLUMN public.notifications.entity_type
IS 'Related application entity type such as TRIAL, EVALUATION, or REPORT.';

COMMENT ON COLUMN public.notifications.entity_id
IS 'UUID of the entity associated with the notification.';

COMMENT ON COLUMN public.notifications.metadata
IS 'Additional structured notification data stored as a JSON object.';

-- ============================================================
-- 2. INDEXES
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_created
ON public.notifications
(
    recipient_user_id,
    created_at DESC
)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_recipient_unread
ON public.notifications
(
    recipient_user_id,
    created_at DESC
)
WHERE is_read = false
  AND is_active = true
  AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_entity
ON public.notifications
(
    entity_type,
    entity_id
)
WHERE entity_id IS NOT NULL
  AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_type
ON public.notifications
(
    notification_type
)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_priority
ON public.notifications
(
    priority,
    created_at DESC
)
WHERE is_active = true
  AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_metadata
ON public.notifications
USING gin(metadata);

-- ============================================================
-- 3. UPDATED-AT TRIGGER FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_notifications_set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, extensions
AS $$
BEGIN
    NEW.updated_at := now();

    IF auth.uid() IS NOT NULL THEN
        NEW.updated_by := auth.uid();
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_notifications_set_updated_at()
IS 'Maintains updated_at and updated_by values for notifications.';

DROP TRIGGER IF EXISTS trg_notifications_set_updated_at
ON public.notifications;

CREATE TRIGGER trg_notifications_set_updated_at
BEFORE UPDATE
ON public.notifications
FOR EACH ROW
EXECUTE FUNCTION public.fn_notifications_set_updated_at();

-- ============================================================
-- 4. READ-STATE TRIGGER FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_notifications_sync_read_state()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, extensions
AS $$
BEGIN
    IF NEW.is_read = true
       AND (
            OLD.is_read = false
            OR NEW.read_at IS NULL
       ) THEN
        NEW.read_at := now();
    END IF;

    IF NEW.is_read = false THEN
        NEW.read_at := NULL;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_notifications_sync_read_state()
IS 'Synchronizes notification is_read and read_at values.';

DROP TRIGGER IF EXISTS trg_notifications_sync_read_state
ON public.notifications;

CREATE TRIGGER trg_notifications_sync_read_state
BEFORE UPDATE OF is_read
ON public.notifications
FOR EACH ROW
EXECUTE FUNCTION public.fn_notifications_sync_read_state();

-- ============================================================
-- 5. CREATE NOTIFICATION FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_create_notification(
    p_recipient_user_id uuid,
    p_notification_type text,
    p_title text,
    p_message text,
    p_entity_type text DEFAULT NULL,
    p_entity_id uuid DEFAULT NULL,
    p_action_url text DEFAULT NULL,
    p_metadata jsonb DEFAULT '{}'::jsonb,
    p_priority text DEFAULT 'NORMAL',
    p_sender_user_id uuid DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_notification_id uuid;
    v_sender_user_id uuid;
BEGIN
    IF p_recipient_user_id IS NULL THEN
        RAISE EXCEPTION
            'Recipient user ID is required.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.profiles p
        WHERE p.user_id = p_recipient_user_id
          AND p.is_active = true
          AND p.deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'The notification recipient does not have an active profile.';
    END IF;

    IF p_notification_type IS NULL
       OR btrim(p_notification_type) = '' THEN
        RAISE EXCEPTION
            'Notification type is required.';
    END IF;

    IF p_title IS NULL
       OR btrim(p_title) = '' THEN
        RAISE EXCEPTION
            'Notification title is required.';
    END IF;

    IF p_message IS NULL
       OR btrim(p_message) = '' THEN
        RAISE EXCEPTION
            'Notification message is required.';
    END IF;

    IF (
        p_entity_type IS NULL
        AND p_entity_id IS NOT NULL
    )
    OR (
        p_entity_type IS NOT NULL
        AND p_entity_id IS NULL
    ) THEN
        RAISE EXCEPTION
            'Entity type and entity ID must either both be supplied or both be NULL.';
    END IF;

    IF upper(
        COALESCE(
            p_priority,
            'NORMAL'
        )
    ) NOT IN (
        'LOW',
        'NORMAL',
        'HIGH',
        'URGENT'
    ) THEN
        RAISE EXCEPTION
            'Invalid notification priority: %',
            p_priority;
    END IF;

    IF p_metadata IS NULL
       OR jsonb_typeof(p_metadata) <> 'object' THEN
        RAISE EXCEPTION
            'Notification metadata must be a JSON object.';
    END IF;

    v_sender_user_id := COALESCE(
        p_sender_user_id,
        auth.uid()
    );

    INSERT INTO public.notifications
    (
        recipient_user_id,
        sender_user_id,
        notification_type,
        title,
        message,
        entity_type,
        entity_id,
        action_url,
        metadata,
        priority,
        created_by,
        updated_by
    )
    VALUES
    (
        p_recipient_user_id,
        v_sender_user_id,
        upper(
            btrim(
                p_notification_type
            )
        ),
        btrim(p_title),
        btrim(p_message),
        CASE
            WHEN p_entity_type IS NULL THEN NULL
            ELSE upper(
                btrim(
                    p_entity_type
                )
            )
        END,
        p_entity_id,
        NULLIF(
            btrim(
                p_action_url
            ),
            ''
        ),
        p_metadata,
        upper(
            COALESCE(
                btrim(p_priority),
                'NORMAL'
            )
        ),
        v_sender_user_id,
        v_sender_user_id
    )
    RETURNING id
    INTO v_notification_id;

    RETURN v_notification_id;
END;
$$;

COMMENT ON FUNCTION public.fn_create_notification(
    uuid,
    text,
    text,
    text,
    text,
    uuid,
    text,
    jsonb,
    text,
    uuid
)
IS 'Creates a validated private in-app notification for an active user.';

-- ============================================================
-- 6. NOTIFY MANAGEMENT FUNCTION
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_notify_management(
    p_notification_type text,
    p_title text,
    p_message text,
    p_entity_type text DEFAULT NULL,
    p_entity_id uuid DEFAULT NULL,
    p_action_url text DEFAULT NULL,
    p_metadata jsonb DEFAULT '{}'::jsonb,
    p_priority text DEFAULT 'NORMAL'
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_profile record;
    v_notification_count integer := 0;
BEGIN
    FOR v_profile IN
        SELECT p.user_id
        FROM public.profiles p
        JOIN public.roles r
          ON r.id = p.role_id
        WHERE p.is_active = true
          AND p.deleted_at IS NULL
          AND r.is_active = true
          AND r.deleted_at IS NULL
          AND r.code::text IN (
              'MANAGER',
              'GENERAL_DIRECTOR'
          )
    LOOP
        PERFORM public.fn_create_notification(
            p_recipient_user_id => v_profile.user_id,
            p_notification_type => p_notification_type,
            p_title => p_title,
            p_message => p_message,
            p_entity_type => p_entity_type,
            p_entity_id => p_entity_id,
            p_action_url => p_action_url,
            p_metadata => p_metadata,
            p_priority => p_priority,
            p_sender_user_id => auth.uid()
        );

        v_notification_count :=
            v_notification_count + 1;
    END LOOP;

    RETURN v_notification_count;
END;
$$;

COMMENT ON FUNCTION public.fn_notify_management(
    text,
    text,
    text,
    text,
    uuid,
    text,
    jsonb,
    text
)
IS 'Creates the same notification for all active Managers and General Directors.';

-- ============================================================
-- 7. MARK ONE NOTIFICATION AS READ
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_mark_notification_read(
    p_notification_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION
            'Authentication is required.';
    END IF;

    UPDATE public.notifications
    SET
        is_read = true,
        read_at = COALESCE(
            read_at,
            now()
        ),
        updated_at = now(),
        updated_by = auth.uid()
    WHERE id = p_notification_id
      AND recipient_user_id = auth.uid()
      AND deleted_at IS NULL;

    RETURN FOUND;
END;
$$;

COMMENT ON FUNCTION public.fn_mark_notification_read(uuid)
IS 'Marks one notification belonging to the authenticated user as read.';

-- ============================================================
-- 8. MARK ALL NOTIFICATIONS AS READ
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_mark_all_notifications_read()
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_updated_count integer;
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION
            'Authentication is required.';
    END IF;

    UPDATE public.notifications
    SET
        is_read = true,
        read_at = now(),
        updated_at = now(),
        updated_by = auth.uid()
    WHERE recipient_user_id = auth.uid()
      AND is_read = false
      AND is_active = true
      AND deleted_at IS NULL;

    GET DIAGNOSTICS
        v_updated_count = ROW_COUNT;

    RETURN v_updated_count;
END;
$$;

COMMENT ON FUNCTION public.fn_mark_all_notifications_read()
IS 'Marks all active notifications belonging to the authenticated user as read.';

-- ============================================================
-- 9. UNREAD NOTIFICATION COUNT
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_unread_notification_count()
RETURNS bigint
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT count(*)
    FROM public.notifications n
    WHERE n.recipient_user_id = auth.uid()
      AND n.is_read = false
      AND n.is_active = true
      AND n.deleted_at IS NULL;
$$;

COMMENT ON FUNCTION public.fn_unread_notification_count()
IS 'Returns the unread notification count for the authenticated user.';

-- ============================================================
-- 10. SOFT DELETE NOTIFICATION
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_delete_notification(
    p_notification_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
    IF auth.uid() IS NULL THEN
        RAISE EXCEPTION
            'Authentication is required.';
    END IF;

    UPDATE public.notifications
    SET
        is_active = false,
        deleted_at = now(),
        updated_at = now(),
        updated_by = auth.uid()
    WHERE id = p_notification_id
      AND recipient_user_id = auth.uid()
      AND deleted_at IS NULL;

    RETURN FOUND;
END;
$$;

COMMENT ON FUNCTION public.fn_delete_notification(uuid)
IS 'Soft deletes one notification belonging to the authenticated user.';

-- ============================================================
-- 11. TRIAL SUBMISSION NOTIFICATION TRIGGER
-- ============================================================

CREATE OR REPLACE FUNCTION public.fn_notify_trial_workflow_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_old_status_code text;
    v_new_status_code text;
    v_trial_creator_user_id uuid;
    v_notification_title text;
    v_notification_message text;
BEGIN
    SELECT ts.code::text
    INTO v_new_status_code
    FROM public.trial_statuses ts
    WHERE ts.id = NEW.status_id;

    IF TG_OP = 'UPDATE' THEN
        SELECT ts.code::text
        INTO v_old_status_code
        FROM public.trial_statuses ts
        WHERE ts.id = OLD.status_id;
    END IF;

    IF TG_OP = 'INSERT'
       OR NEW.status_id IS DISTINCT FROM OLD.status_id THEN

        IF v_new_status_code = 'PENDING_APPROVAL'
           AND COALESCE(
               v_old_status_code,
               ''
           ) <> 'PENDING_APPROVAL' THEN

            PERFORM public.fn_notify_management(
                p_notification_type =>
                    'TRIAL_SUBMITTED',
                p_title =>
                    'New trial awaiting approval',
                p_message =>
                    concat(
                        'Trial ',
                        NEW.business_id,
                        ' has been submitted for approval.'
                    ),
                p_entity_type =>
                    'TRIAL',
                p_entity_id =>
                    NEW.id,
                p_action_url =>
                    concat(
                        '/trials/',
                        NEW.id::text
                    ),
                p_metadata =>
                    jsonb_build_object(
                        'trial_id',
                        NEW.id,
                        'business_id',
                        NEW.business_id,
                        'status',
                        v_new_status_code
                    ),
                p_priority =>
                    'HIGH'
            );
        END IF;

        IF v_new_status_code IN (
            'APPROVED',
            'REJECTED',
            'CORRECTIONS_REQUESTED',
            'COMPLETED'
        ) THEN
            SELECT p.user_id
            INTO v_trial_creator_user_id
            FROM public.profiles p
            WHERE p.id = NEW.created_by
               OR p.user_id = NEW.created_by
            ORDER BY
                CASE
                    WHEN p.user_id = NEW.created_by
                    THEN 1
                    ELSE 2
                END
            LIMIT 1;

            IF v_trial_creator_user_id IS NOT NULL THEN
                v_notification_title :=
                    CASE v_new_status_code
                        WHEN 'APPROVED'
                            THEN 'Trial approved'
                        WHEN 'REJECTED'
                            THEN 'Trial rejected'
                        WHEN 'CORRECTIONS_REQUESTED'
                            THEN 'Trial corrections requested'
                        WHEN 'COMPLETED'
                            THEN 'Trial completed'
                    END;

                v_notification_message :=
                    CASE v_new_status_code
                        WHEN 'APPROVED'
                            THEN concat(
                                'Trial ',
                                NEW.business_id,
                                ' has been approved.'
                            )
                        WHEN 'REJECTED'
                            THEN concat(
                                'Trial ',
                                NEW.business_id,
                                ' has been rejected.'
                            )
                        WHEN 'CORRECTIONS_REQUESTED'
                            THEN concat(
                                'Corrections have been requested for trial ',
                                NEW.business_id,
                                '.'
                            )
                        WHEN 'COMPLETED'
                            THEN concat(
                                'Trial ',
                                NEW.business_id,
                                ' has been marked as completed.'
                            )
                    END;

                PERFORM public.fn_create_notification(
                    p_recipient_user_id =>
                        v_trial_creator_user_id,
                    p_notification_type =>
                        concat(
                            'TRIAL_',
                            v_new_status_code
                        ),
                    p_title =>
                        v_notification_title,
                    p_message =>
                        v_notification_message,
                    p_entity_type =>
                        'TRIAL',
                    p_entity_id =>
                        NEW.id,
                    p_action_url =>
                        concat(
                            '/trials/',
                            NEW.id::text
                        ),
                    p_metadata =>
                        jsonb_build_object(
                            'trial_id',
                            NEW.id,
                            'business_id',
                            NEW.business_id,
                            'previous_status',
                            v_old_status_code,
                            'new_status',
                            v_new_status_code
                        ),
                    p_priority =>
                        CASE
                            WHEN v_new_status_code IN (
                                'REJECTED',
                                'CORRECTIONS_REQUESTED'
                            )
                            THEN 'HIGH'
                            ELSE 'NORMAL'
                        END,
                    p_sender_user_id =>
                        auth.uid()
                );
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_notify_trial_workflow_change()
IS 'Creates in-app notifications when the workflow status of a trial changes.';

DROP TRIGGER IF EXISTS trg_notify_trial_workflow_change
ON public.trials;

CREATE TRIGGER trg_notify_trial_workflow_change
AFTER INSERT OR UPDATE OF status_id
ON public.trials
FOR EACH ROW
EXECUTE FUNCTION public.fn_notify_trial_workflow_change();

-- ============================================================
-- 12. ENABLE ROW LEVEL SECURITY
-- ============================================================

ALTER TABLE public.notifications
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.notifications
FORCE ROW LEVEL SECURITY;

-- ============================================================
-- 13. DROP EXISTING NOTIFICATION POLICIES
-- ============================================================

DROP POLICY IF EXISTS notifications_select_own
ON public.notifications;

DROP POLICY IF EXISTS notifications_insert_authorized
ON public.notifications;

DROP POLICY IF EXISTS notifications_update_own
ON public.notifications;

DROP POLICY IF EXISTS notifications_delete_own
ON public.notifications;

-- ============================================================
-- 14. NOTIFICATION SELECT POLICY
-- ============================================================

CREATE POLICY notifications_select_own
ON public.notifications
FOR SELECT
TO authenticated
USING (
    recipient_user_id = auth.uid()
    AND deleted_at IS NULL
);

-- ============================================================
-- 15. NOTIFICATION INSERT POLICY
-- ============================================================

CREATE POLICY notifications_insert_authorized
ON public.notifications
FOR INSERT
TO authenticated
WITH CHECK (
    public.fn_current_user_is_active()
    AND (
        sender_user_id = auth.uid()
        OR sender_user_id IS NULL
    )
    AND (
        recipient_user_id = auth.uid()
        OR public.fn_is_management()
    )
);

-- ============================================================
-- 16. NOTIFICATION UPDATE POLICY
-- ============================================================

CREATE POLICY notifications_update_own
ON public.notifications
FOR UPDATE
TO authenticated
USING (
    recipient_user_id = auth.uid()
    AND deleted_at IS NULL
)
WITH CHECK (
    recipient_user_id = auth.uid()
);

-- ============================================================
-- 17. NOTIFICATION DELETE POLICY
-- ============================================================

CREATE POLICY notifications_delete_own
ON public.notifications
FOR DELETE
TO authenticated
USING (
    recipient_user_id = auth.uid()
);

-- ============================================================
-- 18. TABLE SECURITY
-- ============================================================

REVOKE ALL
ON TABLE public.notifications
FROM PUBLIC, anon;

GRANT SELECT
ON TABLE public.notifications
TO authenticated;

GRANT INSERT, UPDATE, DELETE
ON TABLE public.notifications
TO authenticated;

GRANT ALL
ON TABLE public.notifications
TO service_role;

-- ============================================================
-- 19. FUNCTION SECURITY
-- ============================================================

REVOKE ALL
ON FUNCTION public.fn_notifications_set_updated_at()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_notifications_sync_read_state()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_create_notification(
    uuid,
    text,
    text,
    text,
    text,
    uuid,
    text,
    jsonb,
    text,
    uuid
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_notify_management(
    text,
    text,
    text,
    text,
    uuid,
    text,
    jsonb,
    text
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_mark_notification_read(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_mark_all_notifications_read()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_unread_notification_count()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_delete_notification(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_notify_trial_workflow_change()
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.fn_create_notification(
    uuid,
    text,
    text,
    text,
    text,
    uuid,
    text,
    jsonb,
    text,
    uuid
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_notify_management(
    text,
    text,
    text,
    text,
    uuid,
    text,
    jsonb,
    text
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_mark_notification_read(uuid)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_mark_all_notifications_read()
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_unread_notification_count()
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_delete_notification(uuid)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_notifications_set_updated_at()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_notifications_sync_read_state()
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_notify_trial_workflow_change()
TO service_role;

-- ============================================================
-- 20. ADD NOTIFICATIONS TO SUPABASE REALTIME
-- ============================================================

ALTER TABLE public.notifications
REPLICA IDENTITY FULL;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_publication
        WHERE pubname = 'supabase_realtime'
    )
    AND NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_publication_tables pt
        WHERE pt.pubname = 'supabase_realtime'
          AND pt.schemaname = 'public'
          AND pt.tablename = 'notifications'
    ) THEN
        ALTER PUBLICATION supabase_realtime
        ADD TABLE public.notifications;
    END IF;
END;
$$;

-- ============================================================
-- 21. SCHEMA VERSION
-- ============================================================

INSERT INTO public.schema_versions
(
    version_number,
    migration_name
)
VALUES
(
    53,
    '0053_in_app_notifications.sql'
)
ON CONFLICT (version_number)
DO UPDATE SET
    migration_name = EXCLUDED.migration_name,
    applied_at = now();

-- ============================================================
-- 22. VALIDATION
-- ============================================================

DO $$
BEGIN
    IF to_regclass(
        'public.notifications'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Notifications table creation failed.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_policies p
        WHERE p.schemaname = 'public'
          AND p.tablename = 'notifications'
          AND p.policyname = 'notifications_select_own'
    ) THEN
        RAISE EXCEPTION
            'Notifications SELECT policy validation failed.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_trigger t
        JOIN pg_catalog.pg_class c
          ON c.oid = t.tgrelid
        JOIN pg_catalog.pg_namespace n
          ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relname = 'trials'
          AND t.tgname =
              'trg_notify_trial_workflow_change'
          AND t.tgisinternal = false
    ) THEN
        RAISE EXCEPTION
            'Trial workflow notification trigger validation failed.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_publication
        WHERE pubname = 'supabase_realtime'
    )
    AND NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_publication_tables pt
        WHERE pt.pubname = 'supabase_realtime'
          AND pt.schemaname = 'public'
          AND pt.tablename = 'notifications'
    ) THEN
        RAISE EXCEPTION
            'Notifications Realtime publication validation failed.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM public.schema_versions
        WHERE version_number = 53
    ) THEN
        RAISE EXCEPTION
            'Schema version 53 registration failed.';
    END IF;

    RAISE NOTICE
        '0053_in_app_notifications.sql completed successfully.';
END;
$$;

COMMIT;
