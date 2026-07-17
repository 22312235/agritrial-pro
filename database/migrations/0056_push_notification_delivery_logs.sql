BEGIN;

SET search_path = public, auth, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

CREATE TABLE IF NOT EXISTS public.push_notification_delivery_logs
(
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    queue_id uuid NOT NULL
        REFERENCES public.push_notification_queue(id)
        ON DELETE CASCADE,

    notification_id uuid NULL
        REFERENCES public.notifications(id)
        ON DELETE SET NULL,

    recipient_user_id uuid NOT NULL
        REFERENCES auth.users(id)
        ON DELETE CASCADE,

    device_id uuid NULL
        REFERENCES public.user_push_devices(id)
        ON DELETE SET NULL,

    attempt_number integer NOT NULL,

    worker_id text NULL,

    provider varchar(30) NOT NULL DEFAULT 'FCM',

    platform varchar(20) NOT NULL,

    delivery_status varchar(30) NOT NULL,

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
        ON DELETE SET NULL,

    CONSTRAINT push_delivery_logs_attempt_number_check
        CHECK (attempt_number >= 1),

    CONSTRAINT push_delivery_logs_worker_not_blank
        CHECK (
            worker_id IS NULL
            OR btrim(worker_id) <> ''
        ),

    CONSTRAINT push_delivery_logs_provider_check
        CHECK (
            provider IN (
                'FCM',
                'APNS',
                'WEB_PUSH',
                'OTHER'
            )
        ),

    CONSTRAINT push_delivery_logs_platform_check
        CHECK (
            platform IN (
                'ANDROID',
                'IOS',
                'WEB'
            )
        ),

    CONSTRAINT push_delivery_logs_status_check
        CHECK (
            delivery_status IN (
                'PROCESSING',
                'DELIVERED',
                'FAILED',
                'RETRY_SCHEDULED',
                'CANCELLED'
            )
        ),

    CONSTRAINT push_delivery_logs_request_payload_check
        CHECK (
            jsonb_typeof(request_payload) = 'object'
        ),

    CONSTRAINT push_delivery_logs_provider_response_check
        CHECK (
            provider_response IS NULL
            OR jsonb_typeof(provider_response) = 'object'
        ),

    CONSTRAINT push_delivery_logs_http_status_check
        CHECK (
            http_status_code IS NULL
            OR http_status_code BETWEEN 100 AND 599
        ),

    CONSTRAINT push_delivery_logs_latency_check
        CHECK (
            latency_ms IS NULL
            OR latency_ms >= 0
        ),

    CONSTRAINT push_delivery_logs_completed_time_check
        CHECK (
            completed_at IS NULL
            OR completed_at >= started_at
        ),

    CONSTRAINT push_delivery_logs_completed_status_check
        CHECK (
            delivery_status = 'PROCESSING'
            OR completed_at IS NOT NULL
        )
);

COMMENT ON TABLE public.push_notification_delivery_logs
IS 'Immutable audit history for every push notification delivery attempt.';

COMMENT ON COLUMN public.push_notification_delivery_logs.queue_id
IS 'Push notification queue item associated with this delivery attempt.';

COMMENT ON COLUMN public.push_notification_delivery_logs.attempt_number
IS 'Sequential delivery attempt number copied from the queue attempt count.';

COMMENT ON COLUMN public.push_notification_delivery_logs.worker_id
IS 'Identifier of the Edge Function, server worker, or background process that handled the attempt.';

COMMENT ON COLUMN public.push_notification_delivery_logs.provider
IS 'Push provider used for the delivery attempt.';

COMMENT ON COLUMN public.push_notification_delivery_logs.push_token_snapshot
IS 'Push token value used during this attempt, retained for auditing.';

COMMENT ON COLUMN public.push_notification_delivery_logs.request_payload
IS 'Payload submitted to the push notification provider.';

COMMENT ON COLUMN public.push_notification_delivery_logs.provider_response
IS 'Structured response returned by the push provider.';

COMMENT ON COLUMN public.push_notification_delivery_logs.latency_ms
IS 'Total provider request duration measured in milliseconds.';

CREATE UNIQUE INDEX IF NOT EXISTS uq_push_delivery_logs_queue_attempt
ON public.push_notification_delivery_logs
(
    queue_id,
    attempt_number
);

CREATE INDEX IF NOT EXISTS idx_push_delivery_logs_notification
ON public.push_notification_delivery_logs
(
    notification_id,
    created_at DESC
)
WHERE notification_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_push_delivery_logs_recipient
ON public.push_notification_delivery_logs
(
    recipient_user_id,
    created_at DESC
);

