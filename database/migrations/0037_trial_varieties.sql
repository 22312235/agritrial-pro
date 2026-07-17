/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0037_trial_varieties.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the trial_varieties table.
*
* This table stores every candidate or comparison variety represented inside
* one agricultural trial installation.
*
* Frozen business rules:
*
*   • One Installation = One Trial.
*   • A trial may contain one or more varieties.
*   • The principal variety entered during installation is the primary variety.
*   • Exactly one active primary candidate variety may exist per trial.
*   • Additional candidate varieties may be attached to the same trial.
*   • Witness varieties may be configured or entered manually.
*   • The trials.number_of_varieties field is synchronized automatically.
*   • Historical variety records use soft deletion.
*
* Variety roles:
*
*   • CANDIDATE
*   • WITNESS
*
* The trials.variety_name field remains the primary installation identity used
* to generate the immutable trial business identifier.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0018_crops.sql
*   • 0022_witness_varieties.sql
*   • 0036_trials.sql
*
***************************************************************************************************/

BEGIN;

--------------------------------------------------------------------------------
-- Session Configuration
--------------------------------------------------------------------------------

SET LOCAL search_path = public;

SET LOCAL statement_timeout = '5min';

SET LOCAL lock_timeout = '30s';

SET LOCAL idle_in_transaction_session_timeout = '5min';

--------------------------------------------------------------------------------
-- TABLE: trial_varieties
--------------------------------------------------------------------------------

