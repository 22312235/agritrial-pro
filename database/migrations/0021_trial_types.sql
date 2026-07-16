/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0021_trial_types.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the trial_types configuration table.
*
* Trial types represent the commercial progression level of a seed variety trial.
*
* Confirmed Agrimatco Morocco trial types:
*
*   • Screening Y1
*   • Demonstrative Y2
*   • Large Demo Y3
*
* Frozen architectural rules:
*
*   • Trial types are configurable master data.
*   • Trial types are managed by the Manager.
*   • Flutter loads trial types dynamically from the database.
*   • An "Other" option is included.
*   • Selecting "Other" requires a custom user-entered value in the trial.
*   • The custom-value requirement will be enforced in the trials migration.
*   • Trial types support soft deletion and historical references.
*   • Row Level Security policies are intentionally deferred.
*
* General configurable-value rule:
*
*   • When a predefined value does not exist, the user may select "Other".
*   • The related workflow record must then require a custom text value.
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
-- TABLE: trial_types
--------------------------------------------------------------------------------

CREATE TABLE public.trial_types
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  uuid
                        PRIMARY KEY
                        DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Trial Type Information
    --------------------------------------------------------------------------

    code                long_code
                        NOT NULL,

    name                varchar(150)
                        NOT NULL,

    year_level          smallint,

    description         description_text,

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

    CONSTRAINT fk_trial_types_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_trial_types_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_trial_types_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_trial_types_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 150
        ),

    CONSTRAINT chk_trial_types_year_level
        CHECK
        (
            year_level IS NULL
            OR year_level BETWEEN 1 AND 99
        ),

    CONSTRAINT chk_trial_types_other_custom_value
        CHECK
        (
            is_other = false
            OR allows_custom_value = true
        ),

    CONSTRAINT chk_trial_types_other_year_level
        CHECK
        (
            is_other = false
            OR year_level IS NULL
        ),

    CONSTRAINT chk_trial_types_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_trial_types_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_trial_types_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.trial_types IS
'Configurable trial progression types used by Agrimatco Morocco, including Screening Y1, Demonstrative Y2, Large Demo Y3, and an Other option for custom user-entered values.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.trial_types.id IS
'Internal UUID primary key of the trial type.';

COMMENT ON COLUMN public.trial_types.code IS
'Unique Agrimatco business code identifying the trial type. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.trial_types.name IS
'Trial-type display name shown in Flutter forms, dashboards, evaluations, and reports.';

COMMENT ON COLUMN public.trial_types.year_level IS
'Optional progression level of the trial type, such as 1 for Y1, 2 for Y2, and 3 for Y3.';

COMMENT ON COLUMN public.trial_types.description IS
'Optional operational or commercial description of the trial type.';

COMMENT ON COLUMN public.trial_types.is_other IS
'Indicates that this record represents the Other trial-type option.';

COMMENT ON COLUMN public.trial_types.allows_custom_value IS
'Indicates that selecting this trial type permits or requires a custom user-entered value in the trial.';

COMMENT ON COLUMN public.trial_types.is_active IS
'Indicates whether the trial type is available for new trial installations.';

COMMENT ON COLUMN public.trial_types.display_order IS
'Controls the ordering of trial types in Flutter dropdowns and configuration screens.';

COMMENT ON COLUMN public.trial_types.created_at IS
'UTC timestamp when the trial type record was created.';

COMMENT ON COLUMN public.trial_types.updated_at IS
'UTC timestamp when the trial type record was most recently updated.';

COMMENT ON COLUMN public.trial_types.created_by IS
'Supabase Auth user who created the trial type record.';

COMMENT ON COLUMN public.trial_types.updated_by IS
'Supabase Auth user who most recently updated the trial type record.';

COMMENT ON COLUMN public.trial_types.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the trial type has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_trial_types_code_ci
    ON public.trial_types
    (
        lower(btrim(code::text))
    );

CREATE UNIQUE INDEX uq_trial_types_name_normalized
    ON public.trial_types
    (
        public.fn_normalize_text(name)
    );

CREATE UNIQUE INDEX uq_trial_types_year_level
    ON public.trial_types (year_level)
    WHERE year_level IS NOT NULL;

CREATE UNIQUE INDEX uq_trial_types_single_other
    ON public.trial_types (is_other)
    WHERE is_other = true;

