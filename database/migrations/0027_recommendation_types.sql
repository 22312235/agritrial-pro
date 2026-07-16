/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0027_recommendation_types.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the recommendation_types configuration table.
*
* Recommendation types classify the Manager's final recommendation at the end
* of a trial.
*
* Examples:
*
*   • Recommended
*   • Recommended with Conditions
*   • Continue Evaluation
*   • Not Recommended
*   • Commercial Demonstration
*
* Frozen architectural rules:
*
*   • Recommendation types are configurable master data.
*   • Recommendation types are managed by the Manager.
*   • Flutter loads recommendation types dynamically from the database.
*   • Exactly one "Other" recommendation type is included.
*   • Selecting "Other" requires a custom user-entered value.
*   • The custom-value requirement will be enforced in trial_recommendations.
*   • Recommendation types support soft deletion and historical references.
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
-- TABLE: recommendation_types
--------------------------------------------------------------------------------

CREATE TABLE public.recommendation_types
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  uuid
                        PRIMARY KEY
                        DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Recommendation Type Information
    --------------------------------------------------------------------------

    code                long_code
                        NOT NULL,

    name                varchar(150)
                        NOT NULL,

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

    CONSTRAINT fk_recommendation_types_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_recommendation_types_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_recommendation_types_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_recommendation_types_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 150
        ),

    CONSTRAINT chk_recommendation_types_other_custom_value
        CHECK
        (
            is_other = false
            OR allows_custom_value = true
        ),

    CONSTRAINT chk_recommendation_types_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_recommendation_types_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_recommendation_types_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.recommendation_types IS
'Configurable final recommendation classifications used at the end of Agrimatco Morocco trials. Includes one Other option for custom user-entered values.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.recommendation_types.id IS
'Internal UUID primary key of the recommendation type.';

COMMENT ON COLUMN public.recommendation_types.code IS
'Unique Agrimatco business code identifying the recommendation type. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.recommendation_types.name IS
'Recommendation-type display name shown in Flutter forms, dashboards, and PDF reports.';

COMMENT ON COLUMN public.recommendation_types.description IS
'Optional explanation of when the recommendation type should be used.';

COMMENT ON COLUMN public.recommendation_types.is_other IS
'Indicates that this record represents the Other recommendation-type option.';

COMMENT ON COLUMN public.recommendation_types.allows_custom_value IS
'Indicates that selecting this recommendation type allows or requires a custom user-entered value.';

COMMENT ON COLUMN public.recommendation_types.is_active IS
'Indicates whether the recommendation type is available for new final recommendations.';

COMMENT ON COLUMN public.recommendation_types.display_order IS
'Controls the ordering of recommendation types in Flutter dropdowns and configuration screens.';

COMMENT ON COLUMN public.recommendation_types.created_at IS
'UTC timestamp when the recommendation-type record was created.';

COMMENT ON COLUMN public.recommendation_types.updated_at IS
'UTC timestamp when the recommendation-type record was most recently updated.';

COMMENT ON COLUMN public.recommendation_types.created_by IS
'Supabase Auth user who created the recommendation-type record.';

COMMENT ON COLUMN public.recommendation_types.updated_by IS
'Supabase Auth user who most recently updated the recommendation-type record.';

COMMENT ON COLUMN public.recommendation_types.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the recommendation type has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_recommendation_types_code_ci
    ON public.recommendation_types
    (
        lower(btrim(code::text))
    );

CREATE UNIQUE INDEX uq_recommendation_types_name_normalized
    ON public.recommendation_types
    (
        public.fn_normalize_text(name)
    );

CREATE UNIQUE INDEX uq_recommendation_types_single_other
    ON public.recommendation_types (is_other)
    WHERE is_other = true;

