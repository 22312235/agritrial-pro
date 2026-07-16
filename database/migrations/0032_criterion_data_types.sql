
/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0032_criterion_data_types.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the criterion_data_types system table.
*
* Criterion data types define how the dynamic evaluation engine stores,
* validates, and renders evaluation criterion values.
*
* Flutter will use these records to determine which input component to display.
*
* Frozen architectural rules:
*
*   • Evaluation forms are generated dynamically from database configuration.
*   • Criterion values must match the assigned criterion data type.
*   • Evaluation details use typed value columns.
*   • Selection types use criterion_options.
*   • Multiple-selection values use evaluation_detail_options.
*   • The data-type codes are system-controlled.
*   • No Other data type is permitted because unknown storage behavior would
*     make database validation impossible.
*   • Row Level Security policies are intentionally deferred.
*
* Supported data types:
*
*   • TEXT
*   • LONG_TEXT
*   • INTEGER
*   • DECIMAL
*   • BOOLEAN
*   • DATE
*   • TIME
*   • DATETIME
*   • SINGLE_SELECT
*   • MULTI_SELECT
*   • RATING
*   • PERCENTAGE
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
-- TABLE: criterion_data_types
--------------------------------------------------------------------------------

CREATE TABLE public.criterion_data_types
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                      uuid
                            PRIMARY KEY
                            DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Data Type Information
    --------------------------------------------------------------------------

    code                    long_code
                            NOT NULL,

    name                    varchar(150)
                            NOT NULL,

    description             description_text,

    flutter_widget          varchar(100)
                            NOT NULL,

    --------------------------------------------------------------------------
    -- Storage Behavior
    --------------------------------------------------------------------------

    uses_text_value         boolean
                            NOT NULL
                            DEFAULT false,

    uses_integer_value      boolean
                            NOT NULL
                            DEFAULT false,

    uses_decimal_value      boolean
                            NOT NULL
                            DEFAULT false,

    uses_boolean_value      boolean
                            NOT NULL
                            DEFAULT false,

    uses_date_value         boolean
                            NOT NULL
                            DEFAULT false,

    uses_time_value         boolean
                            NOT NULL
                            DEFAULT false,

    uses_datetime_value     boolean
                            NOT NULL
                            DEFAULT false,

    uses_single_option      boolean
                            NOT NULL
                            DEFAULT false,

    uses_multiple_options   boolean
                            NOT NULL
                            DEFAULT false,

    --------------------------------------------------------------------------
    -- Validation Behavior
    --------------------------------------------------------------------------

    supports_minimum        boolean
                            NOT NULL
                            DEFAULT false,

    supports_maximum        boolean
                            NOT NULL
                            DEFAULT false,

    supports_decimal_scale  boolean
                            NOT NULL
                            DEFAULT false,

    requires_options        boolean
                            NOT NULL
                            DEFAULT false,

    --------------------------------------------------------------------------
    -- Configuration State
    --------------------------------------------------------------------------

    is_active               boolean
                            NOT NULL
                            DEFAULT true,

    display_order           integer
                            NOT NULL
                            DEFAULT 0,

    --------------------------------------------------------------------------
    -- Audit and Soft-Delete Columns
    --------------------------------------------------------------------------

    created_at              timestamptz
                            NOT NULL
                            DEFAULT timezone('UTC', now()),

    updated_at              timestamptz
                            NOT NULL
                            DEFAULT timezone('UTC', now()),

    created_by              uuid,

    updated_by              uuid,

    deleted_at              timestamptz,

    --------------------------------------------------------------------------
    -- Foreign Keys
    --------------------------------------------------------------------------

    CONSTRAINT fk_criterion_data_types_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_criterion_data_types_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_criterion_data_types_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_criterion_data_types_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 150
        ),

    CONSTRAINT chk_criterion_data_types_flutter_widget
        CHECK
        (
            char_length(btrim(flutter_widget)) BETWEEN 1 AND 100
        ),

    CONSTRAINT chk_criterion_data_types_single_storage
        CHECK
        (
            (
                uses_text_value::integer
                + uses_integer_value::integer
                + uses_decimal_value::integer
                + uses_boolean_value::integer
                + uses_date_value::integer
                + uses_time_value::integer
                + uses_datetime_value::integer
                + uses_single_option::integer
                + uses_multiple_options::integer
            ) = 1
        ),

    CONSTRAINT chk_criterion_data_types_option_behavior
        CHECK
        (
            requires_options =
            (
                uses_single_option
                OR uses_multiple_options
            )
        ),

    CONSTRAINT chk_criterion_data_types_numeric_minimum
        CHECK
        (
            supports_minimum = false
            OR
            (
                uses_integer_value
                OR uses_decimal_value
            )
        ),

    CONSTRAINT chk_criterion_data_types_numeric_maximum
        CHECK
        (
            supports_maximum = false
            OR
            (
                uses_integer_value
                OR uses_decimal_value
            )
        ),

    CONSTRAINT chk_criterion_data_types_decimal_scale
        CHECK
        (
            supports_decimal_scale = false
            OR uses_decimal_value = true
        ),

    CONSTRAINT chk_criterion_data_types_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_criterion_data_types_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_criterion_data_types_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.criterion_data_types IS
