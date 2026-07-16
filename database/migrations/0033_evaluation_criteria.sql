/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0033_evaluation_criteria.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the evaluation_criteria configuration table.
*
* Evaluation criteria define the dynamic questions and measurements displayed
* in Flutter observation and technical-evaluation forms.
*
* Examples:
*
*   • Plant Vigor
*   • Vegetative–Generative Balance
*   • Plant Uniformity
*   • Internode Length
*   • Leaf Size
*   • Disease Tolerance
*   • Fruit Shape
*   • Shelf Life
*   • Fruit Setting
*   • Taste Quality
*   • Average Weight
*   • Firmness
*   • BRIX
*   • Fruit Defects
*   • Leaf Glossiness
*
* Frozen architectural rules:
*
*   • Criteria are managed dynamically by the Manager.
*   • Flutter builds forms directly from database configuration.
*   • Adding a criterion must not require an application update.
*   • Every criterion uses exactly one criterion_data_type.
*   • Criteria may be global or crop-specific.
*   • Criterion assignments determine where criteria appear.
*   • Select-based criteria receive options through criterion_options.
*   • Value validation is enforced later in evaluation_details.
*   • Criteria support soft deletion and historical references.
*   • Row Level Security policies are intentionally deferred.
*
* General custom-value rule:
*
*   • Criteria may permit a custom user-entered value.
*   • For selection criteria, an Other criterion option will support custom text.
*   • The custom-value requirement will be enforced in evaluation details.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0018_crops.sql
*   • 0032_criterion_data_types.sql
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
-- TABLE: evaluation_criteria
--------------------------------------------------------------------------------

