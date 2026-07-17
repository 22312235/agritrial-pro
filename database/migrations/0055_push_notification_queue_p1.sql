BEGIN;

SET search_path = public, auth, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

CREATE TABLE IF NOT EXISTS public.push_notification_queue
(
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    notification_id uuid NULL
        REFERENCES public.notifications(id)
        ON DELETE SET NULL,

    recipient_user_id uuid NOT NULL
        REFERENCES auth.users(id)
        ON DELETE CASCADE,

    device_id uuid NULL
        REFERENCES public.user_push_devices(id)
        ON DELETE SET NULL,

    push_token text NOT NULL,

    platform varchar(20) NOT NULL,

    title varchar(200) NOT NULL,

    message text NOT NULL,

    data_payload jsonb NOT NULL DEFAULT '{}'::jsonb,

    priority varchar(20) NOT NULL DEFAULT 'NORMAL',

    delivery_status varchar(30) NOT NULL DEFAULT 'PENDING',

    attempt_count integer NOT NULL DEFAULT 0,

    maximum_attempts integer NOT NULL DEFAULT 5,

    scheduled_at timestamptz NOT NULL DEFAULT now(),

    locked_at timestamptz NULL,

    locked_by text NULL,

    processing_started_at timestamptz NULL,

    delivered_at timestamptz NULL,

    failed_at timestamptz NULL,

    next_retry_at timestamptz NULL,

    provider_message_id text NULL,

    provider_response jsonb NULL,

    error_code text NULL,

    error_message text NULL,

    is_active boolean NOT NULL DEFAULT true,

    created_at timestamptz NOT NULL DEFAULT now(),

    updated_at timestamptz NOT NULL DEFAULT now(),

    created_by uuid NULL
        REFERENCES auth.users(id)
        ON DELETE SET NULL,

    updated_by uuid NULL
        REFERENCES auth.users(id)
        ON DELETE SET NULL,

    deleted_at timestamptz NULL,

    CONSTRAINT push_notification_queue_token_not_blank
        CHECK (btrim(push_token) <> ''),

    CONSTRAINT push_notification_queue_platform_check
        CHECK (
            platform IN (
                'ANDROID',
                'IOS',
                'WEB'
            )
        ),

    CONSTRAINT push_notification_queue_title_not_blank
        CHECK (btrim(title) <> ''),

    CONSTRAINT push_notification_queue_message_not_blank
        CHECK (btrim(message) <> ''),

    CONSTRAINT push_notification_queue_priority_check
        CHECK (
            priority IN (
                'LOW',
                'NORMAL',
                'HIGH',
                'URGENT'
            )
        ),

    CONSTRAINT push_notification_queue_status_check
        CHECK (
            delivery_status IN (
                'PENDING',
                'PROCESSING',
                'DELIVERED',
                'FAILED',
                'RETRY_SCHEDULED',
                'CANCELLED'
            )
        ),

    CONSTRAINT push_notification_queue_attempt_count_check
        CHECK (attempt_count >= 0),

    CONSTRAINT push_notification_queue_maximum_attempts_check
        CHECK (
            maximum_attempts BETWEEN 1 AND 20
        ),

    CONSTRAINT push_notification_queue_attempt_limit_check
        CHECK (
            attempt_count <= maximum_attempts
        ),

    CONSTRAINT push_notification_queue_payload_object_check
        CHECK (
            jsonb_typeof(data_payload) = 'object'
        ),

    CONSTRAINT push_notification_queue_provider_response_check
        CHECK (
            provider_response IS NULL
            OR jsonb_typeof(provider_response) = 'object'
        ),

    CONSTRAINT push_notification_queue_deleted_state_check
        CHECK (
            deleted_at IS NULL
            OR is_active = false
        ),

    CONSTRAINT push_notification_queue_delivery_state_check
        CHECK (
            delivery_status <> 'DELIVERED'
            OR delivered_at IS NOT NULL
        ),

    CONSTRAINT push_notification_queue_failure_state_check
        CHECK (
            delivery_status <> 'FAILED'
            OR failed_at IS NOT NULL
        ),

    CONSTRAINT push_notification_queue_processing_state_check
        CHECK (
            delivery_status <> 'PROCESSING'
            OR processing_started_at IS NOT NULL
        )
);