'System-controlled data types used by the dynamic evaluation engine to render Flutter inputs and validate typed evaluation values.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.criterion_data_types.id IS
'Internal UUID primary key of the criterion data type.';

COMMENT ON COLUMN public.criterion_data_types.code IS
'Immutable system code identifying the criterion data type.';

COMMENT ON COLUMN public.criterion_data_types.name IS
'Human-readable name of the criterion data type.';

COMMENT ON COLUMN public.criterion_data_types.description IS
'Explanation of the storage, validation, and user-interface behavior of the data type.';

COMMENT ON COLUMN public.criterion_data_types.flutter_widget IS
'Flutter widget identifier used by the application to render the correct dynamic input component.';

COMMENT ON COLUMN public.criterion_data_types.uses_text_value IS
'Indicates that evaluation_details.value_text stores the criterion value.';

COMMENT ON COLUMN public.criterion_data_types.uses_integer_value IS
'Indicates that evaluation_details.value_integer stores the criterion value.';

COMMENT ON COLUMN public.criterion_data_types.uses_decimal_value IS
'Indicates that evaluation_details.value_decimal stores the criterion value.';

COMMENT ON COLUMN public.criterion_data_types.uses_boolean_value IS
'Indicates that evaluation_details.value_boolean stores the criterion value.';

COMMENT ON COLUMN public.criterion_data_types.uses_date_value IS
'Indicates that evaluation_details.value_date stores the criterion value.';

COMMENT ON COLUMN public.criterion_data_types.uses_time_value IS
'Indicates that evaluation_details.value_time stores the criterion value.';

COMMENT ON COLUMN public.criterion_data_types.uses_datetime_value IS
'Indicates that evaluation_details.value_datetime stores the criterion value.';

COMMENT ON COLUMN public.criterion_data_types.uses_single_option IS
'Indicates that one criterion option is stored for the evaluation detail.';

COMMENT ON COLUMN public.criterion_data_types.uses_multiple_options IS
'Indicates that multiple criterion options are stored through evaluation_detail_options.';

COMMENT ON COLUMN public.criterion_data_types.supports_minimum IS
'Indicates that evaluation criteria of this type may define a minimum allowed value.';

COMMENT ON COLUMN public.criterion_data_types.supports_maximum IS
'Indicates that evaluation criteria of this type may define a maximum allowed value.';

COMMENT ON COLUMN public.criterion_data_types.supports_decimal_scale IS
'Indicates that evaluation criteria of this type may define decimal precision.';

COMMENT ON COLUMN public.criterion_data_types.requires_options IS
'Indicates that active criterion_options must exist for criteria using this data type.';

COMMENT ON COLUMN public.criterion_data_types.is_active IS
'Indicates whether the data type remains enabled for dynamic evaluation configuration.';

COMMENT ON COLUMN public.criterion_data_types.display_order IS
'Controls ordering in administrative configuration interfaces.';

COMMENT ON COLUMN public.criterion_data_types.created_at IS
'UTC timestamp when the criterion data-type record was created.';

COMMENT ON COLUMN public.criterion_data_types.updated_at IS
'UTC timestamp when the criterion data-type record was most recently updated.';

COMMENT ON COLUMN public.criterion_data_types.created_by IS
'Supabase Auth user who created the criterion data-type record.';

COMMENT ON COLUMN public.criterion_data_types.updated_by IS
'Supabase Auth user who most recently updated the criterion data-type record.';

COMMENT ON COLUMN public.criterion_data_types.deleted_at IS
'Soft-deletion timestamp. Frozen criterion data types must not be soft-deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_criterion_data_types_code_ci
    ON public.criterion_data_types
    (
        lower(btrim(code::text))
    );

CREATE UNIQUE INDEX uq_criterion_data_types_name_normalized
    ON public.criterion_data_types
    (
        public.fn_normalize_text(name)
    );

