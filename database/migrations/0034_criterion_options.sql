
/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0034_criterion_options.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the criterion_options configuration table.
*
* Criterion options represent the selectable answers displayed for dynamic
* SINGLE_SELECT and MULTI_SELECT evaluation criteria.
*
* Examples:
*
*   • Good / Moderate / Poor
*   • Small / Medium / Large
*   • Determinate / Semi-Determinate / Indeterminate
*   • Excellent / Good / Average / Poor
*   • Fruit shapes
*   • Fruit colors
*   • Fruit defects
*   • Other
*
* General custom-value rule:
*
*   • Every selection criterion may contain one "Other" option.
*   • The Other option must have:
*
*       is_other = true
*       allows_custom_value = true
*
*   • Selecting an Other option allows the evaluator to write a custom value.
*   • Only one active or historical Other option is permitted per criterion.
*
* Frozen architectural rules:
*
*   • Options belong to exactly one evaluation criterion.
*   • Options are only permitted for SINGLE_SELECT and MULTI_SELECT criteria.
*   • Flutter loads options dynamically from this table.
*   • Options may be added without releasing a new application version.
*   • Historical options use soft deletion.
*   • Existing evaluation records must preserve their option references.
*   • Row Level Security policies are intentionally deferred.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0032_criterion_data_types.sql
*   • 0033_evaluation_criteria.sql
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
-- TABLE: criterion_options
--------------------------------------------------------------------------------

CREATE TABLE public.criterion_options
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                      uuid
                            PRIMARY KEY
                            DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Parent Criterion
    --------------------------------------------------------------------------

    criterion_id            uuid
                            NOT NULL,

    --------------------------------------------------------------------------
    -- Option Identity
    --------------------------------------------------------------------------

    code                    long_code
                            NOT NULL,

    name                    varchar(200)
                            NOT NULL,

    description             description_text,

    --------------------------------------------------------------------------
    -- Optional Scoring Configuration
    --------------------------------------------------------------------------
    -- numeric_value may be used for ranking, scoring, analytics, or reports.
    -- It does not replace the selected option reference.
    --------------------------------------------------------------------------

    numeric_value           numeric(18,4),

    --------------------------------------------------------------------------
    -- Custom Value Configuration
    --------------------------------------------------------------------------

    is_other                boolean
                            NOT NULL
                            DEFAULT false,

    allows_custom_value     boolean
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

    CONSTRAINT fk_criterion_options_criterion
        FOREIGN KEY (criterion_id)
        REFERENCES public.evaluation_criteria(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_criterion_options_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_criterion_options_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_criterion_options_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_criterion_options_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 200
        ),

    CONSTRAINT chk_criterion_options_other_custom_value
        CHECK
        (
            is_other = false
            OR allows_custom_value = true
        ),

    CONSTRAINT chk_criterion_options_custom_value_other_only
        CHECK
        (
            allows_custom_value = false
            OR is_other = true
        ),

    CONSTRAINT chk_criterion_options_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_criterion_options_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_criterion_options_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.criterion_options IS
'Dynamic selectable answers belonging to SINGLE_SELECT and MULTI_SELECT evaluation criteria.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.criterion_options.id IS
'Internal UUID primary key of the criterion option.';

COMMENT ON COLUMN public.criterion_options.criterion_id IS
'Parent evaluation criterion that owns the selectable option.';

COMMENT ON COLUMN public.criterion_options.code IS
'Unique option code within the parent evaluation criterion.';

COMMENT ON COLUMN public.criterion_options.name IS
'Human-readable option label displayed in dynamic Flutter evaluation forms.';

COMMENT ON COLUMN public.criterion_options.description IS
'Optional agronomic or administrative explanation of the selectable option.';

COMMENT ON COLUMN public.criterion_options.numeric_value IS
'Optional numeric score used for rankings, analytics, comparisons, and reporting.';

COMMENT ON COLUMN public.criterion_options.is_other IS
'Indicates that this is the special Other option for the parent criterion.';

COMMENT ON COLUMN public.criterion_options.allows_custom_value IS
'Indicates that selecting this option requires or permits evaluator-entered custom text.';

COMMENT ON COLUMN public.criterion_options.is_active IS
'Indicates whether the option may be selected in new evaluations.';

COMMENT ON COLUMN public.criterion_options.display_order IS
'Controls option ordering in Flutter dropdowns, radio groups, and multi-select inputs.';