COMMENT ON TABLE public.push_notification_queue
IS 'Stores queued push notification deliveries for registered user devices.';

COMMENT ON COLUMN public.push_notification_queue.notification_id
IS 'Related in-app notification record.';

COMMENT ON COLUMN public.push_notification_queue.device_id
IS 'Registered device targeted by the push notification.';

COMMENT ON COLUMN public.push_notification_queue.data_payload
IS 'Structured application data delivered with the push notification.';

COMMENT ON COLUMN public.push_notification_queue.delivery_status
IS 'Push delivery lifecycle status.';

CREATE UNIQUE INDEX IF NOT EXISTS uq_push_notification_queue_delivery
ON public.push_notification_queue
(
    notification_id,
    device_id
)
WHERE notification_id IS NOT NULL
  AND device_id IS NOT NULL
  AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_push_notification_queue_pending
ON public.push_notification_queue
(
    priority DESC,
    scheduled_at ASC,
    created_at ASC
)
WHERE delivery_status IN (
        'PENDING',
        'RETRY_SCHEDULED'
    )
  AND is_active = true
  AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_push_notification_queue_retry
ON public.push_notification_queue(next_retry_at)
WHERE delivery_status = 'RETRY_SCHEDULED'
  AND is_active = true
  AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_push_notification_queue_recipient
ON public.push_notification_queue
(
    recipient_user_id,
    created_at DESC
)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_push_notification_queue_notification
ON public.push_notification_queue(notification_id)
WHERE notification_id IS NOT NULL
  AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_push_notification_queue_device
ON public.push_notification_queue
(
    device_id,
    created_at DESC
)
WHERE device_id IS NOT NULL
  AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_push_notification_queue_status
ON public.push_notification_queue
(
    delivery_status,
    updated_at DESC
)
WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_push_notification_queue_locked
ON public.push_notification_queue(locked_at)
WHERE delivery_status = 'PROCESSING'
  AND deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_push_notification_queue_payload
ON public.push_notification_queue
USING gin(data_payload);

CREATE OR REPLACE FUNCTION public.fn_push_queue_normalize()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth, extensions
AS $$
BEGIN
    NEW.push_token := btrim(NEW.push_token);

    NEW.platform :=
        upper(
            btrim(NEW.platform)
        );

    NEW.title := btrim(NEW.title);

    NEW.message := btrim(NEW.message);

    NEW.priority :=
        upper(
            btrim(
                COALESCE(
                    NEW.priority,
                    'NORMAL'
                )
            )
        );

    NEW.delivery_status :=
        upper(
            btrim(
                COALESCE(
                    NEW.delivery_status,
                    'PENDING'
                )
            )
        );

    NEW.locked_by :=
        NULLIF(
            btrim(NEW.locked_by),
            ''
        );

    NEW.provider_message_id :=
        NULLIF(
            btrim(NEW.provider_message_id),
            ''
        );

    NEW.error_code :=
        NULLIF(
            btrim(NEW.error_code),
            ''
        );

    NEW.error_message :=
        NULLIF(
            btrim(NEW.error_message),
            ''
        );

    NEW.data_payload :=
        COALESCE(
            NEW.data_payload,
            '{}'::jsonb
        );

    NEW.updated_at := now();

    IF TG_OP = 'INSERT' THEN
        NEW.created_by :=
            COALESCE(
                NEW.created_by,
                auth.uid()
            );

        NEW.updated_by :=
            COALESCE(
                NEW.updated_by,
                auth.uid()
            );
    ELSE
        NEW.updated_by :=
            COALESCE(
                auth.uid(),
                NEW.updated_by
            );
    END IF;

    IF NEW.is_active = true THEN
        NEW.deleted_at := NULL;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_push_queue_normalize
ON public.push_notification_queue;

CREATE TRIGGER trg_push_queue_normalize
BEFORE INSERT OR UPDATE
ON public.push_notification_queue
FOR EACH ROW
EXECUTE FUNCTION public.fn_push_queue_normalize();

