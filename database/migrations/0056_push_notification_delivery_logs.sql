-- =====================================================================
-- AGRITRIAL PRO
-- Migration: 0056_push_notification_delivery_logs.sql
-- Purpose:
--   Stores the complete audit history of push-notification delivery
--   attempts performed by server workers, Supabase Edge Functions,
--   Firebase Cloud Messaging, APNs, or Web Push providers.
-- =====================================================================

BEGIN;

SET search_path = public, auth, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

-- =====================================================================
-- 1. PRE-MIGRATION VALIDATION
-- =====================================================================

DO $$
BEGIN
    IF to_regclass('public.push_notification_queue') IS NULL THEN
        RAISE EXCEPTION
            'Required table public.push_notification_queue does not exist. Run migration 0055 first.';
    END IF;

    IF to_regclass('public.notifications') IS NULL THEN
        RAISE EXCEPTION
            'Required table public.notifications does not exist. Run migration 0053 first.';
    END IF;

    IF to_regclass('public.user_push_devices') IS NULL THEN
        RAISE EXCEPTION
            'Required table public.user_push_devices does not exist. Run migration 0054 first.';
    END IF;
END;
$$;

-- =====================================================================
-- 2. PUSH DELIVERY LOG TABLE
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.push_notification_delivery_logs
(
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    queue_id uuid NOT NULL
        REFERENCES public.push_notification_queue(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    notification_id uuid NULL
        REFERENCES public.notifications(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    recipient_user_id uuid NOT NULL
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    device_id uuid NULL
        REFERENCES public.user_push_devices(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    attempt_number integer NOT NULL DEFAULT 1,

    worker_id text NULL,

    provider varchar(30) NOT NULL DEFAULT 'FCM',

    platform varchar(20) NOT NULL,

    delivery_status varchar(30) NOT NULL DEFAULT 'PROCESSING',

    push_token_snapshot text NULL,

    provider_message_id text NULL,

    request_payload jsonb NOT NULL DEFAULT '{}'::jsonb,

    provider_response jsonb NULL,

    http_status_code integer NULL,

    error_code text NULL,

    error_message text NULL,

    retryable boolean NOT NULL DEFAULT false,

    started_at timestamptz NOT NULL DEFAULT now(),

    completed_at timestamptz NULL,

    latency_ms integer NULL,

    created_at timestamptz NOT NULL DEFAULT now(),

    created_by uuid NULL
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT chk_push_delivery_log_attempt_number
        CHECK (attempt_number >= 1),

    CONSTRAINT chk_push_delivery_log_worker_id
        CHECK (
            worker_id IS NULL
            OR btrim(worker_id) <> ''
        ),

    CONSTRAINT chk_push_delivery_log_provider
        CHECK (
            provider IN (
                'FCM',
                'APNS',
                'WEB_PUSH',
                'OTHER'
            )
        ),

    CONSTRAINT chk_push_delivery_log_platform
        CHECK (
            platform IN (
                'ANDROID',
                'IOS',
                'WEB',
                'UNKNOWN'
            )
        ),

    CONSTRAINT chk_push_delivery_log_status
        CHECK (
            delivery_status IN (
                'PROCESSING',
                'DELIVERED',
                'FAILED',
                'RETRY_SCHEDULED',
                'CANCELLED'
            )
        ),

    CONSTRAINT chk_push_delivery_log_request_payload
        CHECK (
            jsonb_typeof(request_payload) = 'object'
        ),

    CONSTRAINT chk_push_delivery_log_provider_response
        CHECK (
            provider_response IS NULL
            OR jsonb_typeof(provider_response) = 'object'
        ),

    CONSTRAINT chk_push_delivery_log_http_status
        CHECK (
            http_status_code IS NULL
            OR http_status_code BETWEEN 100 AND 599
        ),

    CONSTRAINT chk_push_delivery_log_latency
        CHECK (
            latency_ms IS NULL
            OR latency_ms >= 0
        ),

    CONSTRAINT chk_push_delivery_log_completion_time
        CHECK (
            completed_at IS NULL
            OR completed_at >= started_at
        ),

    CONSTRAINT chk_push_delivery_log_completed_status
        CHECK (
            delivery_status = 'PROCESSING'
            OR completed_at IS NOT NULL
        )
);

COMMENT ON TABLE public.push_notification_delivery_logs IS
'Immutable audit history for every push-notification delivery attempt.';

COMMENT ON COLUMN public.push_notification_delivery_logs.queue_id IS
'Push-notification queue item associated with the delivery attempt.';

COMMENT ON COLUMN public.push_notification_delivery_logs.notification_id IS
'In-app notification associated with the push delivery.';

COMMENT ON COLUMN public.push_notification_delivery_logs.recipient_user_id IS
'Authenticated user receiving the push notification.';

COMMENT ON COLUMN public.push_notification_delivery_logs.device_id IS
'Registered push-notification device used for the delivery attempt.';

COMMENT ON COLUMN public.push_notification_delivery_logs.attempt_number IS
'Sequential delivery-attempt number for the queue item.';

COMMENT ON COLUMN public.push_notification_delivery_logs.worker_id IS
'Identifier of the Edge Function, server process, or background worker.';

COMMENT ON COLUMN public.push_notification_delivery_logs.provider IS
'Push provider used for delivery: FCM, APNS, WEB_PUSH, or OTHER.';

COMMENT ON COLUMN public.push_notification_delivery_logs.platform IS
'Target platform: ANDROID, IOS, WEB, or UNKNOWN.';

COMMENT ON COLUMN public.push_notification_delivery_logs.push_token_snapshot IS
'Push token used for this delivery attempt, retained for auditing.';

COMMENT ON COLUMN public.push_notification_delivery_logs.request_payload IS
'JSON payload submitted to the push provider.';

COMMENT ON COLUMN public.push_notification_delivery_logs.provider_response IS
'Structured JSON response returned by the push provider.';

COMMENT ON COLUMN public.push_notification_delivery_logs.latency_ms IS
'Total provider-request duration in milliseconds.';

-- =====================================================================
-- 3. UNIQUE CONSTRAINT AND INDEXES
-- =====================================================================

CREATE UNIQUE INDEX IF NOT EXISTS
uq_push_delivery_logs_queue_attempt
ON public.push_notification_delivery_logs
(
    queue_id,
    attempt_number
);

CREATE INDEX IF NOT EXISTS
idx_push_delivery_logs_notification
ON public.push_notification_delivery_logs
(
    notification_id,
    created_at DESC
)
WHERE notification_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS
idx_push_delivery_logs_recipient
ON public.push_notification_delivery_logs
(
    recipient_user_id,
    created_at DESC
);

CREATE INDEX IF NOT EXISTS
idx_push_delivery_logs_device
ON public.push_notification_delivery_logs
(
    device_id,
    created_at DESC
)
WHERE device_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS
idx_push_delivery_logs_queue
ON public.push_notification_delivery_logs
(
    queue_id,
    attempt_number DESC
);

CREATE INDEX IF NOT EXISTS
idx_push_delivery_logs_status
ON public.push_notification_delivery_logs
(
    delivery_status,
    created_at DESC
);

CREATE INDEX IF NOT EXISTS
idx_push_delivery_logs_provider
ON public.push_notification_delivery_logs
(
    provider,
    created_at DESC
);

CREATE INDEX IF NOT EXISTS
idx_push_delivery_logs_platform
ON public.push_notification_delivery_logs
(
    platform,
    created_at DESC
);

CREATE INDEX IF NOT EXISTS
idx_push_delivery_logs_error_code
ON public.push_notification_delivery_logs
(
    error_code,
    created_at DESC
)
WHERE error_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS
idx_push_delivery_logs_started_at
ON public.push_notification_delivery_logs
(
    started_at DESC
);

CREATE INDEX IF NOT EXISTS
idx_push_delivery_logs_completed_at
ON public.push_notification_delivery_logs
(
    completed_at DESC
)
WHERE completed_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS
idx_push_delivery_logs_request_payload
ON public.push_notification_delivery_logs
USING gin(request_payload);

CREATE INDEX IF NOT EXISTS
idx_push_delivery_logs_provider_response
ON public.push_notification_delivery_logs
USING gin(provider_response)
WHERE provider_response IS NOT NULL;

-- =====================================================================
-- 4. NORMALIZATION TRIGGER FUNCTION
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_normalize_push_delivery_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, auth, extensions
AS $$
BEGIN
    NEW.worker_id :=
        NULLIF(
            btrim(NEW.worker_id),
            ''
        );

    NEW.provider :=
        upper(
            btrim(
                COALESCE(
                    NEW.provider,
                    'FCM'
                )
            )
        );

    NEW.platform :=
        upper(
            btrim(
                COALESCE(
                    NEW.platform,
                    'UNKNOWN'
                )
            )
        );

    NEW.delivery_status :=
        upper(
            btrim(
                COALESCE(
                    NEW.delivery_status,
                    'PROCESSING'
                )
            )
        );

    NEW.push_token_snapshot :=
        NULLIF(
            btrim(NEW.push_token_snapshot),
            ''
        );

    NEW.provider_message_id :=
        NULLIF(
            btrim(NEW.provider_message_id),
            ''
        );

    NEW.error_code :=
        NULLIF(
            upper(
                btrim(NEW.error_code)
            ),
            ''
        );

    NEW.error_message :=
        NULLIF(
            btrim(NEW.error_message),
            ''
        );

    NEW.request_payload :=
        COALESCE(
            NEW.request_payload,
            '{}'::jsonb
        );

    NEW.created_at :=
        COALESCE(
            NEW.created_at,
            now()
        );

    NEW.started_at :=
        COALESCE(
            NEW.started_at,
            now()
        );

    NEW.created_by :=
        COALESCE(
            NEW.created_by,
            auth.uid()
        );

    IF NEW.delivery_status <> 'PROCESSING'
       AND NEW.completed_at IS NULL THEN
        NEW.completed_at := now();
    END IF;

    IF NEW.completed_at IS NOT NULL
       AND NEW.latency_ms IS NULL THEN
        NEW.latency_ms :=
            GREATEST(
                0,
                floor(
                    extract(
                        epoch
                        FROM (
                            NEW.completed_at
                            - NEW.started_at
                        )
                    ) * 1000
                )::integer
            );
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.fn_normalize_push_delivery_log() IS
'Normalizes push-delivery log values and calculates completion latency.';

DROP TRIGGER IF EXISTS trg_normalize_push_delivery_log
ON public.push_notification_delivery_logs;

CREATE TRIGGER trg_normalize_push_delivery_log
BEFORE INSERT OR UPDATE
ON public.push_notification_delivery_logs
FOR EACH ROW
EXECUTE FUNCTION public.fn_normalize_push_delivery_log();

-- =====================================================================
-- 5. START DELIVERY LOG
--
-- Uses to_jsonb(queue row) so the function remains compatible with
-- variations in optional queue-table column definitions.
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_start_push_delivery_log(
    p_queue_id uuid,
    p_worker_id text,
    p_provider varchar DEFAULT 'FCM',
    p_request_payload jsonb DEFAULT '{}'::jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_queue_data jsonb;
    v_log_id uuid;

    v_notification_id uuid;
    v_recipient_user_id uuid;
    v_device_id uuid;

    v_attempt_number integer;
    v_platform varchar;
    v_delivery_status varchar;
    v_push_token text;
BEGIN
    IF p_queue_id IS NULL THEN
        RAISE EXCEPTION
            'Queue identifier is required.';
    END IF;

    IF p_worker_id IS NULL
       OR btrim(p_worker_id) = '' THEN
        RAISE EXCEPTION
            'Worker identifier is required.';
    END IF;

    IF p_request_payload IS NULL
       OR jsonb_typeof(p_request_payload) <> 'object' THEN
        RAISE EXCEPTION
            'Request payload must be a JSON object.';
    END IF;

    SELECT to_jsonb(q)
    INTO v_queue_data
    FROM public.push_notification_queue q
    WHERE q.id = p_queue_id
    FOR UPDATE;

    IF v_queue_data IS NULL THEN
        RAISE EXCEPTION
            'Push queue item not found: %',
            p_queue_id;
    END IF;

    v_notification_id :=
        NULLIF(
            v_queue_data ->> 'notification_id',
            ''
        )::uuid;

    v_recipient_user_id :=
        COALESCE(
            NULLIF(
                v_queue_data ->> 'recipient_user_id',
                ''
            )::uuid,
            NULLIF(
                v_queue_data ->> 'user_id',
                ''
            )::uuid
        );

    v_device_id :=
        NULLIF(
            v_queue_data ->> 'device_id',
            ''
        )::uuid;

    v_attempt_number :=
        GREATEST(
            COALESCE(
                NULLIF(
                    v_queue_data ->> 'attempt_count',
                    ''
                )::integer,
                NULLIF(
                    v_queue_data ->> 'attempt_number',
                    ''
                )::integer,
                1
            ),
            1
        );

    v_platform :=
        upper(
            COALESCE(
                NULLIF(
                    v_queue_data ->> 'platform',
                    ''
                ),
                'UNKNOWN'
            )
        );

    v_delivery_status :=
        upper(
            COALESCE(
                NULLIF(
                    v_queue_data ->> 'delivery_status',
                    ''
                ),
                NULLIF(
                    v_queue_data ->> 'status',
                    ''
                ),
                'PROCESSING'
            )
        );

    v_push_token :=
        COALESCE(
            NULLIF(
                v_queue_data ->> 'push_token',
                ''
            ),
            NULLIF(
                v_queue_data ->> 'device_token',
                ''
            )
        );

    IF v_recipient_user_id IS NULL THEN
        RAISE EXCEPTION
            'Queue item % does not contain a recipient_user_id or user_id.',
            p_queue_id;
    END IF;

    IF v_platform NOT IN (
        'ANDROID',
        'IOS',
        'WEB',
        'UNKNOWN'
    ) THEN
        v_platform := 'UNKNOWN';
    END IF;

    IF v_delivery_status NOT IN (
        'PROCESSING',
        'CLAIMED',
        'SENDING',
        'IN_PROGRESS'
    ) THEN
        RAISE EXCEPTION
            'Queue item % is not currently processing. Current status: %',
            p_queue_id,
            v_delivery_status;
    END IF;

    INSERT INTO public.push_notification_delivery_logs
    (
        queue_id,
        notification_id,
        recipient_user_id,
        device_id,
        attempt_number,
        worker_id,
        provider,
        platform,
        delivery_status,
        push_token_snapshot,
        request_payload,
        retryable,
        started_at,
        created_by
    )
    VALUES
    (
        p_queue_id,
        v_notification_id,
        v_recipient_user_id,
        v_device_id,
        v_attempt_number,
        btrim(p_worker_id),
        upper(
            btrim(
                COALESCE(
                    p_provider,
                    'FCM'
                )
            )
        ),
        v_platform,
        'PROCESSING',
        v_push_token,
        p_request_payload,
        false,
        now(),
        auth.uid()
    )
    ON CONFLICT
    (
        queue_id,
        attempt_number
    )
    DO UPDATE SET
        notification_id =
            EXCLUDED.notification_id,

        recipient_user_id =
            EXCLUDED.recipient_user_id,

        device_id =
            EXCLUDED.device_id,

        worker_id =
            EXCLUDED.worker_id,

        provider =
            EXCLUDED.provider,

        platform =
            EXCLUDED.platform,

        delivery_status =
            'PROCESSING',

        push_token_snapshot =
            EXCLUDED.push_token_snapshot,

        request_payload =
            EXCLUDED.request_payload,

        provider_message_id =
            NULL,

        provider_response =
            NULL,

        http_status_code =
            NULL,

        error_code =
            NULL,

        error_message =
            NULL,

        retryable =
            false,

        started_at =
            now(),

        completed_at =
            NULL,

        latency_ms =
            NULL

    RETURNING id
    INTO v_log_id;

    RETURN v_log_id;
END;
$$;

COMMENT ON FUNCTION public.fn_start_push_delivery_log(
    uuid,
    text,
    varchar,
    jsonb
) IS
'Creates or resets the audit log for the current push-delivery attempt.';

-- =====================================================================
-- 6. COMPLETE DELIVERY LOG
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_complete_push_delivery_log(
    p_log_id uuid,
    p_delivery_status varchar,
    p_provider_message_id text DEFAULT NULL,
    p_provider_response jsonb DEFAULT NULL,
    p_http_status_code integer DEFAULT NULL,
    p_error_code text DEFAULT NULL,
    p_error_message text DEFAULT NULL,
    p_retryable boolean DEFAULT false
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_status varchar;
BEGIN
    IF p_log_id IS NULL THEN
        RAISE EXCEPTION
            'Delivery log identifier is required.';
    END IF;

    IF p_delivery_status IS NULL
       OR btrim(p_delivery_status) = '' THEN
        RAISE EXCEPTION
            'Delivery status is required.';
    END IF;

    v_status :=
        upper(
            btrim(p_delivery_status)
        );

    IF v_status NOT IN (
        'DELIVERED',
        'FAILED',
        'RETRY_SCHEDULED',
        'CANCELLED'
    ) THEN
        RAISE EXCEPTION
            'Invalid completed delivery status: %',
            p_delivery_status;
    END IF;

    IF p_provider_response IS NOT NULL
       AND jsonb_typeof(p_provider_response) <> 'object' THEN
        RAISE EXCEPTION
            'Provider response must be a JSON object.';
    END IF;

    IF p_http_status_code IS NOT NULL
       AND (
           p_http_status_code < 100
           OR p_http_status_code > 599
       ) THEN
        RAISE EXCEPTION
            'HTTP status code must be between 100 and 599.';
    END IF;

    UPDATE public.push_notification_delivery_logs
    SET
        delivery_status =
            v_status,

        provider_message_id =
            NULLIF(
                btrim(p_provider_message_id),
                ''
            ),

        provider_response =
            p_provider_response,

        http_status_code =
            p_http_status_code,

        error_code =
            NULLIF(
                upper(
                    btrim(p_error_code)
                ),
                ''
            ),

        error_message =
            NULLIF(
                btrim(p_error_message),
                ''
            ),

        retryable =
            CASE
                WHEN v_status = 'RETRY_SCHEDULED'
                    THEN true
                ELSE COALESCE(
                    p_retryable,
                    false
                )
            END,

        completed_at =
            now(),

        latency_ms =
            GREATEST(
                0,
                floor(
                    extract(
                        epoch
                        FROM (
                            now()
                            - started_at
                        )
                    ) * 1000
                )::integer
            )

    WHERE id = p_log_id
      AND delivery_status = 'PROCESSING';

    RETURN FOUND;
END;
$$;

COMMENT ON FUNCTION public.fn_complete_push_delivery_log(
    uuid,
    varchar,
    text,
    jsonb,
    integer,
    text,
    text,
    boolean
) IS
'Finalizes a push-delivery log with provider response, timing, and error information.';

-- =====================================================================
-- 7. CREATE AND COMPLETE A LOG IN ONE CALL
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_log_push_delivery_from_queue(
    p_queue_id uuid,
    p_worker_id text,
    p_provider varchar,
    p_delivery_status varchar,
    p_request_payload jsonb DEFAULT '{}'::jsonb,
    p_provider_message_id text DEFAULT NULL,
    p_provider_response jsonb DEFAULT NULL,
    p_http_status_code integer DEFAULT NULL,
    p_error_code text DEFAULT NULL,
    p_error_message text DEFAULT NULL,
    p_retryable boolean DEFAULT false
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_log_id uuid;
    v_completed boolean;
BEGIN
    v_log_id :=
        public.fn_start_push_delivery_log(
            p_queue_id,
            p_worker_id,
            p_provider,
            p_request_payload
        );

    v_completed :=
        public.fn_complete_push_delivery_log(
            v_log_id,
            p_delivery_status,
            p_provider_message_id,
            p_provider_response,
            p_http_status_code,
            p_error_code,
            p_error_message,
            p_retryable
        );

    IF NOT v_completed THEN
        RAISE EXCEPTION
            'Push-delivery log % could not be completed.',
            v_log_id;
    END IF;

    RETURN v_log_id;
END;
$$;

COMMENT ON FUNCTION public.fn_log_push_delivery_from_queue(
    uuid,
    text,
    varchar,
    varchar,
    jsonb,
    text,
    jsonb,
    integer,
    text,
    text,
    boolean
) IS
'Creates and immediately completes a delivery log for a processed push queue item.';

-- =====================================================================
-- 8. DELIVERY HISTORY FUNCTION
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_get_push_delivery_history(
    p_queue_id uuid
)
RETURNS TABLE
(
    log_id uuid,
    notification_id uuid,
    recipient_user_id uuid,
    device_id uuid,
    attempt_number integer,
    worker_id text,
    provider varchar,
    platform varchar,
    delivery_status varchar,
    provider_message_id text,
    http_status_code integer,
    error_code text,
    error_message text,
    retryable boolean,
    started_at timestamptz,
    completed_at timestamptz,
    latency_ms integer
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT
        l.id,
        l.notification_id,
        l.recipient_user_id,
        l.device_id,
        l.attempt_number,
        l.worker_id,
        l.provider,
        l.platform,
        l.delivery_status,
        l.provider_message_id,
        l.http_status_code,
        l.error_code,
        l.error_message,
        l.retryable,
        l.started_at,
        l.completed_at,
        l.latency_ms
    FROM public.push_notification_delivery_logs l
    WHERE l.queue_id = p_queue_id
    ORDER BY
        l.attempt_number DESC,
        l.started_at DESC;
$$;

COMMENT ON FUNCTION public.fn_get_push_delivery_history(uuid) IS
'Returns the complete push-delivery attempt history for one queue item.';

-- =====================================================================
-- 9. DELIVERY STATISTICS FUNCTION
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_get_push_delivery_statistics(
    p_start_date timestamptz DEFAULT NULL,
    p_end_date timestamptz DEFAULT NULL
)
RETURNS TABLE
(
    provider varchar,
    platform varchar,
    delivery_status varchar,
    total_attempts bigint,
    average_latency_ms numeric,
    minimum_latency_ms integer,
    maximum_latency_ms integer,
    retryable_failures bigint
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT
        l.provider,
        l.platform,
        l.delivery_status,

        count(*)::bigint
            AS total_attempts,

        round(
            avg(l.latency_ms)::numeric,
            2
        )
            AS average_latency_ms,

        min(l.latency_ms)
            AS minimum_latency_ms,

        max(l.latency_ms)
            AS maximum_latency_ms,

        count(*) FILTER (
            WHERE l.retryable = true
        )::bigint
            AS retryable_failures

    FROM public.push_notification_delivery_logs l

    WHERE
        (
            p_start_date IS NULL
            OR l.started_at >= p_start_date
        )
        AND
        (
            p_end_date IS NULL
            OR l.started_at < p_end_date
        )

    GROUP BY
        l.provider,
        l.platform,
        l.delivery_status

    ORDER BY
        l.provider,
        l.platform,
        l.delivery_status;
$$;

COMMENT ON FUNCTION public.fn_get_push_delivery_statistics(
    timestamptz,
    timestamptz
) IS
'Returns aggregated push-delivery metrics for a specified date range.';

-- =====================================================================
-- 10. CLEANUP FUNCTION
-- =====================================================================

CREATE OR REPLACE FUNCTION public.fn_cleanup_push_delivery_logs(
    p_retention_days integer DEFAULT 180
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
            'Delivery-log retention must be at least 30 days.';
    END IF;

    DELETE FROM public.push_notification_delivery_logs
    WHERE created_at <
          now() - make_interval(
              days => p_retention_days
          );

    GET DIAGNOSTICS
        v_deleted_count = ROW_COUNT;

    RETURN v_deleted_count;
END;
$$;

COMMENT ON FUNCTION public.fn_cleanup_push_delivery_logs(integer) IS
'Deletes push-delivery audit logs older than the configured retention period.';

-- =====================================================================
-- 11. DELIVERY SUMMARY VIEW
--
-- This corrected view depends only on the delivery-log table.
-- It does not assume optional columns from push_notification_queue.
-- =====================================================================

CREATE OR REPLACE VIEW public.v_push_notification_delivery_summary
WITH (security_invoker = true)
AS
SELECT
    l.queue_id,

    max(l.notification_id::text)::uuid
        AS notification_id,

    max(l.recipient_user_id::text)::uuid
        AS recipient_user_id,

    max(l.device_id::text)::uuid
        AS device_id,

    max(l.platform)
        AS platform,

    max(l.provider)
        AS provider,

    count(*)::bigint
        AS logged_attempts,

    count(*) FILTER (
        WHERE l.delivery_status = 'DELIVERED'
    )::bigint
        AS successful_attempts,

    count(*) FILTER (
        WHERE l.delivery_status = 'FAILED'
    )::bigint
        AS failed_attempts,

    count(*) FILTER (
        WHERE l.delivery_status = 'RETRY_SCHEDULED'
    )::bigint
        AS retry_scheduled_attempts,

    count(*) FILTER (
        WHERE l.delivery_status = 'CANCELLED'
    )::bigint
        AS cancelled_attempts,

    count(*) FILTER (
        WHERE l.delivery_status = 'PROCESSING'
    )::bigint
        AS processing_attempts,

    max(l.attempt_number)
        AS latest_attempt_number,

    round(
        avg(l.latency_ms)::numeric,
        2
    )
        AS average_latency_ms,

    min(l.latency_ms)
        AS minimum_latency_ms,

    max(l.latency_ms)
        AS maximum_latency_ms,

    min(l.started_at)
        AS first_attempt_started_at,

    max(l.started_at)
        AS last_attempt_started_at,

    max(l.completed_at)
        AS last_attempt_completed_at

FROM public.push_notification_delivery_logs l

GROUP BY
    l.queue_id;

COMMENT ON VIEW public.v_push_notification_delivery_summary IS
'Summarizes delivery attempts, outcomes, and latency for each push queue item.';

-- =====================================================================
-- 12. ROW-LEVEL SECURITY
-- =====================================================================

ALTER TABLE public.push_notification_delivery_logs
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.push_notification_delivery_logs
FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS push_delivery_logs_select_own
ON public.push_notification_delivery_logs;

DROP POLICY IF EXISTS push_delivery_logs_management_select
ON public.push_notification_delivery_logs;

DROP POLICY IF EXISTS push_delivery_logs_service_role_all
ON public.push_notification_delivery_logs;

CREATE POLICY push_delivery_logs_select_own
ON public.push_notification_delivery_logs
FOR SELECT
TO authenticated
USING
(
    recipient_user_id = auth.uid()
);

CREATE POLICY push_delivery_logs_management_select
ON public.push_notification_delivery_logs
FOR SELECT
TO authenticated
USING
(
    public.fn_is_management()
);

CREATE POLICY push_delivery_logs_service_role_all
ON public.push_notification_delivery_logs
FOR ALL
TO service_role
USING (true)
WITH CHECK (true);

-- =====================================================================
-- 13. TABLE AND VIEW PERMISSIONS
-- =====================================================================

REVOKE ALL
ON TABLE public.push_notification_delivery_logs
FROM PUBLIC, anon, authenticated;

GRANT SELECT
ON TABLE public.push_notification_delivery_logs
TO authenticated;

GRANT ALL
ON TABLE public.push_notification_delivery_logs
TO service_role;

REVOKE ALL
ON TABLE public.v_push_notification_delivery_summary
FROM PUBLIC, anon, authenticated;

GRANT SELECT
ON TABLE public.v_push_notification_delivery_summary
TO authenticated, service_role;

-- =====================================================================
-- 14. FUNCTION PERMISSIONS
-- =====================================================================

REVOKE ALL
ON FUNCTION public.fn_normalize_push_delivery_log()
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.fn_start_push_delivery_log(
    uuid,
    text,
    varchar,
    jsonb
)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.fn_complete_push_delivery_log(
    uuid,
    varchar,
    text,
    jsonb,
    integer,
    text,
    text,
    boolean
)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.fn_log_push_delivery_from_queue(
    uuid,
    text,
    varchar,
    varchar,
    jsonb,
    text,
    jsonb,
    integer,
    text,
    text,
    boolean
)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.fn_get_push_delivery_history(uuid)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.fn_get_push_delivery_statistics(
    timestamptz,
    timestamptz
)
FROM PUBLIC, anon, authenticated;

REVOKE ALL
ON FUNCTION public.fn_cleanup_push_delivery_logs(integer)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE
ON FUNCTION public.fn_start_push_delivery_log(
    uuid,
    text,
    varchar,
    jsonb
)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_complete_push_delivery_log(
    uuid,
    varchar,
    text,
    jsonb,
    integer,
    text,
    text,
    boolean
)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_log_push_delivery_from_queue(
    uuid,
    text,
    varchar,
    varchar,
    jsonb,
    text,
    jsonb,
    integer,
    text,
    text,
    boolean
)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_get_push_delivery_history(uuid)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_get_push_delivery_statistics(
    timestamptz,
    timestamptz
)
TO authenticated, service_role;

GRANT EXECUTE
ON FUNCTION public.fn_cleanup_push_delivery_logs(integer)
TO service_role;

-- =====================================================================
-- 15. SCHEMA VERSION REGISTRATION
-- =====================================================================

INSERT INTO public.schema_versions
(
    version_number,
    migration_name
)
VALUES
(
    56,
    '0056_push_notification_delivery_logs.sql'
)
ON CONFLICT (version_number)
DO UPDATE SET
    migration_name =
        EXCLUDED.migration_name,

    applied_at =
        now();

-- =====================================================================
-- 16. FINAL VALIDATION
-- =====================================================================

DO $$
DECLARE
    v_policy_count integer;
BEGIN
    IF to_regclass(
        'public.push_notification_delivery_logs'
    ) IS NULL THEN
        RAISE EXCEPTION
            'push_notification_delivery_logs table creation failed.';
    END IF;

    IF to_regclass(
        'public.v_push_notification_delivery_summary'
    ) IS NULL THEN
        RAISE EXCEPTION
            'v_push_notification_delivery_summary view creation failed.';
    END IF;

    IF to_regprocedure(
        'public.fn_normalize_push_delivery_log()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_normalize_push_delivery_log function creation failed.';
    END IF;

    IF to_regprocedure(
        'public.fn_start_push_delivery_log(uuid,text,character varying,jsonb)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_start_push_delivery_log function creation failed.';
    END IF;

    IF to_regprocedure(
        'public.fn_complete_push_delivery_log(uuid,character varying,text,jsonb,integer,text,text,boolean)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_complete_push_delivery_log function creation failed.';
    END IF;

    IF to_regprocedure(
        'public.fn_log_push_delivery_from_queue(uuid,text,character varying,character varying,jsonb,text,jsonb,integer,text,text,boolean)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_log_push_delivery_from_queue function creation failed.';
    END IF;

    IF to_regprocedure(
        'public.fn_get_push_delivery_history(uuid)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_get_push_delivery_history function creation failed.';
    END IF;

    IF to_regprocedure(
        'public.fn_get_push_delivery_statistics(timestamp with time zone,timestamp with time zone)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_get_push_delivery_statistics function creation failed.';
    END IF;

    IF to_regprocedure(
        'public.fn_cleanup_push_delivery_logs(integer)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_cleanup_push_delivery_logs function creation failed.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgname =
              'trg_normalize_push_delivery_log'
          AND tgrelid =
              'public.push_notification_delivery_logs'::regclass
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Push-delivery normalization trigger creation failed.';
    END IF;

    SELECT count(*)
    INTO v_policy_count
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename =
          'push_notification_delivery_logs';

    IF v_policy_count < 3 THEN
        RAISE EXCEPTION
            'Expected at least 3 RLS policies on push_notification_delivery_logs, found %.',
            v_policy_count;
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM public.schema_versions
        WHERE version_number = 56
          AND migration_name =
              '0056_push_notification_delivery_logs.sql'
    ) THEN
        RAISE EXCEPTION
            'Schema version 56 registration failed.';
    END IF;

    RAISE NOTICE
        '0056_push_notification_delivery_logs.sql completed successfully.';
END;
$$;

COMMIT;