COMMENT ON COLUMN public.criterion_options.created_at IS
'UTC timestamp when the criterion option was created.';

COMMENT ON COLUMN public.criterion_options.updated_at IS
'UTC timestamp when the criterion option was most recently updated.';

COMMENT ON COLUMN public.criterion_options.created_by IS
'Supabase Auth user who created the criterion option.';

COMMENT ON COLUMN public.criterion_options.updated_by IS
'Supabase Auth user who most recently updated the criterion option.';

COMMENT ON COLUMN public.criterion_options.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the option has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_criterion_options_criterion_code_ci
    ON public.criterion_options
    (
        criterion_id,
        lower(btrim(code::text))
    );

CREATE UNIQUE INDEX uq_criterion_options_criterion_name_normalized
    ON public.criterion_options
    (
        criterion_id,
        public.fn_normalize_text(name)
    );

--------------------------------------------------------------------------------
-- ONE OTHER OPTION PER CRITERION
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_criterion_options_one_other_per_criterion
    ON public.criterion_options (criterion_id)
    WHERE is_other = true;

--------------------------------------------------------------------------------
-- RELATIONSHIP AND FILTERING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_criterion_options_criterion_id
    ON public.criterion_options (criterion_id);

CREATE INDEX idx_criterion_options_active_display
    ON public.criterion_options
    (
        criterion_id,
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_criterion_options_numeric_value
    ON public.criterion_options
    (
        criterion_id,
        numeric_value
    )
    WHERE numeric_value IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_criterion_options_other
    ON public.criterion_options
    (
        criterion_id,
        is_other
    )
    WHERE is_other = true
      AND deleted_at IS NULL;

CREATE INDEX idx_criterion_options_deleted_at
    ON public.criterion_options (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_criterion_options_name_trgm
    ON public.criterion_options
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_criterion_options_created_by
    ON public.criterion_options (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_criterion_options_updated_by
    ON public.criterion_options (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------
-- Validates:
--
--   • Parent criterion exists.
--   • Parent criterion is not soft-deleted.
--   • Active options cannot belong to inactive criteria.
--   • Parent criterion uses SINGLE_SELECT or MULTI_SELECT.
--   • Data type requires configured options.
--   • Custom-value options follow the Other-option rule.
--   • Active Other options are only used when the criterion allows custom data.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_criterion_option()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_criterion_active               boolean;
    v_criterion_deleted_at           timestamptz;
    v_criterion_allows_custom_value  boolean;

    v_data_type_requires_options     boolean;
    v_uses_single_option             boolean;
    v_uses_multiple_options          boolean;
    v_data_type_active               boolean;
    v_data_type_deleted_at           timestamptz;
BEGIN
    --------------------------------------------------------------------------
    -- Normalize option description
    --------------------------------------------------------------------------

    NEW.description :=
        CASE
            WHEN NEW.description IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.description::text), '')
        END;

    --------------------------------------------------------------------------
    -- Resolve parent criterion and data-type behavior
    --------------------------------------------------------------------------

    SELECT
        ec.is_active,
        ec.deleted_at,
        ec.allows_custom_value,
        cdt.requires_options,
        cdt.uses_single_option,
        cdt.uses_multiple_options,
        cdt.is_active,
        cdt.deleted_at
    INTO
        v_criterion_active,
        v_criterion_deleted_at,
        v_criterion_allows_custom_value,
        v_data_type_requires_options,
        v_uses_single_option,
        v_uses_multiple_options,
        v_data_type_active,
        v_data_type_deleted_at
    FROM public.evaluation_criteria ec
    JOIN public.criterion_data_types cdt
        ON cdt.id = ec.data_type_id
    WHERE ec.id = NEW.criterion_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Criterion option validation failed: evaluation criterion %s does not exist.',
                    NEW.criterion_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Reject deleted parents
    --------------------------------------------------------------------------

    IF v_criterion_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion option validation failed: options cannot belong to a soft-deleted criterion.';
    END IF;

    IF v_data_type_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion option validation failed: the parent criterion uses a soft-deleted data type.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate active-state relationships
    --------------------------------------------------------------------------

    IF NEW.is_active = true
       AND v_criterion_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion option validation failed: an active option cannot belong to an inactive criterion.';
    END IF;

    IF NEW.is_active = true
       AND v_data_type_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion option validation failed: an active option cannot use an inactive criterion data type.';
    END IF;

    --------------------------------------------------------------------------
    -- Parent criterion must support selectable options
    --------------------------------------------------------------------------

    IF v_data_type_requires_options = false
       OR
       (
           v_uses_single_option = false
           AND v_uses_multiple_options = false
       ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion option validation failed: options may only belong to SINGLE_SELECT or MULTI_SELECT criteria.';
    END IF;

    --------------------------------------------------------------------------
    -- Enforce Other/custom-value rule
    --------------------------------------------------------------------------

    IF NEW.is_other = true
       AND NEW.allows_custom_value = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion option validation failed: an Other option must allow a custom value.';
    END IF;

    IF NEW.allows_custom_value = true
       AND NEW.is_other = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion option validation failed: only an Other option may allow a custom value.';
    END IF;

    IF NEW.is_other = true
       AND v_criterion_allows_custom_value = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion option validation failed: the parent criterion does not allow custom values.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_criterion_option() IS
'Validates parent criterion compatibility, selectable data types, active states, and the Other/custom-value rule.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_criterion_options_validate
    BEFORE INSERT OR UPDATE OF
        criterion_id,
        description,
        is_other,
        allows_custom_value,
        is_active
    ON public.criterion_options
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_criterion_option();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_criterion_options_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.criterion_options
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_criterion_options_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.criterion_options
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_criterion_options_timestamps
    BEFORE INSERT OR UPDATE
    ON public.criterion_options
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_criterion_options_created_by
    BEFORE INSERT
    ON public.criterion_options
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_criterion_options_updated_by
    BEFORE UPDATE
    ON public.criterion_options
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA: VEGETATIVE–GENERATIVE BALANCE
--------------------------------------------------------------------------------

INSERT INTO public.criterion_options
(
    criterion_id,
    code,
    name,
    description,
    numeric_value,
    is_other,
    allows_custom_value,
    display_order
)
SELECT
    ec.id,
    seed.code,
    seed.name,
    seed.description,
    seed.numeric_value,
    seed.is_other,
    seed.allows_custom_value,
    seed.display_order
FROM public.evaluation_criteria ec
CROSS JOIN
(
    VALUES
        (
            'GOOD',
            'Good',
            'The plant has a suitable balance between vegetative and generative development.',
            3::numeric,
            false,
            false,
            10
        ),
        (
            'MODERATE',
            'Moderate',
            'The plant has an acceptable but imperfect vegetative–generative balance.',
            2::numeric,
            false,
            false,
            20
        ),
        (
            'POOR',
            'Poor',
            'The plant has an unsuitable vegetative–generative balance.',
            1::numeric,
            false,
            false,
            30
        ),
        (
            'OTHER',
            'Other',
            'A balance classification not available in the configured list.',
            NULL::numeric,
            true,
            true,
            999
        )
) AS seed
(
    code,
    name,
    description,
    numeric_value,
    is_other,
    allows_custom_value,
    display_order
)
WHERE ec.code::text = 'VEGETATIVE_GENERATIVE_BALANCE'
  AND ec.deleted_at IS NULL
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- SEED DATA: LEAF SIZE
--------------------------------------------------------------------------------

INSERT INTO public.criterion_options
(
    criterion_id,
    code,
    name,
    description,
    numeric_value,
    is_other,
    allows_custom_value,
    display_order
)
SELECT
    ec.id,
    seed.code,
    seed.name,
    seed.description,
    seed.numeric_value,
    seed.is_other,
    seed.allows_custom_value,
    seed.display_order
FROM public.evaluation_criteria ec
CROSS JOIN
(
    VALUES
        (
            'SMALL',
            'Small',
            'Leaf size is relatively small for the evaluated crop and development stage.',
            1::numeric,
            false,
            false,
            10
        ),
        (
            'MEDIUM',
            'Medium',
            'Leaf size is moderate for the evaluated crop and development stage.',
            2::numeric,
            false,
            false,
            20
        ),
        (
            'LARGE',
            'Large',
            'Leaf size is relatively large for the evaluated crop and development stage.',
            3::numeric,
            false,
            false,
            30
        ),
        (
            'OTHER',
            'Other',
            'A leaf-size classification not available in the configured list.',
            NULL::numeric,
            true,
            true,
            999
        )
) AS seed
(
    code,
    name,
    description,
    numeric_value,
    is_other,
    allows_custom_value,
    display_order
)
WHERE ec.code::text = 'LEAF_SIZE'
  AND ec.deleted_at IS NULL
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- SEED DATA: GROWTH HABIT
--------------------------------------------------------------------------------

INSERT INTO public.criterion_options
(
    criterion_id,
    code,
    name,
    description,
    numeric_value,
    is_other,
    allows_custom_value,
    display_order
)
SELECT
    ec.id,
    seed.code,
    seed.name,
    seed.description,
    NULL::numeric,
    seed.is_other,
    seed.allows_custom_value,
    seed.display_order
FROM public.evaluation_criteria ec
CROSS JOIN
(
    VALUES
        (
            'DETERMINATE',
            'Determinate',
            'Plant growth terminates after reaching a genetically defined structure.',
            false,
            false,
            10
        ),
        (
            'SEMI_DETERMINATE',
            'Semi-Determinate',
            'Plant growth behavior is intermediate between determinate and indeterminate.',
            false,
            false,
            20
        ),
        (
            'INDETERMINATE',
            'Indeterminate',
            'Plant continues vegetative and reproductive growth throughout the season.',
            false,
            false,
            30
        ),
        (
            'BUSH',
            'Bush',
            'Compact bush-type plant growth.',
            false,
            false,
            40
        ),
        (
            'VINING',
            'Vining',
            'Trailing or climbing vine-type plant growth.',
            false,
            false,
            50
        ),
        (
            'ERECT',
            'Erect',
            'Plant develops predominantly upright growth.',
            false,
            false,
            60
        ),
        (
            'SPREADING',
            'Spreading',
            'Plant develops laterally across the soil or surrounding area.',
            false,
            false,
            70
        ),
        (
            'OTHER',
            'Other',
            'A growth habit not available in the configured list.',
            true,
            true,
            999
        )
) AS seed
(
    code,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
WHERE ec.code::text = 'GROWTH_HABIT'
  AND ec.deleted_at IS NULL
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- SEED DATA: FRUIT SHAPE
--------------------------------------------------------------------------------

INSERT INTO public.criterion_options
(
    criterion_id,
    code,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
SELECT
    ec.id,
    seed.code,
    seed.name,
    seed.description,
    seed.is_other,
    seed.allows_custom_value,
    seed.display_order
FROM public.evaluation_criteria ec
CROSS JOIN
(
    VALUES
        ('ROUND',       'Round',       'Fruit has a predominantly round shape.',               false, false, 10),
        ('OVAL',        'Oval',        'Fruit has an oval or egg-like shape.',                  false, false, 20),
        ('ELONGATED',   'Elongated',   'Fruit has an elongated shape.',                        false, false, 30),
        ('CYLINDRICAL', 'Cylindrical', 'Fruit has a cylindrical form.',                        false, false, 40),
        ('BLOCKY',      'Blocky',      'Fruit has a broad block-like shape.',                   false, false, 50),
        ('CONICAL',     'Conical',     'Fruit tapers toward one end.',                          false, false, 60),
        ('FLATTENED',   'Flattened',   'Fruit is compressed along its vertical axis.',          false, false, 70),
        ('HEART',       'Heart-Shaped','Fruit has a heart-like shape.',                         false, false, 80),
        ('PEAR',        'Pear-Shaped', 'Fruit has a pear-like shape.',                          false, false, 90),
        ('LOBED',       'Lobed',       'Fruit presents clearly visible external lobes.',        false, false, 100),
        ('OTHER',       'Other',       'A fruit shape not available in the configured list.',   true,  true,  999)
) AS seed
(
    code,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
WHERE ec.code::text = 'FRUIT_SHAPE'
  AND ec.deleted_at IS NULL
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- SEED DATA: FRUIT COLOR
--------------------------------------------------------------------------------

INSERT INTO public.criterion_options
(
    criterion_id,
    code,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
SELECT
    ec.id,
    seed.code,
    seed.name,
    seed.description,
    seed.is_other,
    seed.allows_custom_value,
    seed.display_order
FROM public.evaluation_criteria ec
CROSS JOIN
(
    VALUES
        ('GREEN',       'Green',       'Fruit is predominantly green.',                        false, false, 10),
        ('LIGHT_GREEN', 'Light Green', 'Fruit is predominantly light green.',                  false, false, 20),
        ('DARK_GREEN',  'Dark Green',  'Fruit is predominantly dark green.',                   false, false, 30),
        ('RED',         'Red',         'Fruit is predominantly red.',                          false, false, 40),
        ('YELLOW',      'Yellow',      'Fruit is predominantly yellow.',                       false, false, 50),
        ('ORANGE',      'Orange',      'Fruit is predominantly orange.',                       false, false, 60),
        ('PURPLE',      'Purple',      'Fruit is predominantly purple.',                       false, false, 70),
        ('WHITE',       'White',       'Fruit is predominantly white or cream.',               false, false, 80),
        ('PINK',        'Pink',        'Fruit is predominantly pink.',                         false, false, 90),
        ('BICOLOR',     'Bicolor',     'Fruit presents two dominant colors.',                   false, false, 100),
        ('OTHER',       'Other',       'A fruit color not available in the configured list.',   true,  true,  999)
) AS seed
(
    code,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
WHERE ec.code::text = 'FRUIT_COLOR'
  AND ec.deleted_at IS NULL
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- SEED DATA: TASTE QUALITY
--------------------------------------------------------------------------------

INSERT INTO public.criterion_options
(
    criterion_id,
    code,
    name,
    description,
    numeric_value,
    is_other,
    allows_custom_value,
    display_order
)
SELECT
    ec.id,
    seed.code,
    seed.name,
    seed.description,
    seed.numeric_value,
    seed.is_other,
    seed.allows_custom_value,
    seed.display_order
FROM public.evaluation_criteria ec
CROSS JOIN
(
    VALUES
        (
            'EXCELLENT',
            'Excellent',
            'Taste quality is considered excellent.',
            4::numeric,
            false,
            false,
            10
        ),
        (
            'GOOD',
            'Good',
            'Taste quality is considered good.',
            3::numeric,
            false,
            false,
            20
        ),
        (
            'AVERAGE',
            'Average',
            'Taste quality is considered average.',
            2::numeric,
            false,
            false,
            30
        ),
        (
            'POOR',
            'Poor',
            'Taste quality is considered poor.',
            1::numeric,
            false,
            false,
            40
        ),
        (
            'OTHER',
            'Other',
            'A taste-quality classification not available in the configured list.',
            NULL::numeric,
            true,
            true,
            999
        )
) AS seed
(
    code,
    name,
    description,
    numeric_value,
    is_other,
    allows_custom_value,
    display_order
)
WHERE ec.code::text = 'TASTE_QUALITY'
  AND ec.deleted_at IS NULL
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- SEED DATA: FRUIT DEFECTS
--------------------------------------------------------------------------------

INSERT INTO public.criterion_options
(
    criterion_id,
    code,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
SELECT
    ec.id,
    seed.code,
    seed.name,
    seed.description,
    seed.is_other,
    seed.allows_custom_value,
    seed.display_order
FROM public.evaluation_criteria ec
CROSS JOIN
(
    VALUES
        (
            'MAUVAISE_NOUAISON',
            'Mauvaise nouaison',
            'Poor or incomplete fruit setting.',
            false,
            false,
            10
        ),
        (
            'CREUX',
            'Creux',
            'Fruit presents hollow internal development.',
            false,
            false,
            20
        ),
        (
            'ECLATEMENT',
            'Éclatement',
            'Fruit presents visible cracking or splitting.',
            false,
            false,
            30
        ),
        (
            'FRUIT_BATEAU',
            'Fruit bateau',
            'Fruit presents an abnormal boat-like deformation.',
            false,
            false,
            40
        ),
        (
            'COULEUR',
            'Couleur',
            'Fruit presents an undesirable or irregular color defect.',
            false,
            false,
            50
        ),
        (
            'ZIPPERS',
            'Zippers',
            'Fruit presents zipper-like scars or lines.',
            false,
            false,
            60
        ),
        (
            'TETON',
            'Téton',
            'Fruit presents an abnormal pointed nipple-like end.',
            false,
            false,
            70
        ),
        (
            'FRUIT_OUVERT',
            'Fruit ouvert',
            'Fruit presents an open or incompletely closed structure.',
            false,
            false,
            80
        ),
        (
            'NECROSE_APICALE',
            'Nécrose apicale',
            'Fruit presents blossom-end rot or apical necrosis.',
            false,
            false,
            90
        ),
        (
            'MICRO_CRACKING',
            'Micro cracking',
            'Fruit skin presents small superficial cracks.',
            false,
            false,
            100
        ),
        (
            'COLLET_VERT',
            'Collet vert',
            'Fruit presents persistent green shoulders near the stem.',
            false,
            false,
            110
        ),
        (
            'OTHER',
            'Other',
            'A fruit defect not available in the configured list.',
            true,
            true,
            999
        )
) AS seed
(
    code,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
WHERE ec.code::text = 'FRUIT_DEFECTS'
  AND ec.deleted_at IS NULL
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    expected_column_count        integer;
    total_option_count           integer;
    selection_criterion_count    integer;
    criteria_with_options_count  integer;
    invalid_parent_count         integer;
    invalid_data_type_count      integer;
    invalid_other_count          integer;
    duplicate_other_count        integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.criterion_options') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: public.criterion_options was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'criterion_options'
      AND column_name IN
      (
          'id',
          'criterion_id',
          'code',
          'name',
          'description',
          'numeric_value',
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

    IF expected_column_count <> 15 THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: criterion_options has % of 15 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify required foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.criterion_options'::regclass
          AND conname = 'fk_criterion_options_criterion'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: criterion foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.criterion_options'::regclass
          AND conname = 'fk_criterion_options_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.criterion_options'::regclass
          AND conname = 'fk_criterion_options_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify indexes
    --------------------------------------------------------------------------

    IF to_regclass(
        'public.uq_criterion_options_criterion_code_ci'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: unique criterion/code index is missing.';
    END IF;

    IF to_regclass(
        'public.uq_criterion_options_criterion_name_normalized'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: unique criterion/name index is missing.';
    END IF;

    IF to_regclass(
        'public.uq_criterion_options_one_other_per_criterion'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: one-Other-per-criterion index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify seed data
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO total_option_count
    FROM public.criterion_options
    WHERE deleted_at IS NULL;

    IF total_option_count < 50 THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: only % criterion options were inserted.',
            total_option_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify selection criteria contain options
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO selection_criterion_count
    FROM public.evaluation_criteria ec
    JOIN public.criterion_data_types cdt
        ON cdt.id = ec.data_type_id
    WHERE cdt.requires_options = true
      AND ec.is_active = true
      AND ec.deleted_at IS NULL;

    SELECT count(DISTINCT co.criterion_id)
    INTO criteria_with_options_count
    FROM public.criterion_options co
    JOIN public.evaluation_criteria ec
        ON ec.id = co.criterion_id
    JOIN public.criterion_data_types cdt
        ON cdt.id = ec.data_type_id
    WHERE cdt.requires_options = true
      AND ec.is_active = true
      AND ec.deleted_at IS NULL
      AND co.is_active = true
      AND co.deleted_at IS NULL;

    IF criteria_with_options_count <> selection_criterion_count THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: % of % active selection criteria contain options.',
            criteria_with_options_count,
            selection_criterion_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify every option references a valid criterion
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO invalid_parent_count
    FROM public.criterion_options co
    LEFT JOIN public.evaluation_criteria ec
        ON ec.id = co.criterion_id
    WHERE ec.id IS NULL;

    IF invalid_parent_count <> 0 THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: % options reference missing criteria.',
            invalid_parent_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify options only belong to selectable data types
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO invalid_data_type_count
    FROM public.criterion_options co
    JOIN public.evaluation_criteria ec
        ON ec.id = co.criterion_id
    JOIN public.criterion_data_types cdt
        ON cdt.id = ec.data_type_id
    WHERE cdt.requires_options = false
       OR
       (
           cdt.uses_single_option = false
           AND cdt.uses_multiple_options = false
       );

    IF invalid_data_type_count <> 0 THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: % options belong to non-selection criteria.',
            invalid_data_type_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify Other/custom-value rule
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO invalid_other_count
    FROM public.criterion_options
    WHERE
    (
        is_other = true
        AND allows_custom_value = false
    )
    OR
    (
        is_other = false
        AND allows_custom_value = true
    );

    IF invalid_other_count <> 0 THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: % options violate the Other/custom-value rule.',
            invalid_other_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify no criterion has multiple Other options
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO duplicate_other_count
    FROM
    (
        SELECT criterion_id
        FROM public.criterion_options
        WHERE is_other = true
        GROUP BY criterion_id
        HAVING count(*) > 1
    ) duplicate_other;

    IF duplicate_other_count <> 0 THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: % criteria contain multiple Other options.',
            duplicate_other_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify validation function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.trg_validate_criterion_option()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.criterion_options'::regclass
          AND tgname = 'trg_criterion_options_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.criterion_options'::regclass
          AND tgname = 'trg_criterion_options_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.criterion_options'::regclass
          AND tgname = 'trg_criterion_options_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.criterion_options'::regclass
          AND tgname = 'trg_criterion_options_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0034_criterion_options.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