CREATE TABLE public.evaluation_criteria
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                      uuid
                            PRIMARY KEY
                            DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Criterion Identity
    --------------------------------------------------------------------------

    code                    long_code
                            NOT NULL,

    name                    varchar(200)
                            NOT NULL,

    description             description_text,

    help_text               text,

    --------------------------------------------------------------------------
    -- Criterion Data Type
    --------------------------------------------------------------------------

    data_type_id            uuid
                            NOT NULL,

    --------------------------------------------------------------------------
    -- Optional Crop Scope
    --------------------------------------------------------------------------
    -- NULL crop_id means the criterion may be used globally.
    -- A non-NULL crop_id means the criterion is intended for that crop.
    --------------------------------------------------------------------------

    crop_id                 uuid,

    --------------------------------------------------------------------------
    -- Dynamic Form Configuration
    --------------------------------------------------------------------------

    unit_label              varchar(50),

    placeholder             varchar(250),

    is_required_by_default  boolean
                            NOT NULL
                            DEFAULT false,

    allows_custom_value     boolean
                            NOT NULL
                            DEFAULT false,

    --------------------------------------------------------------------------
    -- Numeric Validation Configuration
    --------------------------------------------------------------------------

    minimum_value           numeric(18,4),

    maximum_value           numeric(18,4),

    decimal_scale           smallint,

    --------------------------------------------------------------------------
    -- Text Validation Configuration
    --------------------------------------------------------------------------

    minimum_text_length     integer,

    maximum_text_length     integer,

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

    CONSTRAINT fk_evaluation_criteria_data_type
        FOREIGN KEY (data_type_id)
        REFERENCES public.criterion_data_types(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluation_criteria_crop
        FOREIGN KEY (crop_id)
        REFERENCES public.crops(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluation_criteria_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_evaluation_criteria_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_evaluation_criteria_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_evaluation_criteria_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 200
        ),

    CONSTRAINT chk_evaluation_criteria_help_text
        CHECK
        (
            help_text IS NULL
            OR
            (
                length(btrim(help_text)) > 0
                AND char_length(btrim(help_text)) <= 3000
            )
        ),

    CONSTRAINT chk_evaluation_criteria_unit_label
        CHECK
        (
            unit_label IS NULL
            OR
            (
                length(btrim(unit_label)) > 0
                AND char_length(btrim(unit_label)) <= 50
            )
        ),

    CONSTRAINT chk_evaluation_criteria_placeholder
        CHECK
        (
            placeholder IS NULL
            OR
            (
                length(btrim(placeholder)) > 0
                AND char_length(btrim(placeholder)) <= 250
            )
        ),

    CONSTRAINT chk_evaluation_criteria_numeric_range
        CHECK
        (
            minimum_value IS NULL
            OR maximum_value IS NULL
            OR maximum_value >= minimum_value
        ),

    CONSTRAINT chk_evaluation_criteria_decimal_scale
        CHECK
        (
            decimal_scale IS NULL
            OR decimal_scale BETWEEN 0 AND 4
        ),

    CONSTRAINT chk_evaluation_criteria_text_lengths
        CHECK
        (
            minimum_text_length IS NULL
            OR minimum_text_length >= 0
        ),

    CONSTRAINT chk_evaluation_criteria_maximum_text_length
        CHECK
        (
            maximum_text_length IS NULL
            OR maximum_text_length BETWEEN 1 AND 5000
        ),

    CONSTRAINT chk_evaluation_criteria_text_length_range
        CHECK
        (
            minimum_text_length IS NULL
            OR maximum_text_length IS NULL
            OR maximum_text_length >= minimum_text_length
        ),

    CONSTRAINT chk_evaluation_criteria_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_evaluation_criteria_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_evaluation_criteria_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.evaluation_criteria IS
'Dynamic evaluation criteria managed by the Manager and rendered automatically by Flutter for observations and technical evaluations.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.evaluation_criteria.id IS
'Internal UUID primary key of the evaluation criterion.';

COMMENT ON COLUMN public.evaluation_criteria.code IS
'Unique Agrimatco configuration code identifying the evaluation criterion.';

COMMENT ON COLUMN public.evaluation_criteria.name IS
'Criterion label displayed in dynamic Flutter evaluation forms.';

COMMENT ON COLUMN public.evaluation_criteria.description IS
'Optional administrative or agronomic description of the criterion.';

COMMENT ON COLUMN public.evaluation_criteria.help_text IS
'Optional guidance shown to the evaluator when completing the criterion.';

COMMENT ON COLUMN public.evaluation_criteria.data_type_id IS
'Criterion data type controlling Flutter rendering and database value validation.';

COMMENT ON COLUMN public.evaluation_criteria.crop_id IS
'Optional crop scope. NULL indicates a global criterion; otherwise the criterion is crop-specific.';

COMMENT ON COLUMN public.evaluation_criteria.unit_label IS
'Optional measurement unit such as g, kg, cm, mm, days, percentage, or °Brix.';

COMMENT ON COLUMN public.evaluation_criteria.placeholder IS
'Optional placeholder text displayed by Flutter in the criterion input.';

COMMENT ON COLUMN public.evaluation_criteria.is_required_by_default IS
'Default required-state used when a criterion assignment does not override requirement behavior.';

COMMENT ON COLUMN public.evaluation_criteria.allows_custom_value IS
'Indicates that the criterion may accept a custom user-entered value when supported by its configuration.';

COMMENT ON COLUMN public.evaluation_criteria.minimum_value IS
'Optional minimum numeric value permitted for integer, decimal, rating, or percentage criteria.';

COMMENT ON COLUMN public.evaluation_criteria.maximum_value IS
'Optional maximum numeric value permitted for integer, decimal, rating, or percentage criteria.';

COMMENT ON COLUMN public.evaluation_criteria.decimal_scale IS
'Optional number of decimal places allowed for decimal criteria.';

COMMENT ON COLUMN public.evaluation_criteria.minimum_text_length IS
'Optional minimum length for text or long-text criterion values.';

COMMENT ON COLUMN public.evaluation_criteria.maximum_text_length IS
'Optional maximum length for text or long-text criterion values.';

COMMENT ON COLUMN public.evaluation_criteria.is_active IS
'Indicates whether the criterion may be assigned to new dynamic evaluation forms.';

COMMENT ON COLUMN public.evaluation_criteria.display_order IS
'Default ordering of the criterion in configuration and dynamic Flutter forms.';

COMMENT ON COLUMN public.evaluation_criteria.created_at IS
'UTC timestamp when the criterion was created.';

COMMENT ON COLUMN public.evaluation_criteria.updated_at IS
'UTC timestamp when the criterion was most recently updated.';

COMMENT ON COLUMN public.evaluation_criteria.created_by IS
'Supabase Auth user who created the criterion.';

COMMENT ON COLUMN public.evaluation_criteria.updated_by IS
'Supabase Auth user who most recently updated the criterion.';

COMMENT ON COLUMN public.evaluation_criteria.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the criterion has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_evaluation_criteria_code_ci
    ON public.evaluation_criteria
    (
        lower(btrim(code::text))
    );

-- Prevent duplicate criterion names within the same scope.
-- NULL crop_id represents the global scope.
CREATE UNIQUE INDEX uq_evaluation_criteria_scope_name
    ON public.evaluation_criteria
    (
        COALESCE(crop_id, '00000000-0000-0000-0000-000000000000'::uuid),
        public.fn_normalize_text(name)
    );

--------------------------------------------------------------------------------
-- RELATIONSHIP AND FILTERING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_criteria_data_type_id
    ON public.evaluation_criteria (data_type_id);

CREATE INDEX idx_evaluation_criteria_crop_id
    ON public.evaluation_criteria (crop_id)
    WHERE crop_id IS NOT NULL;

CREATE INDEX idx_evaluation_criteria_global
    ON public.evaluation_criteria
    (
        display_order,
        name
    )
    WHERE crop_id IS NULL
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_criteria_crop_active
    ON public.evaluation_criteria
    (
        crop_id,
        display_order,
        name
    )
    WHERE crop_id IS NOT NULL
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_criteria_is_active
    ON public.evaluation_criteria (is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_evaluation_criteria_custom_values
    ON public.evaluation_criteria (allows_custom_value)
    WHERE allows_custom_value = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_criteria_deleted_at
    ON public.evaluation_criteria (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_criteria_name_trgm
    ON public.evaluation_criteria
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_criteria_created_by
    ON public.evaluation_criteria (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_evaluation_criteria_updated_by
    ON public.evaluation_criteria (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------
-- Validates:
--
--   • Data type exists and is active.
--   • Crop scope references an active, non-deleted crop.
--   • Numeric limits are only used by supported numeric data types.
--   • Decimal scale is only used by decimal-based data types.
--   • Text limits are only used by text data types.
--   • Selection criteria cannot define numeric or text-length limits.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_evaluation_criterion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_type_active              boolean;
    v_type_deleted_at          timestamptz;
    v_uses_text                boolean;
    v_uses_integer             boolean;
    v_uses_decimal             boolean;
    v_uses_single_option       boolean;
    v_uses_multiple_options    boolean;
    v_supports_minimum         boolean;
    v_supports_maximum         boolean;
    v_supports_decimal_scale   boolean;

    v_crop_active              boolean;
    v_crop_deleted_at          timestamptz;
BEGIN
    --------------------------------------------------------------------------
    -- Normalize optional text fields
    --------------------------------------------------------------------------

    NEW.help_text :=
        CASE
            WHEN NEW.help_text IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.help_text), '')
        END;

    NEW.unit_label :=
        CASE
            WHEN NEW.unit_label IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.unit_label), '')
        END;

    NEW.placeholder :=
        CASE
            WHEN NEW.placeholder IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.placeholder), '')
        END;

    --------------------------------------------------------------------------
    -- Resolve criterion data-type behavior
    --------------------------------------------------------------------------

    SELECT
        cdt.is_active,
        cdt.deleted_at,
        cdt.uses_text_value,
        cdt.uses_integer_value,
        cdt.uses_decimal_value,
        cdt.uses_single_option,
        cdt.uses_multiple_options,
        cdt.supports_minimum,
        cdt.supports_maximum,
        cdt.supports_decimal_scale
    INTO
        v_type_active,
        v_type_deleted_at,
        v_uses_text,
        v_uses_integer,
        v_uses_decimal,
        v_uses_single_option,
        v_uses_multiple_options,
        v_supports_minimum,
        v_supports_maximum,
        v_supports_decimal_scale
    FROM public.criterion_data_types cdt
    WHERE cdt.id = NEW.data_type_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Evaluation criterion validation failed: criterion data type %s does not exist.',
                    NEW.data_type_id
                );
    END IF;

    IF v_type_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation criterion validation failed: the selected criterion data type is soft-deleted.';
    END IF;

    IF NEW.is_active = true
       AND v_type_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation criterion validation failed: an active criterion cannot use an inactive data type.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate optional crop scope
    --------------------------------------------------------------------------

    IF NEW.crop_id IS NOT NULL THEN
        SELECT
            c.is_active,
            c.deleted_at
        INTO
            v_crop_active,
            v_crop_deleted_at
        FROM public.crops c
        WHERE c.id = NEW.crop_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE = format(
                        'Evaluation criterion validation failed: crop %s does not exist.',
                        NEW.crop_id
                    );
        END IF;

        IF v_crop_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation criterion validation failed: the selected crop is soft-deleted.';
        END IF;

        IF NEW.is_active = true
           AND v_crop_active = false THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation criterion validation failed: an active criterion cannot belong to an inactive crop.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate numeric limits
    --------------------------------------------------------------------------

    IF NEW.minimum_value IS NOT NULL
       AND v_supports_minimum = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation criterion validation failed: the selected data type does not support a minimum value.';
    END IF;

    IF NEW.maximum_value IS NOT NULL
       AND v_supports_maximum = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation criterion validation failed: the selected data type does not support a maximum value.';
    END IF;

    IF NEW.decimal_scale IS NOT NULL
       AND v_supports_decimal_scale = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation criterion validation failed: the selected data type does not support decimal scale.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate text-length rules
    --------------------------------------------------------------------------

    IF
    (
        NEW.minimum_text_length IS NOT NULL
        OR NEW.maximum_text_length IS NOT NULL
    )
    AND v_uses_text = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation criterion validation failed: text-length rules may only be used with text data types.';
    END IF;

    --------------------------------------------------------------------------
    -- Selection-based criteria cannot use typed value limits
    --------------------------------------------------------------------------

    IF
    (
        v_uses_single_option = true
        OR v_uses_multiple_options = true
    )
    AND
    (
        NEW.minimum_value IS NOT NULL
        OR NEW.maximum_value IS NOT NULL
        OR NEW.decimal_scale IS NOT NULL
        OR NEW.minimum_text_length IS NOT NULL
        OR NEW.maximum_text_length IS NOT NULL
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation criterion validation failed: selection criteria cannot define numeric or text-length limits.';
    END IF;

    --------------------------------------------------------------------------
    -- Integer criteria cannot use decimal scale
    --------------------------------------------------------------------------

    IF v_uses_integer = true
       AND NEW.decimal_scale IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation criterion validation failed: integer criteria cannot define decimal scale.';
    END IF;

    --------------------------------------------------------------------------
    -- Non-decimal criteria must not retain decimal scale
    --------------------------------------------------------------------------

    IF v_uses_decimal = false THEN
        NEW.decimal_scale := NULL;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_evaluation_criterion() IS
'Validates criterion data-type compatibility, crop scope, numeric limits, text limits, and dynamic form configuration.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_evaluation_criteria_validate
    BEFORE INSERT OR UPDATE OF
        data_type_id,
        crop_id,
        help_text,
        unit_label,
        placeholder,
        minimum_value,
        maximum_value,
        decimal_scale,
        minimum_text_length,
        maximum_text_length,
        is_active
    ON public.evaluation_criteria
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_evaluation_criterion();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_evaluation_criteria_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.evaluation_criteria
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_evaluation_criteria_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.evaluation_criteria
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_evaluation_criteria_timestamps
    BEFORE INSERT OR UPDATE
    ON public.evaluation_criteria
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_evaluation_criteria_created_by
    BEFORE INSERT
    ON public.evaluation_criteria
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_evaluation_criteria_updated_by
    BEFORE UPDATE
    ON public.evaluation_criteria
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------
-- Seeds confirmed common criteria as global criteria.
--
-- Criterion assignments created later determine whether each criterion appears
-- in Observation, Technical Evaluation, or both.
--------------------------------------------------------------------------------

INSERT INTO public.evaluation_criteria
(
    code,
    name,
    description,
    help_text,
    data_type_id,
    crop_id,
    unit_label,
    placeholder,
    is_required_by_default,
    allows_custom_value,
    minimum_value,
    maximum_value,
    decimal_scale,
    minimum_text_length,
    maximum_text_length,
    display_order
)
SELECT
    seed.code,
    seed.name,
    seed.description,
    seed.help_text,
    cdt.id,
    NULL,
    seed.unit_label,
    seed.placeholder,
    seed.is_required,
    seed.allows_custom,
    seed.minimum_value,
    seed.maximum_value,
    seed.decimal_scale,
    seed.minimum_text_length,
    seed.maximum_text_length,
    seed.display_order
FROM
(
    VALUES
        (
            'PLANT_VIGOR',
            'Plant Vigor',
            'Overall strength and development of the plant.',
            'Evaluate the general vigor of the plant.',
            'RATING',
            NULL,
            NULL,
            true,
            false,
            1::numeric,
            5::numeric,
            NULL::smallint,
            NULL::integer,
            NULL::integer,
            10
        ),
        (
            'VEGETATIVE_GENERATIVE_BALANCE',
            'Vegetative–Generative Balance',
            'Balance between vegetative growth and reproductive development.',
            'Select the option that best describes the plant balance.',
            'SINGLE_SELECT',
            NULL,
            NULL,
            true,
            true,
            NULL::numeric,
            NULL::numeric,
            NULL::smallint,
            NULL::integer,
            NULL::integer,
            20
        ),
        (
            'PLANT_UNIFORMITY',
            'Plant Uniformity',
            'Uniformity of plant growth within the evaluated variety.',
            'Evaluate consistency among plants.',
            'RATING',
            NULL,
            NULL,
            true,
            false,
            1::numeric,
            5::numeric,
            NULL::smallint,
            NULL::integer,
            NULL::integer,
            30
        ),
        (
            'INTERNODE_LENGTH',
            'Internode Length',
            'Observed distance between consecutive plant nodes.',
            'Enter the average observed internode length.',
            'DECIMAL',
            'cm',
            'Example: 8.5',
            false,
            false,
            0::numeric,
            NULL::numeric,
            2::smallint,
            NULL::integer,
            NULL::integer,
            40
        ),
        (
            'LEAF_SIZE',
            'Leaf Size',
            'Observed relative or measured leaf size.',
            'Enter or select the leaf-size evaluation.',
            'SINGLE_SELECT',
            NULL,
            NULL,
            false,
            true,
            NULL::numeric,
            NULL::numeric,
            NULL::smallint,
            NULL::integer,
            NULL::integer,
            50
        ),
        (
            'DISEASE_TOLERANCE',
            'Disease Tolerance',
            'Observed tolerance to disease pressure.',
            'Evaluate the variety’s apparent disease tolerance.',
            'RATING',
            NULL,
            NULL,
            false,
            false,
            1::numeric,
            5::numeric,
            NULL::smallint,
            NULL::integer,
            NULL::integer,
            60
        ),
        (
            'GROWTH_HABIT',
            'Growth Habit',
            'Observed plant growth habit.',
            'Select the growth habit or choose Other.',
            'SINGLE_SELECT',
            NULL,
            NULL,
            false,
            true,
            NULL::numeric,
            NULL::numeric,
            NULL::smallint,
            NULL::integer,
            NULL::integer,
            70
        ),
        (
            'FRUIT_SHAPE',
            'Fruit Shape',
            'Observed fruit or harvested-product shape.',
            'Select the closest configured fruit shape or choose Other.',
            'SINGLE_SELECT',
            NULL,
            NULL,
            true,
            true,
            NULL::numeric,
            NULL::numeric,
            NULL::smallint,
            NULL::integer,
            NULL::integer,
            80
        ),
        (
            'FRUIT_COLOR',
            'Fruit Color',
            'Observed fruit or harvested-product color.',
            'Select the closest configured color or choose Other.',
            'SINGLE_SELECT',
            NULL,
            NULL,
            false,
            true,
            NULL::numeric,
            NULL::numeric,
            NULL::smallint,
            NULL::integer,
            NULL::integer,
            90
        ),
        (
            'SHELF_LIFE',
            'Shelf Life',
            'Estimated or measured post-harvest shelf life.',
            'Enter the number of days the fruit remains commercially acceptable.',
            'INTEGER',
            'days',
            'Example: 12',
            false,
            false,
            0::numeric,
            365::numeric,
            NULL::smallint,
            NULL::integer,
            NULL::integer,
            100
        ),
        (
            'FRUIT_SETTING',
            'Fruit Setting',
            'Quality and consistency of fruit setting.',
            'Evaluate the fruit-setting performance.',
            'RATING',
            NULL,
            NULL,
            true,
            false,
            1::numeric,
            5::numeric,
            NULL::smallint,
            NULL::integer,
            NULL::integer,
            110
        ),
        (
            'TASTE_QUALITY',
            'Taste Quality',
            'Sensory evaluation of taste quality.',
            'Select the closest taste-quality option or choose Other.',
            'SINGLE_SELECT',
            NULL,
            NULL,
            false,
            true,
            NULL::numeric,
            NULL::numeric,
            NULL::smallint,
            NULL::integer,
            NULL::integer,
            120
        ),
        (
            'AVERAGE_WEIGHT',
            'Average Weight',
            'Average fruit or harvested-product weight.',
            'Enter the measured average weight.',
            'DECIMAL',
            'g',
            'Example: 185.50',
            true,
            false,
            0::numeric,
            NULL::numeric,
            2::smallint,
            NULL::integer,
            NULL::integer,
            130
        ),
        (
            'FIRMNESS',
            'Firmness',
            'Observed or measured fruit firmness.',
            'Evaluate fruit firmness.',
            'RATING',
            NULL,
            NULL,
            false,
            false,
            1::numeric,
            5::numeric,
            NULL::smallint,
            NULL::integer,
            NULL::integer,
            140
        ),
        (
            'BRIX',
            'BRIX',
            'Soluble solids measurement indicating sugar content.',
            'Enter the measured BRIX value.',
            'DECIMAL',
            '°Brix',
            'Example: 7.8',
            false,
            false,
            0::numeric,
            100::numeric,
            2::smallint,
            NULL::integer,
            NULL::integer,
            150
        ),
        (
            'FRUIT_DEFECTS',
            'Fruit Defects',
            'Observed fruit defects affecting quality or marketability.',
            'Select every observed defect. Choose Other for an unlisted defect.',
            'MULTI_SELECT',
            NULL,
            NULL,
            false,
            true,
            NULL::numeric,
            NULL::numeric,
            NULL::smallint,
            NULL::integer,
            NULL::integer,
            160
        ),
        (
            'GENERAL_COMMENTS',
            'General Comments',
            'Additional evaluator comments not captured by other criteria.',
            'Enter any useful agronomic or technical observations.',
            'LONG_TEXT',
            NULL,
            'Write additional comments',
            false,
            true,
            NULL::numeric,
            NULL::numeric,
            NULL::smallint,
            1::integer,
            5000::integer,
            170
        )
) AS seed
(
    code,
    name,
    description,
    help_text,
    data_type_code,
    unit_label,
    placeholder,
    is_required,
    allows_custom,
    minimum_value,
    maximum_value,
    decimal_scale,
    minimum_text_length,
    maximum_text_length,
    display_order
)
JOIN public.criterion_data_types cdt
    ON cdt.code::text = seed.data_type_code
WHERE cdt.deleted_at IS NULL
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    expected_column_count  integer;
    seeded_criteria_count  integer;
    invalid_type_count     integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.evaluation_criteria') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0033_evaluation_criteria.sql failed: public.evaluation_criteria was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'evaluation_criteria'
      AND column_name IN
      (
          'id',
          'code',
          'name',
          'description',
          'help_text',
          'data_type_id',
          'crop_id',
          'unit_label',
          'placeholder',
          'is_required_by_default',
          'allows_custom_value',
          'minimum_value',
          'maximum_value',
          'decimal_scale',
          'minimum_text_length',
          'maximum_text_length',
          'is_active',
          'display_order',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF expected_column_count <> 23 THEN
        RAISE EXCEPTION
            'Migration 0033_evaluation_criteria.sql failed: evaluation_criteria has % of 23 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify required relationships
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_criteria'::regclass
          AND conname = 'fk_evaluation_criteria_data_type'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0033_evaluation_criteria.sql failed: data-type foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_criteria'::regclass
          AND conname = 'fk_evaluation_criteria_crop'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0033_evaluation_criteria.sql failed: crop foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_evaluation_criteria_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0033_evaluation_criteria.sql failed: unique criterion-code index is missing.';
    END IF;

    IF to_regclass('public.uq_evaluation_criteria_scope_name') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0033_evaluation_criteria.sql failed: unique scope/name index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify validation function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.trg_validate_evaluation_criterion()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0033_evaluation_criteria.sql failed: validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_criteria'::regclass
          AND tgname = 'trg_evaluation_criteria_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0033_evaluation_criteria.sql failed: validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_criteria'::regclass
          AND tgname = 'trg_evaluation_criteria_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0033_evaluation_criteria.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_criteria'::regclass
          AND tgname = 'trg_evaluation_criteria_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0033_evaluation_criteria.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_criteria'::regclass
          AND tgname = 'trg_evaluation_criteria_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0033_evaluation_criteria.sql failed: updated_by trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify confirmed criteria
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO seeded_criteria_count
    FROM public.evaluation_criteria
    WHERE code::text IN
    (
        'PLANT_VIGOR',
        'VEGETATIVE_GENERATIVE_BALANCE',
        'PLANT_UNIFORMITY',
        'INTERNODE_LENGTH',
        'LEAF_SIZE',
        'DISEASE_TOLERANCE',
        'GROWTH_HABIT',
        'FRUIT_SHAPE',
        'FRUIT_COLOR',
        'SHELF_LIFE',
        'FRUIT_SETTING',
        'TASTE_QUALITY',
        'AVERAGE_WEIGHT',
        'FIRMNESS',
        'BRIX',
        'FRUIT_DEFECTS',
        'GENERAL_COMMENTS'
    )
      AND deleted_at IS NULL;

    IF seeded_criteria_count <> 17 THEN
        RAISE EXCEPTION
            'Migration 0033_evaluation_criteria.sql failed: only % of 17 confirmed criteria were inserted.',
            seeded_criteria_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify every criterion references a valid data type
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO invalid_type_count
    FROM public.evaluation_criteria ec
    LEFT JOIN public.criterion_data_types cdt
        ON cdt.id = ec.data_type_id
    WHERE cdt.id IS NULL
       OR cdt.deleted_at IS NOT NULL;

    IF invalid_type_count <> 0 THEN
        RAISE EXCEPTION
            'Migration 0033_evaluation_criteria.sql failed: % criteria reference invalid data types.',
            invalid_type_count;
    END IF;
END;
$$;

COMMIT;