CREATE OR REPLACE FUNCTION public.fn_enqueue_notification_push(
    p_notification_id uuid
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_notification record;
    v_created_count integer := 0;
BEGIN
    SELECT
        n.id,
        n.recipient_user_id,
        n.title,
        n.message,
        n.notification_type,
        n.entity_type,
        n.entity_id,
        n.action_url,
        n.metadata,
        n.priority,
        n.created_by,
        n.updated_by
    INTO v_notification
    FROM public.notifications n
    WHERE n.id = p_notification_id
      AND n.is_active = true
      AND n.deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Active notification not found: %',
            p_notification_id;
    END IF;

    INSERT INTO public.push_notification_queue
    (
        notification_id,
        recipient_user_id,
        device_id,
        push_token,
        platform,
        title,
        message,
        data_payload,
        priority,
        delivery_status,
        maximum_attempts,
        scheduled_at,
        created_by,
        updated_by
    )
    SELECT
        v_notification.id,
        v_notification.recipient_user_id,
        d.id,
        d.push_token,
        d.platform,
        v_notification.title,
        v_notification.message,
        jsonb_build_object(
            'notification_id',
            v_notification.id,
            'notification_type',
            v_notification.notification_type,
            'entity_type',
            v_notification.entity_type,
            'entity_id',
            v_notification.entity_id,
            'action_url',
            v_notification.action_url,
            'metadata',
            COALESCE(
                v_notification.metadata,
                '{}'::jsonb
            )
        ),
        COALESCE(
            v_notification.priority,
            'NORMAL'
        ),
        'PENDING',
        5,
        now(),
        v_notification.created_by,
        v_notification.updated_by
    FROM public.user_push_devices d
    JOIN public.profiles p
      ON p.user_id = d.user_id
    WHERE d.user_id =
          v_notification.recipient_user_id
      AND d.notifications_enabled = true
      AND d.is_active = true
      AND d.deleted_at IS NULL
      AND p.is_active = true
      AND p.deleted_at IS NULL
    ON CONFLICT (
        notification_id,
        device_id
    )
    WHERE notification_id IS NOT NULL
      AND device_id IS NOT NULL
      AND deleted_at IS NULL
    DO NOTHING;

    GET DIAGNOSTICS
        v_created_count = ROW_COUNT;

    RETURN v_created_count;
END;
$$;

COMMENT ON FUNCTION public.fn_enqueue_notification_push(uuid)
IS 'Creates one push queue record for each active device belonging to the notification recipient.';

CREATE OR REPLACE FUNCTION public.fn_auto_enqueue_notification_push()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
    IF NEW.is_active = true
       AND NEW.deleted_at IS NULL THEN
        PERFORM public.fn_enqueue_notification_push(
            NEW.id
        );
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_auto_enqueue_notification_push()
IS 'Automatically queues push notification deliveries after a notification is created.';

DROP TRIGGER IF EXISTS trg_auto_enqueue_notification_push
ON public.notifications;

CREATE TRIGGER trg_auto_enqueue_notification_push
AFTER INSERT
ON public.notifications
FOR EACH ROW
EXECUTE FUNCTION public.fn_auto_enqueue_notification_push();

DO $$
BEGIN
    IF to_regclass(
        'public.push_notification_queue'
    ) IS NULL THEN
        RAISE EXCEPTION
            'push_notification_queue table creation failed.';
    END IF;

    IF to_regclass(
        'public.user_push_devices'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Required table public.user_push_devices does not exist.';
    END IF;

    IF to_regprocedure(
        'public.fn_enqueue_notification_push(uuid)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_enqueue_notification_push function creation failed.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_catalog.pg_trigger t
        JOIN pg_catalog.pg_class c
          ON c.oid = t.tgrelid
        JOIN pg_catalog.pg_namespace n
          ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relname = 'notifications'
          AND t.tgname =
              'trg_auto_enqueue_notification_push'
          AND t.tgisinternal = false
    ) THEN
        RAISE EXCEPTION
            'Automatic push enqueue trigger creation failed.';
    END IF;
END;
$$;

COMMIT;
