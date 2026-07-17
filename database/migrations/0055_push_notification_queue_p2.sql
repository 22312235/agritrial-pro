BEGIN;

SET search_path = public, auth, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

CREATE OR REPLACE FUNCTION public.fn_claim_push_queue_items(
    p_worker_id text,
    p_batch_size integer DEFAULT 50
)
RETURNS TABLE
(
    queue_id uuid,
    notification_id uuid,
    recipient_user_id uuid,
    device_id uuid,
    push_token text,
    platform varchar,
    title varchar,
    message text,
    data_payload jsonb,
    priority varchar,
    attempt_count integer,
    maximum_attempts integer
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
    IF p_worker_id IS NULL
       OR btrim(p_worker_id) = '' THEN
        RAISE EXCEPTION
            'Worker identifier is required.';
    END IF;

    IF p_batch_size IS NULL
       OR p_batch_size < 1
       OR p_batch_size > 500 THEN
        RAISE EXCEPTION
            'Batch size must be between 1 and 500.';
    END IF;

    RETURN QUERY
    WITH claimable AS
    (
        SELECT q.id
        FROM public.push_notification_queue q
        WHERE q.is_active = true
          AND q.deleted_at IS NULL
          AND q.attempt_count < q.maximum_attempts
          AND
          (
              (
                  q.delivery_status = 'PENDING'
                  AND q.scheduled_at <= now()
              )
              OR
              (
                  q.delivery_status = 'RETRY_SCHEDULED'
                  AND q.next_retry_at IS NOT NULL
                  AND q.next_retry_at <= now()
              )
          )
        ORDER BY
            CASE q.priority
                WHEN 'URGENT' THEN 1
                WHEN 'HIGH' THEN 2
                WHEN 'NORMAL' THEN 3
                WHEN 'LOW' THEN 4
                ELSE 5
            END,
            q.scheduled_at,
            q.created_at
        FOR UPDATE SKIP LOCKED
        LIMIT p_batch_size
    ),
    claimed AS
    (
        UPDATE public.push_notification_queue q
        SET
            delivery_status = 'PROCESSING',
            attempt_count = q.attempt_count + 1,
            locked_at = now(),
            locked_by = btrim(p_worker_id),
            processing_started_at = now(),
            next_retry_at = NULL,
            updated_at = now()
        FROM claimable c
        WHERE q.id = c.id
        RETURNING q.*
    )
    SELECT
        c.id,
        c.notification_id,
        c.recipient_user_id,
        c.device_id,
        c.push_token,
        c.platform,
        c.title,
        c.message,
        c.data_payload,
        c.priority,
        c.attempt_count,
        c.maximum_attempts
    FROM claimed c;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_complete_push_delivery(
    p_queue_id uuid,
    p_worker_id text,
    p_provider_message_id text DEFAULT NULL,
    p_provider_response jsonb DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
    IF p_worker_id IS NULL
       OR btrim(p_worker_id) = '' THEN
        RAISE EXCEPTION
            'Worker identifier is required.';
    END IF;

    IF p_provider_response IS NOT NULL
       AND jsonb_typeof(p_provider_response) <> 'object' THEN
        RAISE EXCEPTION
            'Provider response must be a JSON object.';
    END IF;

    UPDATE public.push_notification_queue
    SET
        delivery_status = 'DELIVERED',
        delivered_at = now(),
        failed_at = NULL,
        next_retry_at = NULL,
        provider_message_id =
            NULLIF(
                btrim(p_provider_message_id),
                ''
            ),
        provider_response = p_provider_response,
        error_code = NULL,
        error_message = NULL,
        locked_at = NULL,
        locked_by = NULL,
        updated_at = now()
    WHERE id = p_queue_id
      AND delivery_status = 'PROCESSING'
      AND locked_by = btrim(p_worker_id)
      AND is_active = true
      AND deleted_at IS NULL;

    RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_fail_push_delivery(
    p_queue_id uuid,
    p_worker_id text,
    p_error_code text,
    p_error_message text,
    p_provider_response jsonb DEFAULT NULL,
    p_retryable boolean DEFAULT true
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_attempt_count integer;
    v_maximum_attempts integer;
    v_push_token text;
    v_retry_minutes integer;
BEGIN
    IF p_worker_id IS NULL
       OR btrim(p_worker_id) = '' THEN
        RAISE EXCEPTION
            'Worker identifier is required.';
    END IF;

    IF p_error_message IS NULL
       OR btrim(p_error_message) = '' THEN
        RAISE EXCEPTION
            'Error message is required.';
    END IF;

    IF p_provider_response IS NOT NULL
       AND jsonb_typeof(p_provider_response) <> 'object' THEN
        RAISE EXCEPTION
            'Provider response must be a JSON object.';
    END IF;

    SELECT
        q.attempt_count,
        q.maximum_attempts,
        q.push_token
    INTO
        v_attempt_count,
        v_maximum_attempts,
        v_push_token
    FROM public.push_notification_queue q
    WHERE q.id = p_queue_id
      AND q.delivery_status = 'PROCESSING'
      AND q.locked_by = btrim(p_worker_id)
      AND q.is_active = true
      AND q.deleted_at IS NULL
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    v_retry_minutes :=
        LEAST(
            1440,
            GREATEST(
                1,
                power(
                    2,
                    LEAST(
                        v_attempt_count,
                        10
                    )
                )::integer
            )
        );

    IF p_retryable = true
       AND v_attempt_count < v_maximum_attempts THEN

        UPDATE public.push_notification_queue
        SET
            delivery_status = 'RETRY_SCHEDULED',
            failed_at = NULL,
            next_retry_at =
                now() + make_interval(
                    mins => v_retry_minutes
                ),
            provider_response = p_provider_response,
            error_code =
                NULLIF(
                    btrim(p_error_code),
                    ''
                ),
            error_message = btrim(p_error_message),
            locked_at = NULL,
            locked_by = NULL,
            updated_at = now()
        WHERE id = p_queue_id;

    ELSE

        UPDATE public.push_notification_queue
        SET
            delivery_status = 'FAILED',
            failed_at = now(),
            next_retry_at = NULL,
            provider_response = p_provider_response,
            error_code =
                NULLIF(
                    btrim(p_error_code),
                    ''
                ),
            error_message = btrim(p_error_message),
            locked_at = NULL,
            locked_by = NULL,
            updated_at = now()
        WHERE id = p_queue_id;

    END IF;

    IF upper(
        COALESCE(
            btrim(p_error_code),
            ''
        )
    ) IN
    (
        'UNREGISTERED',
        'INVALID_ARGUMENT',
        'INVALID_REGISTRATION',
        'NOT_REGISTERED',
        'MESSAGING_REGISTRATION_TOKEN_NOT_REGISTERED'
    ) THEN
        PERFORM public.fn_deactivate_invalid_push_token(
            v_push_token,
            btrim(p_error_message)
        );
    END IF;

    RETURN true;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_cancel_push_delivery(
    p_queue_id uuid,
    p_reason text DEFAULT NULL
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
    UPDATE public.push_notification_queue
    SET
        delivery_status = 'CANCELLED',
        error_message =
            COALESCE(
                NULLIF(
                    btrim(p_reason),
                    ''
                ),
                'Delivery cancelled.'
            ),
        next_retry_at = NULL,
        locked_at = NULL,
        locked_by = NULL,
        is_active = false,
        deleted_at = now(),
        updated_at = now(),
        updated_by = auth.uid()
    WHERE id = p_queue_id
      AND delivery_status IN
      (
          'PENDING',
          'PROCESSING',
          'RETRY_SCHEDULED'
      )
      AND deleted_at IS NULL;

    RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_release_stale_push_locks(
    p_lock_timeout_minutes integer DEFAULT 15
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
    v_updated_count integer;
BEGIN
    IF p_lock_timeout_minutes IS NULL
       OR p_lock_timeout_minutes < 1
       OR p_lock_timeout_minutes > 1440 THEN
        RAISE EXCEPTION
            'Lock timeout must be between 1 and 1440 minutes.';
    END IF;

    UPDATE public.push_notification_queue
    SET
        delivery_status =
            CASE
                WHEN attempt_count < maximum_attempts
                    THEN 'RETRY_SCHEDULED'
                ELSE 'FAILED'
            END,
        failed_at =
            CASE
                WHEN attempt_count >= maximum_attempts
                    THEN now()
                ELSE NULL
            END,
        next_retry_at =
            CASE
                WHEN attempt_count < maximum_attempts
                    THEN now()
                ELSE NULL
            END,
        error_code = 'STALE_WORKER_LOCK',
        error_message =
            'Processing lock expired before delivery completed.',
        locked_at = NULL,
        locked_by = NULL,
        updated_at = now()
    WHERE delivery_status = 'PROCESSING'
      AND locked_at IS NOT NULL
      AND locked_at <
          now() - make_interval(
              mins => p_lock_timeout_minutes
          )
      AND is_active = true
      AND deleted_at IS NULL;

    GET DIAGNOSTICS
        v_updated_count = ROW_COUNT;

    RETURN v_updated_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_retry_failed_push_delivery(
    p_queue_id uuid
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
    UPDATE public.push_notification_queue
    SET
        delivery_status = 'RETRY_SCHEDULED',
        next_retry_at = now(),
        failed_at = NULL,
        delivered_at = NULL,
        provider_message_id = NULL,
        provider_response = NULL,
        error_code = NULL,
        error_message = NULL,
        locked_at = NULL,
        locked_by = NULL,
        is_active = true,
        deleted_at = NULL,
        updated_at = now(),
        updated_by = auth.uid()
    WHERE id = p_queue_id
      AND delivery_status = 'FAILED'
      AND attempt_count < maximum_attempts;

    RETURN FOUND;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_cleanup_push_queue(
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
       OR p_retention_days < 7 THEN
        RAISE EXCEPTION
            'Push queue retention must be at least 7 days.';
    END IF;

    DELETE FROM public.push_notification_queue
    WHERE delivery_status IN
    (
        'DELIVERED',
        'FAILED',
        'CANCELLED'
    )
      AND updated_at <
          now() - make_interval(
              days => p_retention_days
          );

    GET DIAGNOSTICS
        v_deleted_count = ROW_COUNT;

    RETURN v_deleted_count;
END;
$$;

CREATE OR REPLACE FUNCTION public.fn_push_queue_statistics()
RETURNS TABLE
(
    delivery_status varchar,
    total_count bigint,
    oldest_created_at timestamptz,
    newest_created_at timestamptz
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
    SELECT
        q.delivery_status,
        count(*)::bigint,
        min(q.created_at),
        max(q.created_at)
    FROM public.push_notification_queue q
    WHERE q.deleted_at IS NULL
    GROUP BY q.delivery_status
    ORDER BY q.delivery_status;
$$;

ALTER TABLE public.push_notification_queue
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.push_notification_queue
FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS push_notification_queue_select_own
ON public.push_notification_queue;

DROP POLICY IF EXISTS push_notification_queue_management_select
ON public.push_notification_queue;

CREATE POLICY push_notification_queue_select_own
ON public.push_notification_queue
FOR SELECT
TO authenticated
USING
(
    recipient_user_id = auth.uid()
);

CREATE POLICY push_notification_queue_management_select
ON public.push_notification_queue
FOR SELECT
TO authenticated
USING
(
    public.fn_is_management()
);

REVOKE ALL
ON TABLE public.push_notification_queue
FROM PUBLIC, anon, authenticated;

GRANT SELECT
ON TABLE public.push_notification_queue
TO authenticated;

GRANT ALL
ON TABLE public.push_notification_queue
TO service_role;

REVOKE ALL
ON FUNCTION public.fn_push_queue_normalize()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_enqueue_notification_push(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_auto_enqueue_notification_push()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_claim_push_queue_items(text, integer)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_complete_push_delivery(
    uuid,
    text,
    text,
    jsonb
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_fail_push_delivery(
    uuid,
    text,
    text,
    text,
    jsonb,
    boolean
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_cancel_push_delivery(
    uuid,
    text
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_release_stale_push_locks(integer)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_retry_failed_push_delivery(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_cleanup_push_queue(integer)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_push_queue_statistics()
FROM PUBLIC;

GRANT EXECUTE
ON FUNCTION public.fn_enqueue_notification_push(uuid)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_claim_push_queue_items(
    text,
    integer
)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_complete_push_delivery(
    uuid,
    text,
    text,
    jsonb
)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_fail_push_delivery(
    uuid,
    text,
    text,
    text,
    jsonb,
    boolean
)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_cancel_push_delivery(
    uuid,
    text
)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_release_stale_push_locks(integer)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_retry_failed_push_delivery(uuid)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_cleanup_push_queue(integer)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_push_queue_statistics()
TO service_role;

INSERT INTO public.schema_versions
(
    version_number,
    migration_name
)
VALUES
(
    55,
    '0055_push_notification_queue.sql'
)
ON CONFLICT (version_number)
DO UPDATE SET
    migration_name = EXCLUDED.migration_name,
    applied_at = now();

DO $$
BEGIN
    IF to_regprocedure(
        'public.fn_claim_push_queue_items(text,integer)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_claim_push_queue_items function creation failed.';
    END IF;

    IF to_regprocedure(
        'public.fn_complete_push_delivery(uuid,text,text,jsonb)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_complete_push_delivery function creation failed.';
    END IF;

    IF to_regprocedure(
        'public.fn_fail_push_delivery(uuid,text,text,text,jsonb,boolean)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_fail_push_delivery function creation failed.';
    END IF;

    IF to_regprocedure(
        'public.fn_release_stale_push_locks(integer)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_release_stale_push_locks function creation failed.';
    END IF;

    IF to_regprocedure(
        'public.fn_cleanup_push_queue(integer)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'fn_cleanup_push_queue function creation failed.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM public.schema_versions
        WHERE version_number = 55
    ) THEN
        RAISE EXCEPTION
            'Schema version 55 registration failed.';
    END IF;

    RAISE NOTICE
        '0055_push_notification_queue.sql completed successfully.';
END;
$$;

COMMIT;
