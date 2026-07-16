/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0028_decision_types.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the decision_types configuration table.
*
* Decision types classify installation review decisions and initial decisions
* made during Phase 1 of the trial workflow.
*
* Confirmed workflow decisions include:
*
*   • Approve
*   • Reject
*   • Request Corrections
*
* Additional configurable initial decisions may be added by the Manager.
*
* Frozen architectural rules:
*
*   • Decision types are configurable master data.
*   • Decision types are managed by the Manager.
*   • Flutter loads decision types dynamically from the database.
*   • Exactly one "Other" decision type is included.
*   • Selecting "Other" requires a custom user-entered value.
*   • The custom-value requirement will be enforced in installation_reviews
*     and other relevant workflow records.
*   • Decision types support soft deletion and historical references.
*   • Row Level Security policies are intentionally deferred.
*
* General configurable-value rule:
*
*   • When a predefined value does not exist, the user may select "Other".
*   • The related workflow record must require a custom text value.
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
-- TABLE: decision_types
--------------------------------------------------------------------------------

CREATE TABLE public.decision_types
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  uuid
                        PRIMARY KEY
                        DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Decision Type Information
    --------------------------------------------------------------------------

    code                long_code
                        NOT NULL,

    name                varchar(150)
                        NOT NULL,

    description         description_text,

    --------------------------------------------------------------------------
    -- Workflow Behavior
    --------------------------------------------------------------------------

    is_approval         boolean
                        NOT NULL
                        DEFAULT false,

    is_rejection        boolean
                        NOT NULL
                        DEFAULT false,

    is_correction       boolean
                        NOT NULL
                        DEFAULT false,

    --------------------------------------------------------------------------
    -- Custom-Value Support
    --------------------------------------------------------------------------

    is_other            boolean
                        NOT NULL
                        DEFAULT false,

    allows_custom_value boolean
                        NOT NULL
                        DEFAULT false,

    --------------------------------------------------------------------------
    -- Configuration State
    --------------------------------------------------------------------------

    is_active           boolean
                        NOT NULL
                        DEFAULT true,

    display_order       integer
                        NOT NULL
                        DEFAULT 0,

    --------------------------------------------------------------------------
    -- Audit and Soft-Delete Columns
    --------------------------------------------------------------------------

    created_at          timestamptz
                        NOT NULL
                        DEFAULT timezone('UTC', now()),

    updated_at          timestamptz
                        NOT NULL
                        DEFAULT timezone('UTC', now()),

    created_by          uuid,

    updated_by          uuid,

    deleted_at          timestamptz,

    --------------------------------------------------------------------------
    -- Foreign Keys
    --------------------------------------------------------------------------

    CONSTRAINT fk_decision_types_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_decision_types_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_decision_types_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_decision_types_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 150
        ),

    CONSTRAINT chk_decision_types_single_behavior
        CHECK
        (
            (
                is_approval::integer
                + is_rejection::integer
                + is_correction::integer
            ) <= 1
        ),

    CONSTRAINT chk_decision_types_other_custom_value
        CHECK
        (
            is_other = false
            OR allows_custom_value = true
        ),

    CONSTRAINT chk_decision_types_other_behavior
        CHECK
        (
            is_other = false
            OR
            (
                is_approval = false
                AND is_rejection = false
                AND is_correction = false
            )
        ),

    CONSTRAINT chk_decision_types_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_decision_types_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_decision_types_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.decision_types IS
'Configurable Phase 1 decision classifications used in installation reviews and related workflows. Includes Approve, Reject, Request Corrections, and one Other option.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.decision_types.id IS
'Internal UUID primary key of the decision type.';

COMMENT ON COLUMN public.decision_types.code IS
'Unique Agrimatco business code identifying the decision type. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.decision_types.name IS
'Decision-type display name shown in Flutter review forms, dashboards, and reports.';

COMMENT ON COLUMN public.decision_types.description IS
'Optional explanation of when the decision type should be used.';

