/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0031_evaluation_types.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the evaluation_types configuration table.
*
* AgriTrial Pro uses one dynamic evaluation engine for both:
*
*   • OBSERVATION
*   • TECHNICAL_EVALUATION
*
* The evaluation type determines which dynamic criteria and options Flutter
* loads through criterion_assignments.
*
* Frozen architectural rules:
*
*   • Observations and technical evaluations use the same evaluations table.
*   • No separate observation or technical-evaluation tables may be created.
*   • Observation evaluations may occur multiple times for the same trial.
*   • A technical evaluation is required before a trial may be completed.
*   • Evaluation types are system-controlled workflow values.
*   • Evaluation type codes must not be renamed or deleted.
*   • Row Level Security policies are intentionally deferred.
*
* Important exception to the general "Other" rule:
*
*   • Evaluation type is a strict system workflow classification.
*   • An Other evaluation type is intentionally prohibited because only the
*     two frozen evaluation types are supported by the workflow.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
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
-- TABLE: evaluation_types
--------------------------------------------------------------------------------

CREATE TABLE public.evaluation_types
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                          uuid
                                PRIMARY KEY
                                DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Evaluation Type Information
    --------------------------------------------------------------------------

    code                        long_code
                                NOT NULL,

    name                        varchar(150)
                                NOT NULL,

    description                 description_text,

    --------------------------------------------------------------------------
    -- Workflow Behavior
    --------------------------------------------------------------------------

    allows_multiple_per_trial   boolean
                                NOT NULL
                                DEFAULT false,

    requires_approved_trial     boolean
                                NOT NULL
                                DEFAULT true,

    is_required_for_completion  boolean
                                NOT NULL
                                DEFAULT false,

    --------------------------------------------------------------------------
    -- Configuration State
    --------------------------------------------------------------------------

    is_active                   boolean
                                NOT NULL
                                DEFAULT true,

    display_order               integer
                                NOT NULL
                                DEFAULT 0,

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

    CONSTRAINT fk_evaluation_types_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_evaluation_types_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_evaluation_types_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_evaluation_types_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 150
        ),

    CONSTRAINT chk_evaluation_types_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_evaluation_types_completion_requirement
        CHECK
        (
            is_required_for_completion = false
            OR requires_approved_trial = true
        ),

    CONSTRAINT chk_evaluation_types_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_evaluation_types_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.evaluation_types IS
'System-controlled evaluation classifications used by the shared dynamic evaluation engine. The frozen types are Observation and Technical Evaluation.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.evaluation_types.id IS
'Internal UUID primary key of the evaluation type.';

COMMENT ON COLUMN public.evaluation_types.code IS
'Immutable system code identifying the evaluation type.';

COMMENT ON COLUMN public.evaluation_types.name IS
'Human-readable evaluation-type name shown in Flutter forms, dashboards, and reports.';

COMMENT ON COLUMN public.evaluation_types.description IS
'Explanation of the evaluation type and its role in the trial workflow.';

COMMENT ON COLUMN public.evaluation_types.allows_multiple_per_trial IS
'Indicates whether multiple evaluations of this type may be created for the same trial.';

COMMENT ON COLUMN public.evaluation_types.requires_approved_trial IS
'Indicates that the trial must be approved before an evaluation of this type may be created.';

COMMENT ON COLUMN public.evaluation_types.is_required_for_completion IS
'Indicates that at least one submitted or validated evaluation of this type is required before the trial may be completed.';

COMMENT ON COLUMN public.evaluation_types.is_active IS
'Indicates whether the evaluation type is enabled for system workflow operations. Frozen evaluation types should remain active.';

COMMENT ON COLUMN public.evaluation_types.display_order IS
'Controls ordering in Flutter forms, filters, dashboards, and administrative interfaces.';

COMMENT ON COLUMN public.evaluation_types.created_at IS
'UTC timestamp when the evaluation-type record was created.';

COMMENT ON COLUMN public.evaluation_types.updated_at IS
'UTC timestamp when the evaluation-type record was most recently updated.';

COMMENT ON COLUMN public.evaluation_types.created_by IS
'Supabase Auth user who created the evaluation-type record.';

COMMENT ON COLUMN public.evaluation_types.updated_by IS
'Supabase Auth user who most recently updated the evaluation-type record.';

COMMENT ON COLUMN public.evaluation_types.deleted_at IS
'Soft-deletion timestamp. Frozen evaluation types must not be soft-deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_evaluation_types_code_ci
    ON public.evaluation_types
    (
        lower(btrim(code::text))
    );

CREATE UNIQUE INDEX uq_evaluation_types_name_normalized
    ON public.evaluation_types
    (
        public.fn_normalize_text(name)
    );