--------------------------------------------------------------------------------
-- FILTERING AND SORTING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_recommendation_types_active_display
    ON public.recommendation_types
    (
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_recommendation_types_is_active
    ON public.recommendation_types (is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_recommendation_types_custom_values
    ON public.recommendation_types (allows_custom_value)
    WHERE allows_custom_value = true
      AND deleted_at IS NULL;

CREATE INDEX idx_recommendation_types_deleted_at
    ON public.recommendation_types (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_recommendation_types_name_trgm
    ON public.recommendation_types
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_recommendation_types_created_by
    ON public.recommendation_types (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_recommendation_types_updated_by
    ON public.recommendation_types (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_recommendation_type()
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
                    'Recommendation type validation failed: the name "Other" requires is_other = true.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_recommendation_type() IS
'Ensures that the reserved Other recommendation type is correctly configured to support a custom user-entered value.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_recommendation_types_validate
    BEFORE INSERT OR UPDATE OF
        name,
        is_other,
        allows_custom_value
    ON public.recommendation_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_recommendation_type();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_recommendation_types_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.recommendation_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_recommendation_types_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.recommendation_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_recommendation_types_timestamps
    BEFORE INSERT OR UPDATE
    ON public.recommendation_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_recommendation_types_created_by
    BEFORE INSERT
    ON public.recommendation_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_recommendation_types_updated_by
    BEFORE UPDATE
    ON public.recommendation_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------

INSERT INTO public.recommendation_types
(
    code,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
VALUES
    (
        'RECOMMENDED',
        'Recommended',
        'The tested variety is recommended based on the final agronomic and technical results.',
        false,
        false,
        10
    ),
    (
        'RECOMMENDED_WITH_CONDITIONS',
        'Recommended with Conditions',
        'The tested variety is recommended only under specified agronomic, regional, seasonal, or commercial conditions.',
        false,
        false,
        20
    ),
    (
        'CONTINUE_EVALUATION',
        'Continue Evaluation',
        'The tested variety requires additional observations, another season, or further technical evaluation before a final decision.',
        false,
        false,
        30
    ),
    (
        'COMMERCIAL_DEMONSTRATION',
        'Commercial Demonstration',
        'The tested variety should proceed to a broader commercial demonstration or advanced field trial.',
        false,
        false,
        40
    ),
    (
        'NOT_RECOMMENDED',
        'Not Recommended',
        'The tested variety is not recommended based on the final trial results.',
        false,
        false,
        50
    ),
    (
        'OTHER',
        'Other',
        'Custom final recommendation type entered by the Manager.',
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
    seeded_type_count     integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.recommendation_types') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: public.recommendation_types was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'recommendation_types'
      AND column_name IN
      (
          'id',
          'code',
          'name',
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

    IF expected_column_count <> 13 THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: recommendation_types has % of 13 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.recommendation_types'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.recommendation_types'::regclass
          AND conname = 'fk_recommendation_types_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.recommendation_types'::regclass
          AND conname = 'fk_recommendation_types_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_recommendation_types_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: unique recommendation-type code index is missing.';
    END IF;

    IF to_regclass('public.uq_recommendation_types_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: unique recommendation-type name index is missing.';
    END IF;

    IF to_regclass('public.uq_recommendation_types_single_other') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: single-Other index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify validation function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure('public.trg_validate_recommendation_type()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.recommendation_types'::regclass
          AND tgname = 'trg_recommendation_types_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.recommendation_types'::regclass
          AND tgname = 'trg_recommendation_types_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.recommendation_types'::regclass
          AND tgname = 'trg_recommendation_types_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.recommendation_types'::regclass
          AND tgname = 'trg_recommendation_types_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: updated_by trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify predefined recommendation types
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO seeded_type_count
    FROM public.recommendation_types
    WHERE code::text IN
    (
        'RECOMMENDED',
        'RECOMMENDED_WITH_CONDITIONS',
        'CONTINUE_EVALUATION',
        'COMMERCIAL_DEMONSTRATION',
        'NOT_RECOMMENDED'
    )
      AND deleted_at IS NULL;

    IF seeded_type_count <> 5 THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: only % of 5 predefined recommendation types were inserted.',
            seeded_type_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify exactly one valid Other option
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO other_count
    FROM public.recommendation_types
    WHERE is_other = true
      AND allows_custom_value = true;

    IF other_count <> 1 THEN
        RAISE EXCEPTION
            'Migration 0027_recommendation_types.sql failed: expected exactly one valid Other option, found %.',
            other_count;
    END IF;
END;
$$;

COMMIT;