COMMENT ON COLUMN public.decision_types.is_approval IS
'Indicates that this decision approves the installation and permits the trial to continue to Phase 2.';

COMMENT ON COLUMN public.decision_types.is_rejection IS
'Indicates that this decision rejects the installation.';

COMMENT ON COLUMN public.decision_types.is_correction IS
'Indicates that this decision requests corrections before another review.';

COMMENT ON COLUMN public.decision_types.is_other IS
'Indicates that this record represents the Other decision-type option.';

COMMENT ON COLUMN public.decision_types.allows_custom_value IS
'Indicates that selecting this decision type allows or requires a custom user-entered value.';

COMMENT ON COLUMN public.decision_types.is_active IS
'Indicates whether the decision type is available for new workflow decisions.';

COMMENT ON COLUMN public.decision_types.display_order IS
'Controls the ordering of decision types in Flutter dropdowns and configuration screens.';

COMMENT ON COLUMN public.decision_types.created_at IS
'UTC timestamp when the decision-type record was created.';

COMMENT ON COLUMN public.decision_types.updated_at IS
'UTC timestamp when the decision-type record was most recently updated.';

COMMENT ON COLUMN public.decision_types.created_by IS
'Supabase Auth user who created the decision-type record.';

COMMENT ON COLUMN public.decision_types.updated_by IS
'Supabase Auth user who most recently updated the decision-type record.';

COMMENT ON COLUMN public.decision_types.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the decision type has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_decision_types_code_ci
    ON public.decision_types
    (
        lower(btrim(code::text))
    );

CREATE UNIQUE INDEX uq_decision_types_name_normalized
    ON public.decision_types
    (
        public.fn_normalize_text(name)
    );

CREATE UNIQUE INDEX uq_decision_types_single_other
    ON public.decision_types (is_other)
    WHERE is_other = true;

CREATE UNIQUE INDEX uq_decision_types_single_approval
    ON public.decision_types (is_approval)
    WHERE is_approval = true;

CREATE UNIQUE INDEX uq_decision_types_single_rejection
    ON public.decision_types (is_rejection)
    WHERE is_rejection = true;

CREATE UNIQUE INDEX uq_decision_types_single_correction
    ON public.decision_types (is_correction)
    WHERE is_correction = true;