--------------------------------------------------------------------------------
-- FILTERING AND SORTING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_types_active_display
    ON public.evaluation_types
    (
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_types_multiple
    ON public.evaluation_types
    (
        allows_multiple_per_trial
    )
    WHERE allows_multiple_per_trial = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_types_required_completion
    ON public.evaluation_types
    (
        is_required_for_completion
    )
    WHERE is_required_for_completion = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_types_deleted_at
    ON public.evaluation_types (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_types_name_trgm
    ON public.evaluation_types
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_types_created_by
    ON public.evaluation_types (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_evaluation_types_updated_by
    ON public.evaluation_types (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- PROTECTION FUNCTION
--------------------------------------------------------------------------------
-- Protects frozen evaluation-type workflow fields after insertion.
--
-- Authorized configuration changes may update:
--
--   • name
--   • description
--   • display_order
--   • updated_at
--   • updated_by
--
-- The following system fields cannot be changed:
--
--   • code
--   • allows_multiple_per_trial
--   • requires_approved_trial
--   • is_required_for_completion
--   • is_active
--   • deleted_at
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_protect_evaluation_type()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    IF TG_OP = 'DELETE' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation type protection failed: frozen evaluation types cannot be deleted.';

    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.code IS DISTINCT FROM OLD.code
           OR NEW.allows_multiple_per_trial
                IS DISTINCT FROM OLD.allows_multiple_per_trial
           OR NEW.requires_approved_trial
                IS DISTINCT FROM OLD.requires_approved_trial
           OR NEW.is_required_for_completion
                IS DISTINCT FROM OLD.is_required_for_completion
           OR NEW.is_active IS DISTINCT FROM OLD.is_active
           OR NEW.deleted_at IS DISTINCT FROM OLD.deleted_at THEN

            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation type protection failed: frozen workflow fields cannot be changed.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_protect_evaluation_type() IS
'Protects frozen evaluation-type codes, workflow behavior, active state, and soft-delete state from modification or deletion.';

--------------------------------------------------------------------------------
-- PROTECTION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_evaluation_types_protect
    BEFORE UPDATE OR DELETE
    ON public.evaluation_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_protect_evaluation_type();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_evaluation_types_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.evaluation_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_evaluation_types_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.evaluation_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_evaluation_types_timestamps
    BEFORE INSERT OR UPDATE
    ON public.evaluation_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_evaluation_types_created_by
    BEFORE INSERT
    ON public.evaluation_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_evaluation_types_updated_by
    BEFORE UPDATE
    ON public.evaluation_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------

INSERT INTO public.evaluation_types
(
    code,
    name,
    description,
    allows_multiple_per_trial,
    requires_approved_trial,
    is_required_for_completion,
    is_active,
    display_order
)
VALUES
    (
        'OBSERVATION',
        'Observation',
        'Repeatable field observation performed during the approved trial lifecycle.',
        true,
        true,
        false,
        true,
        10
    ),
    (
        'TECHNICAL_EVALUATION',
        'Technical Evaluation',
        'Formal technical evaluation performed with agronomic or technical participation and required before trial completion.',
        false,
        true,
        true,
        true,
        20
    )
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    expected_column_count       integer;
    evaluation_type_count       integer;
    observation_count           integer;
    technical_evaluation_count  integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.evaluation_types') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: public.evaluation_types was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'evaluation_types'
      AND column_name IN
      (
          'id',
          'code',
          'name',
          'description',
          'allows_multiple_per_trial',
          'requires_approved_trial',
          'is_required_for_completion',
          'is_active',
          'display_order',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF expected_column_count <> 14 THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: evaluation_types has % of 14 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_types'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_types'::regclass
          AND conname = 'fk_evaluation_types_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_types'::regclass
          AND conname = 'fk_evaluation_types_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_evaluation_types_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: unique evaluation-type code index is missing.';
    END IF;

    IF to_regclass('public.uq_evaluation_types_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: unique evaluation-type name index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify frozen evaluation types
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO evaluation_type_count
    FROM public.evaluation_types
    WHERE code::text IN
    (
        'OBSERVATION',
        'TECHNICAL_EVALUATION'
    );

    IF evaluation_type_count <> 2 THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: only % of 2 frozen evaluation types were inserted.',
            evaluation_type_count;
    END IF;

    SELECT count(*)
    INTO observation_count
    FROM public.evaluation_types
    WHERE code::text = 'OBSERVATION'
      AND allows_multiple_per_trial = true
      AND requires_approved_trial = true
      AND is_required_for_completion = false
      AND is_active = true
      AND deleted_at IS NULL;

    IF observation_count <> 1 THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: Observation configuration is invalid.';
    END IF;

    SELECT count(*)
    INTO technical_evaluation_count
    FROM public.evaluation_types
    WHERE code::text = 'TECHNICAL_EVALUATION'
      AND allows_multiple_per_trial = false
      AND requires_approved_trial = true
      AND is_required_for_completion = true
      AND is_active = true
      AND deleted_at IS NULL;

    IF technical_evaluation_count <> 1 THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: Technical Evaluation configuration is invalid.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify protection function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure('public.trg_protect_evaluation_type()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: protection function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_types'::regclass
          AND tgname = 'trg_evaluation_types_protect'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: protection trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_types'::regclass
          AND tgname = 'trg_evaluation_types_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_types'::regclass
          AND tgname = 'trg_evaluation_types_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_types'::regclass
          AND tgname = 'trg_evaluation_types_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0031_evaluation_types.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