--------------------------------------------------------------------------------
-- FILTERING AND SORTING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_trial_types_active_display
    ON public.trial_types
    (
        display_order,
        year_level,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_trial_types_is_active
    ON public.trial_types (is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_trial_types_custom_values
    ON public.trial_types (allows_custom_value)
    WHERE allows_custom_value = true
      AND deleted_at IS NULL;

CREATE INDEX idx_trial_types_deleted_at
    ON public.trial_types (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_trial_types_name_trgm
    ON public.trial_types
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_trial_types_created_by
    ON public.trial_types (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_trial_types_updated_by
    ON public.trial_types (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_trial_type()
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
        NEW.year_level := NULL;
        NEW.allows_custom_value := true;
    END IF;

    --------------------------------------------------------------------------
    -- Reserve the name Other for explicitly marked records
    --------------------------------------------------------------------------

    IF public.fn_normalize_text(NEW.name) = 'other'
       AND NEW.is_other = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial type validation failed: the name "Other" requires is_other = true.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_trial_type() IS
'Ensures that the reserved Other trial type is correctly configured and supports a custom user-entered value.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_types_validate
    BEFORE INSERT OR UPDATE OF
        name,
        year_level,
        is_other,
        allows_custom_value
    ON public.trial_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_trial_type();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_types_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.trial_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_trial_types_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.trial_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_trial_types_timestamps
    BEFORE INSERT OR UPDATE
    ON public.trial_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_trial_types_created_by
    BEFORE INSERT
    ON public.trial_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_trial_types_updated_by
    BEFORE UPDATE
    ON public.trial_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------

INSERT INTO public.trial_types
(
    code,
    name,
    year_level,
    description,
    is_other,
    allows_custom_value,
    display_order
)
VALUES
    (
        'SCREENING_Y1',
        'Screening Y1',
        1,
        'First-year screening trial used to evaluate and filter candidate varieties.',
        false,
        false,
        10
    ),
    (
        'DEMONSTRATIVE_Y2',
        'Demonstrative Y2',
        2,
        'Second-year demonstrative trial used to validate promising varieties under field conditions.',
        false,
        false,
        20
    ),
    (
        'LARGE_DEMO_Y3',
        'Large Demo Y3',
        3,
        'Third-year large demonstration trial used for advanced commercial and agronomic validation.',
        false,
        false,
        30
    ),
    (
        'OTHER',
        'Other',
        NULL,
        'Custom trial type entered by the user.',
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
    other_count           integer;
    confirmed_type_count  integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.trial_types') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: public.trial_types was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'trial_types'
      AND column_name IN
      (
          'id',
          'code',
          'name',
          'year_level',
          'description',
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

    IF expected_column_count <> 14 THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: trial_types has % of 14 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_types'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_types'::regclass
          AND conname = 'fk_trial_types_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_types'::regclass
          AND conname = 'fk_trial_types_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_trial_types_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: unique trial-type code index is missing.';
    END IF;

    IF to_regclass('public.uq_trial_types_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: unique trial-type name index is missing.';
    END IF;

    IF to_regclass('public.uq_trial_types_year_level') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: unique year-level index is missing.';
    END IF;

    IF to_regclass('public.uq_trial_types_single_other') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: single-Other index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify business validation
    --------------------------------------------------------------------------

    IF to_regprocedure('public.trg_validate_trial_type()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_types'::regclass
          AND tgname = 'trg_trial_types_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_types'::regclass
          AND tgname = 'trg_trial_types_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_types'::regclass
          AND tgname = 'trg_trial_types_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_types'::regclass
          AND tgname = 'trg_trial_types_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: updated_by trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify confirmed trial types
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO confirmed_type_count
    FROM public.trial_types
    WHERE code::text IN
    (
        'SCREENING_Y1',
        'DEMONSTRATIVE_Y2',
        'LARGE_DEMO_Y3'
    )
      AND deleted_at IS NULL;

    IF confirmed_type_count <> 3 THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: only % of 3 confirmed trial types were inserted.',
            confirmed_type_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify exactly one valid Other option
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO other_count
    FROM public.trial_types
    WHERE is_other = true
      AND allows_custom_value = true
      AND year_level IS NULL;

    IF other_count <> 1 THEN
        RAISE EXCEPTION
            'Migration 0021_trial_types.sql failed: expected exactly one valid Other option, found %.',
            other_count;
    END IF;
END;
$$;

COMMIT;