--------------------------------------------------------------------------------
-- FILTERING AND SORTING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_decision_types_active_display
    ON public.decision_types
    (
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_decision_types_is_active
    ON public.decision_types (is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_decision_types_behavior
    ON public.decision_types
    (
        is_approval,
        is_rejection,
        is_correction
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_decision_types_custom_values
    ON public.decision_types (allows_custom_value)
    WHERE allows_custom_value = true
      AND deleted_at IS NULL;

CREATE INDEX idx_decision_types_deleted_at
    ON public.decision_types (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_decision_types_name_trgm
    ON public.decision_types
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_decision_types_created_by
    ON public.decision_types (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_decision_types_updated_by
    ON public.decision_types (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_decision_type()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    --------------------------------------------------------------------------
    -- Normalize the Other option
    --------------------------------------------------------------------------

    IF NEW.is_other = true THEN
        NEW.name := 'Other';
        NEW.allows_custom_value := true;
        NEW.is_approval := false;
        NEW.is_rejection := false;
        NEW.is_correction := false;
    END IF;

    --------------------------------------------------------------------------
    -- Reserve the name Other
    --------------------------------------------------------------------------

    IF public.fn_normalize_text(NEW.name) = 'other'
       AND NEW.is_other = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Decision type validation failed: the name "Other" requires is_other = true.';
    END IF;

    --------------------------------------------------------------------------
    -- Prevent conflicting workflow behavior
    --------------------------------------------------------------------------

    IF
    (
        NEW.is_approval::integer
        + NEW.is_rejection::integer
        + NEW.is_correction::integer
    ) > 1 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Decision type validation failed: a decision type cannot represent more than one workflow behavior.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_decision_type() IS
'Validates workflow behavior flags and ensures that the Other decision type supports a custom value without changing trial status automatically.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_decision_types_validate
    BEFORE INSERT OR UPDATE OF
        name,
        is_approval,
        is_rejection,
        is_correction,
        is_other,
        allows_custom_value
    ON public.decision_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_decision_type();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_decision_types_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.decision_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_decision_types_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.decision_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_decision_types_timestamps
    BEFORE INSERT OR UPDATE
    ON public.decision_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_decision_types_created_by
    BEFORE INSERT
    ON public.decision_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_decision_types_updated_by
    BEFORE UPDATE
    ON public.decision_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------

INSERT INTO public.decision_types
(
    code,
    name,
    description,
    is_approval,
    is_rejection,
    is_correction,
    is_other,
    allows_custom_value,
    display_order
)
VALUES
    (
        'APPROVE',
        'Approve',
        'Approves the trial installation and permits the trial to proceed to Phase 2.',
        true,
        false,
        false,
        false,
        false,
        10
    ),
    (
        'REJECT',
        'Reject',
        'Rejects the submitted trial installation.',
        false,
        true,
        false,
        false,
        false,
        20
    ),
    (
        'REQUEST_CORRECTIONS',
        'Request Corrections',
        'Returns the installation to the Trial Officer for correction and resubmission.',
        false,
        false,
        true,
        false,
        false,
        30
    ),
    (
        'OTHER',
        'Other',
        'Custom installation decision entered by an authorized user.',
        false,
        false,
        false,
        true,
        true,
        999
    )
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    expected_column_count integer;
    approval_count        integer;
    rejection_count       integer;
    correction_count      integer;
    other_count           integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.decision_types') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: public.decision_types was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'decision_types'
      AND column_name IN
      (
          'id',
          'code',
          'name',
          'description',
          'is_approval',
          'is_rejection',
          'is_correction',
          'is_other',
          'allows_custom_value',
          'is_active',
          'display_order',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF expected_column_count <> 16 THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: decision_types has % of 16 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.decision_types'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.decision_types'::regclass
          AND conname = 'fk_decision_types_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.decision_types'::regclass
          AND conname = 'fk_decision_types_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_decision_types_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: unique decision-type code index is missing.';
    END IF;

    IF to_regclass('public.uq_decision_types_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: unique decision-type name index is missing.';
    END IF;

    IF to_regclass('public.uq_decision_types_single_other') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: single-Other index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify validation function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure('public.trg_validate_decision_type()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.decision_types'::regclass
          AND tgname = 'trg_decision_types_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.decision_types'::regclass
          AND tgname = 'trg_decision_types_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.decision_types'::regclass
          AND tgname = 'trg_decision_types_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.decision_types'::regclass
          AND tgname = 'trg_decision_types_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: updated_by trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify exactly one workflow decision of each required type
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO approval_count
    FROM public.decision_types
    WHERE is_approval = true;

    SELECT count(*)
    INTO rejection_count
    FROM public.decision_types
    WHERE is_rejection = true;

    SELECT count(*)
    INTO correction_count
    FROM public.decision_types
    WHERE is_correction = true;

    SELECT count(*)
    INTO other_count
    FROM public.decision_types
    WHERE is_other = true
      AND allows_custom_value = true
      AND is_approval = false
      AND is_rejection = false
      AND is_correction = false;

    IF approval_count <> 1 THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: expected one approval decision, found %.',
            approval_count;
    END IF;

    IF rejection_count <> 1 THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: expected one rejection decision, found %.',
            rejection_count;
    END IF;

    IF correction_count <> 1 THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: expected one correction decision, found %.',
            correction_count;
    END IF;

    IF other_count <> 1 THEN
        RAISE EXCEPTION
            'Migration 0028_decision_types.sql failed: expected one valid Other decision, found %.',
            other_count;
    END IF;
END;
$$;

COMMIT;
