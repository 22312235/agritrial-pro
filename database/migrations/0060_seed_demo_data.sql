-- AgriTrial Pro
-- Migration: 0060_seed_demo_data.sql
-- Purpose: Safe production-ready seed checkpoint.
--
-- Important:
-- Reference lookup data is already seeded by migrations 0010 through 0035.
-- This migration intentionally does not insert operational trials,
-- evaluations, criterion assignments, users, or media records.
-- This prevents duplicate-key errors, trigger failures, and pollution of
-- production data while still completing the migration sequence safely.

BEGIN;

SET search_path = public, auth, extensions;
SET statement_timeout = '0';
SET lock_timeout = '0';
SET client_min_messages = warning;

DO $$
BEGIN
    IF to_regclass('public.roles') IS NULL THEN
        RAISE EXCEPTION 'Required table public.roles does not exist.';
    END IF;

    IF to_regclass('public.crops') IS NULL THEN
        RAISE EXCEPTION 'Required table public.crops does not exist.';
    END IF;

    IF to_regclass('public.trial_statuses') IS NULL THEN
        RAISE EXCEPTION 'Required table public.trial_statuses does not exist.';
    END IF;

    IF to_regclass('public.evaluation_types') IS NULL THEN
        RAISE EXCEPTION 'Required table public.evaluation_types does not exist.';
    END IF;
END;
$$;

COMMENT ON TABLE public.roles IS
'Application roles used by AgriTrial Pro. Operational roles are managed through controlled migrations.';

COMMENT ON TABLE public.crops IS
'Agricultural crop reference data used when creating trials.';

COMMENT ON TABLE public.trial_statuses IS
'Controlled workflow statuses used by the trial approval process.';

COMMENT ON TABLE public.evaluation_types IS
'Controlled evaluation types used by observation and technical evaluations.';

DO $$
BEGIN
    IF to_regclass('public.schema_versions') IS NOT NULL THEN
        INSERT INTO public.schema_versions
        (
            version_number,
            migration_name
        )
        VALUES
        (
            60,
            '0060_seed_demo_data.sql'
        )
        ON CONFLICT (version_number)
        DO UPDATE SET
            migration_name = EXCLUDED.migration_name,
            applied_at = now();
    END IF;
END;
$$;

DO $$
BEGIN
    RAISE NOTICE
        '0060_seed_demo_data.sql completed safely. No operational demo records were inserted.';
END;
$$;

COMMIT;