CREATE UNIQUE INDEX uq_criterion_data_types_flutter_widget
    ON public.criterion_data_types
    (
        lower(btrim(flutter_widget))
    );

--------------------------------------------------------------------------------
-- FILTERING AND SORTING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_criterion_data_types_active_display
    ON public.criterion_data_types
    (
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_criterion_data_types_requires_options
    ON public.criterion_data_types
    (
        requires_options
    )
    WHERE requires_options = true
      AND deleted_at IS NULL;

CREATE INDEX idx_criterion_data_types_deleted_at
    ON public.criterion_data_types (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_criterion_data_types_created_by
    ON public.criterion_data_types (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_criterion_data_types_updated_by
    ON public.criterion_data_types (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- PROTECTION FUNCTION
--------------------------------------------------------------------------------
-- Protects frozen data-type behavior after insertion.
--
-- Authorized changes may update:
--
--   • name
--   • description
--   • display_order
--   • updated_at
--   • updated_by
--
-- Storage behavior, validation behavior, codes, widget identifiers, active
-- state, and soft-delete state cannot be changed.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_protect_criterion_data_type()
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
                    'Criterion data type protection failed: system data types cannot be deleted.';

    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.code IS DISTINCT FROM OLD.code
           OR NEW.flutter_widget IS DISTINCT FROM OLD.flutter_widget
           OR NEW.uses_text_value IS DISTINCT FROM OLD.uses_text_value
           OR NEW.uses_integer_value IS DISTINCT FROM OLD.uses_integer_value
           OR NEW.uses_decimal_value IS DISTINCT FROM OLD.uses_decimal_value
           OR NEW.uses_boolean_value IS DISTINCT FROM OLD.uses_boolean_value
           OR NEW.uses_date_value IS DISTINCT FROM OLD.uses_date_value
           OR NEW.uses_time_value IS DISTINCT FROM OLD.uses_time_value
           OR NEW.uses_datetime_value IS DISTINCT FROM OLD.uses_datetime_value
           OR NEW.uses_single_option IS DISTINCT FROM OLD.uses_single_option
           OR NEW.uses_multiple_options IS DISTINCT FROM OLD.uses_multiple_options
           OR NEW.supports_minimum IS DISTINCT FROM OLD.supports_minimum
           OR NEW.supports_maximum IS DISTINCT FROM OLD.supports_maximum
           OR NEW.supports_decimal_scale IS DISTINCT FROM OLD.supports_decimal_scale
           OR NEW.requires_options IS DISTINCT FROM OLD.requires_options
           OR NEW.is_active IS DISTINCT FROM OLD.is_active
           OR NEW.deleted_at IS DISTINCT FROM OLD.deleted_at THEN

            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Criterion data type protection failed: system behavior fields cannot be changed.';
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_protect_criterion_data_type() IS
'Protects frozen criterion data-type codes, Flutter widgets, storage behavior, validation behavior, active state, and soft-delete state.';

--------------------------------------------------------------------------------
-- PROTECTION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_criterion_data_types_protect
    BEFORE UPDATE OR DELETE
    ON public.criterion_data_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_protect_criterion_data_type();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_criterion_data_types_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.criterion_data_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_criterion_data_types_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.criterion_data_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_criterion_data_types_timestamps
    BEFORE INSERT OR UPDATE
    ON public.criterion_data_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_criterion_data_types_created_by
    BEFORE INSERT
    ON public.criterion_data_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_criterion_data_types_updated_by
    BEFORE UPDATE
    ON public.criterion_data_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------

INSERT INTO public.criterion_data_types
(
    code,
    name,
    description,
    flutter_widget,
    uses_text_value,
    uses_integer_value,
    uses_decimal_value,
    uses_boolean_value,
    uses_date_value,
    uses_time_value,
    uses_datetime_value,
    uses_single_option,
    uses_multiple_options,
    supports_minimum,
    supports_maximum,
    supports_decimal_scale,
    requires_options,
    is_active,
    display_order
)
VALUES
    (
        'TEXT',
        'Text',
        'Short single-line text value.',
        'text_field',
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        10
    ),
    (
        'LONG_TEXT',
        'Long Text',
        'Long multi-line text value.',
        'multiline_text_field',
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        20
    ),
    (
        'INTEGER',
        'Integer',
        'Whole-number numeric value.',
        'integer_field',
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        false,
        false,
        true,
        30
    ),
    (
        'DECIMAL',
        'Decimal',
        'Decimal numeric value.',
        'decimal_field',
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        true,
        40
    ),
    (
        'BOOLEAN',
        'Boolean',
        'True or false value.',
        'switch',
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        50
    ),
    (
        'DATE',
        'Date',
        'Calendar date value.',
        'date_picker',
        false,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        60
    ),
    (
        'TIME',
        'Time',
        'Time-of-day value.',
        'time_picker',
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        70
    ),
    (
        'DATETIME',
        'Date and Time',
        'Combined calendar date and time value.',
        'datetime_picker',
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        80
    ),
    (
        'SINGLE_SELECT',
        'Single Select',
        'Exactly one configured option may be selected.',
        'dropdown',
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        true,
        true,
        90
    ),
    (
        'MULTI_SELECT',
        'Multi Select',
        'One or more configured options may be selected.',
        'multi_select',
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        false,
        false,
        false,
        true,
        true,
        100
    ),
    (
        'RATING',
        'Rating',
        'Whole-number rating within a configured minimum and maximum.',
        'rating_selector',
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        false,
        false,
        true,
        110
    ),
    (
        'PERCENTAGE',
        'Percentage',
        'Decimal percentage value normally constrained between 0 and 100.',
        'percentage_field',
        false,
        false,
        true,
        false,
        false,
        false,
        false,
        false,
        false,
        true,
        true,
        true,
        false,
        true,
        120
    )
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    expected_column_count integer;
    required_type_count   integer;
    invalid_storage_count integer;
    invalid_option_count  integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.criterion_data_types') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0032_criterion_data_types.sql failed: public.criterion_data_types was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'criterion_data_types'
      AND column_name IN
      (
          'id',
          'code',
          'name',
          'description',
          'flutter_widget',
          'uses_text_value',
          'uses_integer_value',
          'uses_decimal_value',
          'uses_boolean_value',
          'uses_date_value',
          'uses_time_value',
          'uses_datetime_value',
          'uses_single_option',
          'uses_multiple_options',
          'supports_minimum',
          'supports_maximum',
          'supports_decimal_scale',
          'requires_options',
          'is_active',
          'display_order',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF expected_column_count <> 25 THEN
        RAISE EXCEPTION
            'Migration 0032_criterion_data_types.sql failed: criterion_data_types has % of 25 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify required system types
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO required_type_count
    FROM public.criterion_data_types
    WHERE code::text IN
    (
        'TEXT',
        'LONG_TEXT',
        'INTEGER',
        'DECIMAL',
        'BOOLEAN',
        'DATE',
        'TIME',
        'DATETIME',
        'SINGLE_SELECT',
        'MULTI_SELECT',
        'RATING',
        'PERCENTAGE'
    )
      AND is_active = true
      AND deleted_at IS NULL;

    IF required_type_count <> 12 THEN
        RAISE EXCEPTION
            'Migration 0032_criterion_data_types.sql failed: only % of 12 required data types were inserted.',
            required_type_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify exactly one storage strategy per type
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO invalid_storage_count
    FROM public.criterion_data_types
    WHERE
    (
        uses_text_value::integer
        + uses_integer_value::integer
        + uses_decimal_value::integer
        + uses_boolean_value::integer
        + uses_date_value::integer
        + uses_time_value::integer
        + uses_datetime_value::integer
        + uses_single_option::integer
        + uses_multiple_options::integer
    ) <> 1;

    IF invalid_storage_count <> 0 THEN
        RAISE EXCEPTION
            'Migration 0032_criterion_data_types.sql failed: % data types have invalid storage behavior.',
            invalid_storage_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify option-based data types
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO invalid_option_count
    FROM public.criterion_data_types
    WHERE requires_options IS DISTINCT FROM
    (
        uses_single_option
        OR uses_multiple_options
    );

    IF invalid_option_count <> 0 THEN
        RAISE EXCEPTION
            'Migration 0032_criterion_data_types.sql failed: % data types have invalid option behavior.',
            invalid_option_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify protection function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.trg_protect_criterion_data_type()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0032_criterion_data_types.sql failed: protection function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.criterion_data_types'::regclass
          AND tgname = 'trg_criterion_data_types_protect'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0032_criterion_data_types.sql failed: protection trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.criterion_data_types'::regclass
          AND tgname = 'trg_criterion_data_types_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0032_criterion_data_types.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.criterion_data_types'::regclass
          AND tgname = 'trg_criterion_data_types_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0032_criterion_data_types.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.criterion_data_types'::regclass
          AND tgname = 'trg_criterion_data_types_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0032_criterion_data_types.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
