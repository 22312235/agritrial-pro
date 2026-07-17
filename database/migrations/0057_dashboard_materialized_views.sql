CREATE OR REPLACE FUNCTION public.fn_get_push_delivery_history(
    p_queue_id uuid
)
RETURNS TABLE
(
    log_id uuid,
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

COMMENT ON FUNCTION public.fn_get_push_delivery_history(uuid)
IS 'Returns the complete push delivery attempt history for one queue item.';

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
        count(*)::bigint,
        round(
            avg(l.latency_ms)::numeric,
            2
        ),
        min(l.latency_ms),
        max(l.latency_ms),
        count(*) FILTER (
            WHERE l.retryable = true
        )::bigint
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
)
IS 'Returns aggregated push delivery metrics for a specified date range.';

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
            'Delivery log retention must be at least 30 days.';
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

COMMENT ON FUNCTION public.fn_cleanup_push_delivery_logs(integer)
IS 'Deletes push delivery audit logs older than the configured retention period.';

CREATE OR REPLACE VIEW public.v_push_notification_delivery_summary
WITH (security_invoker = true)
AS
SELECT
    q.id AS queue_id,
    q.notification_id,
    q.recipient_user_id,
    q.device_id,
    q.platform,
    q.priority,
    q.delivery_status AS queue_status,
    q.attempt_count,
    q.maximum_attempts,
    q.scheduled_at,
    q.delivered_at,
    q.failed_at,
    q.error_code AS latest_queue_error_code,
    q.error_message AS latest_queue_error_message,
    count(l.id)::bigint AS logged_attempts,
    count(l.id) FILTER (
        WHERE l.delivery_status = 'DELIVERED'
    )::bigint AS successful_attempts,
    count(l.id) FILTER (
        WHERE l.delivery_status IN (
            'FAILED',
            'RETRY_SCHEDULED'
        )
    )::bigint AS failed_attempts,
    round(
        avg(l.latency_ms)::numeric,
        2
    ) AS average_latency_ms,
    max(l.completed_at) AS last_attempt_completed_at
FROM public.push_notification_queue q
LEFT JOIN public.push_notification_delivery_logs l
    ON l.queue_id = q.id
WHERE q.deleted_at IS NULL
GROUP BY
    q.id,
    q.notification_id,
    q.recipient_user_id,
    q.device_id,
    q.platform,
    q.priority,
    q.delivery_status,
    q.attempt_count,
    q.maximum_attempts,
    q.scheduled_at,
    q.delivered_at,
    q.failed_at,
    q.error_code,
    q.error_message;

COMMENT ON VIEW public.v_push_notification_delivery_summary
IS 'Summary of push queue items and their recorded delivery attempts.';

ALTER TABLE public.push_notification_delivery_logs
ENABLE ROW LEVEL SECURITY;

ALTER TABLE public.push_notification_delivery_logs
FORCE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS push_delivery_logs_select_own
ON public.push_notification_delivery_logs;

DROP POLICY IF EXISTS push_delivery_logs_management_select
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
ON public.v_push_notification_delivery_summary
FROM PUBLIC, anon, authenticated;

GRANT SELECT
ON public.v_push_notification_delivery_summary
TO authenticated, service_role;

REVOKE ALL
ON FUNCTION public.fn_normalize_push_delivery_log()
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_start_push_delivery_log(
    uuid,
    text,
    varchar,
    jsonb
)
FROM PUBLIC;

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
FROM PUBLIC;

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
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_get_push_delivery_history(uuid)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_get_push_delivery_statistics(
    timestamptz,
    timestamptz
)
FROM PUBLIC;

REVOKE ALL
ON FUNCTION public.fn_cleanup_push_delivery_logs(integer)
FROM PUBLIC;

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
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_get_push_delivery_statistics(
    timestamptz,
    timestamptz
)
TO service_role;

GRANT EXECUTE
ON FUNCTION public.fn_cleanup_push_delivery_logs(integer)
TO service_role;

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
    migration_name = EXCLUDED.migration_name,
    applied_at = now();

DO $$
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

    IF NOT EXISTS
    (
        SELECT 1
        FROM public.schema_versions
        WHERE version_number = 56
    ) THEN
        RAISE EXCEPTION
            'Schema version 56 registration failed.';
    END IF;

    RAISE NOTICE
        '0056_push_notification_delivery_logs.sql completed successfully.';
END;
$$;

COMMIT;