CREATE TABLE public.trial_varieties
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                          uuid
                                PRIMARY KEY
                                DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Parent Trial
    --------------------------------------------------------------------------

    trial_id                    uuid
                                NOT NULL,

    --------------------------------------------------------------------------
    -- Variety Classification
    --------------------------------------------------------------------------

    variety_role                varchar(20)
                                NOT NULL
                                DEFAULT 'CANDIDATE',

    variety_name                varchar(200)
                                NOT NULL,

    witness_variety_id          uuid,

    --------------------------------------------------------------------------
    -- Variety Behavior
    --------------------------------------------------------------------------

    is_primary                  boolean
                                NOT NULL
                                DEFAULT false,

    is_leader                   boolean
                                NOT NULL
                                DEFAULT false,

    --------------------------------------------------------------------------
    -- Optional Agronomic Information
    --------------------------------------------------------------------------

    seed_lot_number             varchar(150),

    supplier_name               varchar(200),

    notes                       text,

    --------------------------------------------------------------------------
    -- Display and State
    --------------------------------------------------------------------------

    display_order               integer
                                NOT NULL
                                DEFAULT 0,

    is_active                   boolean
                                NOT NULL
                                DEFAULT true,

    --------------------------------------------------------------------------
    -- Audit and Soft-Delete Columns
    --------------------------------------------------------------------------

    created_at                  timestamptz
                                NOT NULL
                                DEFAULT timezone('UTC', now()),

    updated_at                  timestamptz
                                NOT NULL
                                DEFAULT timezone('UTC', now()),

    created_by                  uuid,

    updated_by                  uuid,

    deleted_at                  timestamptz,

    --------------------------------------------------------------------------
    -- Foreign Keys
    --------------------------------------------------------------------------

    CONSTRAINT fk_trial_varieties_trial
        FOREIGN KEY (trial_id)
        REFERENCES public.trials(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trial_varieties_witness_variety
        FOREIGN KEY (witness_variety_id)
        REFERENCES public.witness_varieties(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trial_varieties_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_trial_varieties_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_trial_varieties_role
        CHECK
        (
            variety_role IN
            (
                'CANDIDATE',
                'WITNESS'
            )
        ),

    CONSTRAINT chk_trial_varieties_name
        CHECK
        (
            char_length(btrim(variety_name)) BETWEEN 1 AND 200
        ),

    CONSTRAINT chk_trial_varieties_primary_candidate
        CHECK
        (
            is_primary = false
            OR variety_role = 'CANDIDATE'
        ),

    CONSTRAINT chk_trial_varieties_witness_reference
        CHECK
        (
            witness_variety_id IS NULL
            OR variety_role = 'WITNESS'
        ),

    CONSTRAINT chk_trial_varieties_candidate_reference
        CHECK
        (
            variety_role <> 'CANDIDATE'
            OR witness_variety_id IS NULL
        ),

    CONSTRAINT chk_trial_varieties_seed_lot_number
        CHECK
        (
            seed_lot_number IS NULL
            OR
            (
                length(btrim(seed_lot_number)) > 0
                AND char_length(btrim(seed_lot_number)) <= 150
            )
        ),

    CONSTRAINT chk_trial_varieties_supplier_name
        CHECK
        (
            supplier_name IS NULL
            OR
            (
                length(btrim(supplier_name)) > 0
                AND char_length(btrim(supplier_name)) <= 200
            )
        ),

    CONSTRAINT chk_trial_varieties_notes
        CHECK
        (
            notes IS NULL
            OR
            (
                length(btrim(notes)) > 0
                AND char_length(btrim(notes)) <= 5000
            )
        ),

    CONSTRAINT chk_trial_varieties_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_trial_varieties_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_trial_varieties_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.trial_varieties IS
'Candidate and witness varieties represented within one agricultural trial installation.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.trial_varieties.id IS
'Internal UUID primary key of the trial-variety record.';

COMMENT ON COLUMN public.trial_varieties.trial_id IS
'Parent agricultural trial containing the variety.';

COMMENT ON COLUMN public.trial_varieties.variety_role IS
'Variety role within the trial. Allowed values are CANDIDATE and WITNESS.';

COMMENT ON COLUMN public.trial_varieties.variety_name IS
'Candidate or witness variety name displayed in evaluations, dashboards, and reports.';

COMMENT ON COLUMN public.trial_varieties.witness_variety_id IS
'Optional configured witness-variety reference. Only valid when variety_role is WITNESS.';

COMMENT ON COLUMN public.trial_varieties.is_primary IS
'Indicates the principal candidate variety used as the trial installation identity.';

COMMENT ON COLUMN public.trial_varieties.is_leader IS
'Indicates that the variety is currently identified as a leading variety for the trial.';

COMMENT ON COLUMN public.trial_varieties.seed_lot_number IS
'Optional seed or plant-material lot identifier.';

COMMENT ON COLUMN public.trial_varieties.supplier_name IS
'Optional supplier, breeder, or seed-company name.';

COMMENT ON COLUMN public.trial_varieties.notes IS
'Optional agronomic or administrative notes about the variety.';

COMMENT ON COLUMN public.trial_varieties.display_order IS
'Controls variety ordering in Flutter forms, evaluations, dashboards, and reports.';

COMMENT ON COLUMN public.trial_varieties.is_active IS
'Indicates whether the variety remains active inside the trial.';

COMMENT ON COLUMN public.trial_varieties.created_at IS
'UTC timestamp when the trial-variety record was created.';

COMMENT ON COLUMN public.trial_varieties.updated_at IS
'UTC timestamp when the trial-variety record was most recently updated.';

COMMENT ON COLUMN public.trial_varieties.created_by IS
'Supabase Auth user who created the trial-variety record.';

COMMENT ON COLUMN public.trial_varieties.updated_by IS
'Supabase Auth user who most recently updated the trial-variety record.';

COMMENT ON COLUMN public.trial_varieties.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the variety has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_trial_varieties_trial_name_role
    ON public.trial_varieties
    (
        trial_id,
        variety_role,
        public.fn_normalize_text(variety_name)
    );

--------------------------------------------------------------------------------
-- EXACTLY ONE PRIMARY CANDIDATE PER TRIAL
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_trial_varieties_one_primary_candidate
    ON public.trial_varieties (trial_id)
    WHERE is_primary = true
      AND variety_role = 'CANDIDATE'
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- PREVENT DUPLICATE CONFIGURED WITNESS VARIETIES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_trial_varieties_witness_reference
    ON public.trial_varieties
    (
        trial_id,
        witness_variety_id
    )
    WHERE witness_variety_id IS NOT NULL
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- RELATIONSHIP AND FILTERING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_trial_varieties_trial_id
    ON public.trial_varieties (trial_id);

CREATE INDEX idx_trial_varieties_witness_variety_id
    ON public.trial_varieties (witness_variety_id)
    WHERE witness_variety_id IS NOT NULL;

CREATE INDEX idx_trial_varieties_trial_active
    ON public.trial_varieties
    (
        trial_id,
        variety_role,
        display_order,
        variety_name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_trial_varieties_candidates
    ON public.trial_varieties
    (
        trial_id,
        is_primary,
        display_order
    )
    WHERE variety_role = 'CANDIDATE'
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_trial_varieties_witnesses
    ON public.trial_varieties
    (
        trial_id,
        display_order
    )
    WHERE variety_role = 'WITNESS'
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_trial_varieties_leaders
    ON public.trial_varieties
    (
        trial_id,
        is_leader
    )
    WHERE is_leader = true
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_trial_varieties_deleted_at
    ON public.trial_varieties (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_trial_varieties_name_trgm
    ON public.trial_varieties
    USING gin
    (
        variety_name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_trial_varieties_created_by
    ON public.trial_varieties (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_trial_varieties_updated_by
    ON public.trial_varieties (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------
-- Validates:
--
--   • Parent trial exists and is not soft-deleted.
--   • Witness variety exists and is compatible with the trial crop.
--   • Candidate records cannot reference witness-variety master data.
--   • Primary records must be candidate varieties.
--   • Primary variety name must match trials.variety_name.
--   • Optional text values are normalized.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_trial_variety()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_trial_crop_id             uuid;
    v_trial_variety_name        text;
    v_trial_deleted_at          timestamptz;

    v_witness_crop_id           uuid;
    v_witness_name              text;
    v_witness_active            boolean;
    v_witness_deleted_at        timestamptz;
BEGIN
    --------------------------------------------------------------------------
    -- Normalize input
    --------------------------------------------------------------------------

    NEW.variety_role := upper(btrim(NEW.variety_role));

    NEW.variety_name := NULLIF(btrim(NEW.variety_name), '');

    NEW.seed_lot_number :=
        CASE
            WHEN NEW.seed_lot_number IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.seed_lot_number), '')
        END;

    NEW.supplier_name :=
        CASE
            WHEN NEW.supplier_name IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.supplier_name), '')
        END;

    NEW.notes :=
        CASE
            WHEN NEW.notes IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.notes), '')
        END;

    IF NEW.variety_name IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial variety validation failed: variety name is required.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate parent trial
    --------------------------------------------------------------------------

    SELECT
        t.crop_id,
        t.variety_name,
        t.deleted_at
    INTO
        v_trial_crop_id,
        v_trial_variety_name,
        v_trial_deleted_at
    FROM public.trials t
    WHERE t.id = NEW.trial_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Trial variety validation failed: trial %s does not exist.',
                    NEW.trial_id
                );
    END IF;

    IF v_trial_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial variety validation failed: varieties cannot be attached to a soft-deleted trial.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate candidate variety
    --------------------------------------------------------------------------

    IF NEW.variety_role = 'CANDIDATE' THEN
        IF NEW.witness_variety_id IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial variety validation failed: a candidate variety cannot reference witness-variety master data.';
        END IF;

        IF NEW.is_primary = true
           AND public.fn_normalize_text(NEW.variety_name)
               IS DISTINCT FROM
               public.fn_normalize_text(v_trial_variety_name) THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial variety validation failed: the primary candidate name must match trials.variety_name.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate witness variety
    --------------------------------------------------------------------------

    IF NEW.witness_variety_id IS NOT NULL THEN
        SELECT
            wv.crop_id,
            wv.name,
            wv.is_active,
            wv.deleted_at
        INTO
            v_witness_crop_id,
            v_witness_name,
            v_witness_active,
            v_witness_deleted_at
        FROM public.witness_varieties wv
        WHERE wv.id = NEW.witness_variety_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE =
                        'Trial variety validation failed: the selected witness variety does not exist.';
        END IF;

        IF v_witness_deleted_at IS NOT NULL
           OR v_witness_active = false THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial variety validation failed: the selected witness variety is unavailable.';
        END IF;

        IF v_witness_crop_id IS DISTINCT FROM v_trial_crop_id THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial variety validation failed: the witness variety does not belong to the trial crop.';
        END IF;

        NEW.variety_name := v_witness_name;
    END IF;

    --------------------------------------------------------------------------
    -- Witness varieties cannot be primary
    --------------------------------------------------------------------------

    IF NEW.variety_role = 'WITNESS'
       AND NEW.is_primary = true THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial variety validation failed: a witness variety cannot be the primary trial variety.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_trial_variety() IS