CREATE INDEX IF NOT EXISTS idx_push_delivery_logs_device
ON public.push_notification_delivery_logs
(
    device_id,
    created_at DESC
)
WHERE device_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_push_delivery_logs_status
ON public.push_notification_delivery_logs
(
    delivery_status,
    created_at DESC
);

CREATE INDEX IF NOT EXISTS idx_push_delivery_logs_provider
ON public.push_notification_delivery_logs
(
    provider,
    created_at DESC
);

CREATE INDEX IF NOT EXISTS idx_push_delivery_logs_error_code
ON public.push_notification_delivery_logs
(
    error_code,
    created_at DESC
)
WHERE error_code IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_push_delivery_logs_started_at
ON public.push_notification_delivery_logs(started_at DESC);

CREATE INDEX IF NOT EXISTS idx_push_delivery_logs_request_payload
ON public.push_notification_delivery_logs
USING gin(request_payload);

CREATE INDEX IF NOT EXISTS idx_push_delivery_logs_provider_response
ON public.push_notification_delivery_logs
USING gin(provider_response)
WHERE provider_response IS NOT NULL;

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
            btrim(NEW.platform)
        );

    NEW.delivery_status :=
        upper(
            btrim(NEW.delivery_status)
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

    NEW.created_by :=
        COALESCE(
            NEW.created_by,
            auth.uid()
        );

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

DROP TRIGGER IF EXISTS trg_normalize_push_delivery_log
ON public.push_notification_delivery_logs;

CREATE TRIGGER trg_normalize_push_delivery_log
BEFORE INSERT OR UPDATE
ON public.push_notification_delivery_logs
FOR EACH ROW
EXECUTE FUNCTION public.fn_normalize_push_delivery_log();

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
    v_queue public.push_notification_queue%ROWTYPE;
    v_log_id uuid;
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

    SELECT q.*
    INTO v_queue
    FROM public.push_notification_queue q
    WHERE q.id = p_queue_id
      AND q.is_active = true
      AND q.deleted_at IS NULL
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Active push queue item not found: %',
            p_queue_id;
    END IF;

    IF v_queue.delivery_status <> 'PROCESSING' THEN
        RAISE EXCEPTION
            'Push queue item % is not in PROCESSING status.',
            p_queue_id;
    END IF;

    IF v_queue.attempt_count < 1 THEN
        RAISE EXCEPTION
            'Push queue item % has an invalid attempt count.',
            p_queue_id;
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
        v_queue.id,
        v_queue.notification_id,
        v_queue.recipient_user_id,
        v_queue.device_id,
        v_queue.attempt_count,
        btrim(p_worker_id),
        upper(
            btrim(
                COALESCE(
                    p_provider,
                    'FCM'
                )
            )
        ),
        v_queue.platform,
        'PROCESSING',
        v_queue.push_token,
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
        worker_id = EXCLUDED.worker_id,
        provider = EXCLUDED.provider,
        platform = EXCLUDED.platform,
        delivery_status = 'PROCESSING',
        push_token_snapshot =
            EXCLUDED.push_token_snapshot,
        request_payload =
            EXCLUDED.request_payload,
        provider_message_id = NULL,
        provider_response = NULL,
        http_status_code = NULL,
        error_code = NULL,
        error_message = NULL,
        retryable = false,
        started_at = now(),
        completed_at = NULL,
        latency_ms = NULL
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
)
IS 'Creates or resets the audit log for the current push delivery attempt.';

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

    v_status :=
        upper(
            btrim(p_delivery_status)
        );

    IF v_status NOT IN
    (
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
        delivery_status = v_status,
        provider_message_id =
            NULLIF(
                btrim(p_provider_message_id),
                ''
            ),
        provider_response = p_provider_response,
        http_status_code = p_http_status_code,
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
        completed_at = now(),
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
)
IS 'Finalizes a push delivery log with provider response, timing, and error information.';

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
BEGIN
    v_log_id :=
        public.fn_start_push_delivery_log(
            p_queue_id,
            p_worker_id,
            p_provider,
            p_request_payload
        );

    PERFORM public.fn_complete_push_delivery_log(
        v_log_id,
        p_delivery_status,
        p_provider_message_id,
        p_provider_response,
        p_http_status_code,
        p_error_code,
        p_error_message,
        p_retryable
    );

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
)
IS 'Creates and immediately completes a delivery log for a processed push queue item.';
