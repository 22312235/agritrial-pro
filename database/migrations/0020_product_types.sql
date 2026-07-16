/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0020_product_types.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the product_types configuration table.
*
* Product types represent commercial, technical, or resistance-related
* classifications used during trial installation.
*
* Examples:
*
*   • Indeterminate TYLCV
*   • Determinate
*   • Hybrid
*   • Open Pollinated
*
* Frozen architectural rules:
*
*   • Product types are configurable master data.
*   • Product types are managed by the Manager.
*   • Flutter loads product types dynamically from the database.
*   • An "Other" option is included.
*   • Selecting "Other" requires a custom user-entered value in the trial.
*   • The custom-value requirement will be enforced in the trials migration.
*   • Product types support soft deletion and historical references.
*   • Row Level Security policies are intentionally deferred.
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
-- TABLE: product_types
--------------------------------------------------------------------------------

CREATE TABLE public.product_types
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  uuid
                        PRIMARY KEY
                        DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Product Type Information
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

    CONSTRAINT fk_product_types_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_product_types_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_product_types_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_product_types_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 150
        ),

    CONSTRAINT chk_product_types_other_custom_value
        CHECK
        (
            is_other = false
            OR allows_custom_value = true
        ),

    CONSTRAINT chk_product_types_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_product_types_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_product_types_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.product_types IS
'Configurable product classifications used during trial installation. Includes an Other option for custom user-entered values.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.product_types.id IS
'Internal UUID primary key of the product type.';

COMMENT ON COLUMN public.product_types.code IS
'Unique Agrimatco business code identifying the product type. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.product_types.name IS
'Product-type display name shown in Flutter forms, dashboards, and reports.';

COMMENT ON COLUMN public.product_types.description IS
'Optional technical, commercial, or resistance-related description of the product type.';

COMMENT ON COLUMN public.product_types.is_other IS
'Indicates that this record represents the Other product-type option.';

COMMENT ON COLUMN public.product_types.allows_custom_value IS
'Indicates that selecting this product type permits or requires a custom user-entered value in the trial.';

COMMENT ON COLUMN public.product_types.is_active IS
'Indicates whether the product type is available for new trial installations.';

COMMENT ON COLUMN public.product_types.display_order IS
'Controls the ordering of product types in Flutter dropdowns and configuration screens.';

COMMENT ON COLUMN public.product_types.created_at IS
'UTC timestamp when the product type record was created.';

COMMENT ON COLUMN public.product_types.updated_at IS
'UTC timestamp when the product type record was most recently updated.';

COMMENT ON COLUMN public.product_types.created_by IS
'Supabase Auth user who created the product type record.';

COMMENT ON COLUMN public.product_types.updated_by IS
'Supabase Auth user who most recently updated the product type record.';

COMMENT ON COLUMN public.product_types.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the product type has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_product_types_code_ci
    ON public.product_types
    (
        lower(btrim(code::text))
    );

CREATE UNIQUE INDEX uq_product_types_name_normalized
    ON public.product_types
    (
        public.fn_normalize_text(name)
    );

CREATE UNIQUE INDEX uq_product_types_single_other
    ON public.product_types
    (
        is_other
    )
    WHERE is_other = true;

--------------------------------------------------------------------------------
-- FILTERING AND SORTING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_product_types_active_display
    ON public.product_types
    (
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_product_types_is_active
    ON public.product_types (is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_product_types_custom_values
    ON public.product_types (allows_custom_value)
    WHERE allows_custom_value = true
      AND deleted_at IS NULL;

CREATE INDEX idx_product_types_deleted_at
    ON public.product_types (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_product_types_name_trgm
    ON public.product_types
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_product_types_created_by
    ON public.product_types (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_product_types_updated_by
    ON public.product_types (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_product_type()
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
    -- Reserve the name Other for explicitly marked records
    --------------------------------------------------------------------------

    IF public.fn_normalize_text(NEW.name) = 'other'
       AND NEW.is_other = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Product type validation failed: the name "Other" requires is_other = true.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_product_type() IS
'Ensures that the reserved Other product type is correctly configured to accept a custom user-entered value.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_product_types_validate
    BEFORE INSERT OR UPDATE OF
        name,
        is_other,
        allows_custom_value
    ON public.product_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_product_type();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_product_types_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.product_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_product_types_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.product_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_product_types_timestamps
    BEFORE INSERT OR UPDATE
    ON public.product_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_product_types_created_by
    BEFORE INSERT
    ON public.product_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_product_types_updated_by
    BEFORE UPDATE
    ON public.product_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------

INSERT INTO public.product_types
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
        'INDETERMINATE_TYLCV',
        'Indeterminate TYLCV',
        'Indeterminate product type with TYLCV resistance or tolerance characteristics.',
        false,
        false,
        10
    ),
    (
        'INDETERMINATE',
        'Indeterminate',
        'Indeterminate growth or commercial product classification.',
        false,
        false,
        20
    ),
    (
        'DETERMINATE',
        'Determinate',
        'Determinate growth or commercial product classification.',
        false,
        false,
        30
    ),
    (
        'HYBRID',
        'Hybrid',
        'Hybrid seed or product classification.',
        false,
        false,
        40
    ),
    (
        'OPEN_POLLINATED',
        'Open Pollinated',
        'Open-pollinated seed or product classification.',
        false,
        false,
        50
    ),
    (
        'OTHER',
        'Other',
        'Custom product type entered by the user.',
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
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.product_types') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0020_product_types.sql failed: public.product_types was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'product_types'
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
            'Migration 0020_product_types.sql failed: product_types has % of 13 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.product_types'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0020_product_types.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.product_types'::regclass
          AND conname = 'fk_product_types_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0020_product_types.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.product_types'::regclass
          AND conname = 'fk_product_types_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0020_product_types.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_product_types_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0020_product_types.sql failed: unique product-type code index is missing.';
    END IF;

    IF to_regclass('public.uq_product_types_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0020_product_types.sql failed: unique product-type name index is missing.';
    END IF;

    IF to_regclass('public.uq_product_types_single_other') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0020_product_types.sql failed: single-Other index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify business validation function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure('public.trg_validate_product_type()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0020_product_types.sql failed: product-type validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.product_types'::regclass
          AND tgname = 'trg_product_types_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0020_product_types.sql failed: product-type validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.product_types'::regclass
          AND tgname = 'trg_product_types_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0020_product_types.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.product_types'::regclass
          AND tgname = 'trg_product_types_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0020_product_types.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.product_types'::regclass
          AND tgname = 'trg_product_types_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0020_product_types.sql failed: updated_by trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify exactly one valid Other option
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO other_count
    FROM public.product_types
    WHERE is_other = true
      AND allows_custom_value = true;

    IF other_count <> 1 THEN
        RAISE EXCEPTION
            'Migration 0020_product_types.sql failed: expected exactly one valid Other option, found %.',
            other_count;
    END IF;
END;
$$;

COMMIT;