'Validates trial membership, candidate and witness roles, crop compatibility, primary-variety identity, and optional text normalization.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_varieties_validate
    BEFORE INSERT OR UPDATE OF
        trial_id,
        variety_role,
        variety_name,
        witness_variety_id,
        is_primary,
        seed_lot_number,
        supplier_name,
        notes,
        is_active,
        deleted_at
    ON public.trial_varieties
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_trial_variety();

--------------------------------------------------------------------------------
-- SYNCHRONIZATION FUNCTION
--------------------------------------------------------------------------------
-- Synchronizes trials.number_of_varieties with the number of active,
-- non-deleted candidate varieties.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_sync_trial_variety_count()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_old_trial_id      uuid;
    v_new_trial_id      uuid;
    v_candidate_count   integer;
BEGIN
    v_old_trial_id :=
        CASE
            WHEN TG_OP IN ('UPDATE', 'DELETE') THEN OLD.trial_id
            ELSE NULL
        END;

    v_new_trial_id :=
        CASE
            WHEN TG_OP IN ('INSERT', 'UPDATE') THEN NEW.trial_id
            ELSE NULL
        END;

    --------------------------------------------------------------------------
    -- Synchronize the previous parent after movement or deletion
    --------------------------------------------------------------------------

    IF v_old_trial_id IS NOT NULL THEN
        SELECT count(*)
        INTO v_candidate_count
        FROM public.trial_varieties tv
        WHERE tv.trial_id = v_old_trial_id
          AND tv.variety_role = 'CANDIDATE'
          AND tv.is_active = true
          AND tv.deleted_at IS NULL;

        UPDATE public.trials
        SET number_of_varieties = GREATEST(v_candidate_count, 1)
        WHERE id = v_old_trial_id;
    END IF;

    --------------------------------------------------------------------------
    -- Synchronize the current parent after insertion or update
    --------------------------------------------------------------------------

    IF v_new_trial_id IS NOT NULL
       AND v_new_trial_id IS DISTINCT FROM v_old_trial_id THEN
        SELECT count(*)
        INTO v_candidate_count
        FROM public.trial_varieties tv
        WHERE tv.trial_id = v_new_trial_id
          AND tv.variety_role = 'CANDIDATE'
          AND tv.is_active = true
          AND tv.deleted_at IS NULL;

        UPDATE public.trials
        SET number_of_varieties = GREATEST(v_candidate_count, 1)
        WHERE id = v_new_trial_id;

    ELSIF v_new_trial_id IS NOT NULL
          AND TG_OP <> 'DELETE' THEN
        SELECT count(*)
        INTO v_candidate_count
        FROM public.trial_varieties tv
        WHERE tv.trial_id = v_new_trial_id
          AND tv.variety_role = 'CANDIDATE'
          AND tv.is_active = true
          AND tv.deleted_at IS NULL;

        UPDATE public.trials
        SET number_of_varieties = GREATEST(v_candidate_count, 1)
        WHERE id = v_new_trial_id;
    END IF;

    RETURN NULL;
END;
$$;

COMMENT ON FUNCTION public.trg_sync_trial_variety_count() IS
'Synchronizes trials.number_of_varieties with active, non-deleted candidate-variety records.';

--------------------------------------------------------------------------------
-- SYNCHRONIZATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_varieties_sync_count
    AFTER INSERT OR UPDATE OR DELETE
    ON public.trial_varieties
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_sync_trial_variety_count();

--------------------------------------------------------------------------------
-- PRIMARY VARIETY PROTECTION FUNCTION
--------------------------------------------------------------------------------
-- Prevents removal, deactivation, or role conversion of the primary candidate
-- when other trial-variety records still reference the same trial.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_protect_primary_trial_variety()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    IF TG_OP = 'DELETE'
       AND OLD.is_primary = true
       AND OLD.deleted_at IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Primary trial variety protection failed: the primary candidate cannot be physically deleted. Use trial soft deletion instead.';
    END IF;

    IF TG_OP = 'UPDATE'
       AND OLD.is_primary = true
       AND OLD.deleted_at IS NULL
       AND
       (
           NEW.is_primary = false
           OR NEW.variety_role <> 'CANDIDATE'
           OR NEW.is_active = false
           OR NEW.deleted_at IS NOT NULL
       ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Primary trial variety protection failed: the primary candidate cannot be demoted, deactivated, or soft-deleted.';
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$;

COMMENT ON FUNCTION public.trg_protect_primary_trial_variety() IS
'Prevents physical deletion, demotion, deactivation, or soft deletion of the primary candidate variety.';

--------------------------------------------------------------------------------
-- PRIMARY VARIETY PROTECTION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_varieties_protect_primary
    BEFORE UPDATE OR DELETE
    ON public.trial_varieties
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_protect_primary_trial_variety();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_varieties_timestamps
    BEFORE INSERT OR UPDATE
    ON public.trial_varieties
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_trial_varieties_created_by
    BEFORE INSERT
    ON public.trial_varieties
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_trial_varieties_updated_by
    BEFORE UPDATE
    ON public.trial_varieties
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- AUTOMATIC PRIMARY VARIETY CREATION
--------------------------------------------------------------------------------
-- Every newly created trial automatically receives one primary candidate
-- variety based on trials.variety_name.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_create_primary_trial_variety()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    INSERT INTO public.trial_varieties
    (
        trial_id,
        variety_role,
        variety_name,
        is_primary,
        is_leader,
        display_order,
        is_active,
        created_by,
        updated_by
    )
    VALUES
    (
        NEW.id,
        'CANDIDATE',
        NEW.variety_name,
        true,
        false,
        10,
        true,
        NEW.created_by,
        NEW.created_by
    );

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_create_primary_trial_variety() IS
'Creates the primary candidate trial_varieties record immediately after a trial installation is created.';

--------------------------------------------------------------------------------
-- AUTOMATIC PRIMARY VARIETY CREATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trials_create_primary_variety
    AFTER INSERT
    ON public.trials
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_create_primary_trial_variety();

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    expected_column_count integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.trial_varieties') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: public.trial_varieties was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'trial_varieties'
      AND column_name IN
      (
          'id',
          'trial_id',
          'variety_role',
          'variety_name',
          'witness_variety_id',
          'is_primary',
          'is_leader',
          'seed_lot_number',
          'supplier_name',
          'notes',
          'display_order',
          'is_active',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF expected_column_count <> 17 THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: trial_varieties has % of 17 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_varieties'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_varieties'::regclass
          AND conname = 'fk_trial_varieties_trial'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: trial foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_varieties'::regclass
          AND conname = 'fk_trial_varieties_witness_variety'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: witness-variety foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass(
        'public.uq_trial_varieties_trial_name_role'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: trial/name/role unique index is missing.';
    END IF;

    IF to_regclass(
        'public.uq_trial_varieties_one_primary_candidate'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: one-primary-candidate index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify validation function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.trg_validate_trial_variety()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_varieties'::regclass
          AND tgname = 'trg_trial_varieties_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify synchronization function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.trg_sync_trial_variety_count()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: variety-count synchronization function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_varieties'::regclass
          AND tgname = 'trg_trial_varieties_sync_count'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: variety-count synchronization trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary-variety creation function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.trg_create_primary_trial_variety()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: primary-variety creation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trials'::regclass
          AND tgname = 'trg_trials_create_primary_variety'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: primary-variety creation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_varieties'::regclass
          AND tgname = 'trg_trial_varieties_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_varieties'::regclass
          AND tgname = 'trg_trial_varieties_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_varieties'::regclass
          AND tgname = 'trg_trial_varieties_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0037_trial_varieties.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
